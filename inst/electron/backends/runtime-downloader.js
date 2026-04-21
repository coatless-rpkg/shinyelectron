// Runtime downloader — downloads portable R on first launch (auto-download strategy)
const https = require('https');
const http = require('http');
const fs = require('fs');
const path = require('path');
const os = require('os');
const { execFileSync } = require('child_process');
const crypto = require('crypto');
const { logDebug } = require('./utils');

/**
 * Download a file with progress reporting.
 * @param {string} url - URL to download.
 * @param {string} dest - Destination file path.
 * @param {function} onProgress - Callback: (percent) => void
 * @returns {Promise<void>}
 */
function downloadFile(url, dest, onProgress) {
  return new Promise((resolve, reject) => {
    const proto = url.startsWith('https') ? https : http;
    const file = fs.createWriteStream(dest);

    proto.get(url, (response) => {
      // Follow redirects
      if (response.statusCode >= 300 && response.statusCode < 400 && response.headers.location) {
        file.close();
        fs.unlinkSync(dest);
        return downloadFile(response.headers.location, dest, onProgress).then(resolve).catch(reject);
      }

      if (response.statusCode !== 200) {
        file.close();
        fs.unlinkSync(dest);
        reject(new Error(`Download failed with status ${response.statusCode}`));
        return;
      }

      const totalBytes = parseInt(response.headers['content-length'], 10);
      let downloadedBytes = 0;

      response.on('data', (chunk) => {
        downloadedBytes += chunk.length;
        if (totalBytes && onProgress) {
          onProgress(Math.round((downloadedBytes / totalBytes) * 100));
        }
      });

      response.pipe(file);
      file.on('finish', () => {
        file.close();
        resolve();
      });
    }).on('error', (err) => {
      file.close();
      if (fs.existsSync(dest)) fs.unlinkSync(dest);
      reject(err);
    });
  });
}

/**
 * Check if a runtime is already downloaded.
 * @param {object} manifest - Runtime manifest (must include a `language` field).
 * @returns {string|null} Path to the runtime executable if found, null otherwise.
 */
function findCachedRuntime(manifest) {
  const { checkManifestSchema } = require('./utils');
  checkManifestSchema(manifest, 'runtime');
  const installPath = path.normalize(manifest.install_path.replace('~', os.homedir()));

  if (manifest.language === 'r') {
    // portable-r extracts to a subdirectory: portable-r-{version}-{platform}-{arch}/
    // Search for Rscript in common portable-r layouts
    const candidates = [];

    if (process.platform === 'win32') {
      // Try portable-r subdirectory first, then flat
      const dirs = fs.existsSync(installPath) ?
        fs.readdirSync(installPath).filter(d => d.startsWith('portable-r-')) : [];
      for (const d of dirs) {
        candidates.push(path.join(installPath, d, 'bin', 'Rscript.exe'));
      }
      candidates.push(path.join(installPath, 'bin', 'Rscript.exe'));
    } else if (process.platform === 'darwin') {
      const dirs = fs.existsSync(installPath) ?
        fs.readdirSync(installPath).filter(d => d.startsWith('portable-r-')) : [];
      for (const d of dirs) {
        candidates.push(path.join(installPath, d, 'bin', 'Rscript'));
      }
      candidates.push(path.join(installPath, 'bin', 'Rscript'));
    } else {
      candidates.push(path.join(installPath, 'bin', 'Rscript'));
    }

    for (const c of candidates) {
      if (fs.existsSync(c)) return c;
    }
    return null;
  }

  if (manifest.language === 'python') {
    const candidates = [];
    const pyExe = process.platform === 'win32' ? 'python.exe' : 'python3';

    // python-build-standalone extracts to a subdirectory like python/ or cpython-*/
    if (fs.existsSync(installPath)) {
      const dirs = fs.readdirSync(installPath);
      for (const d of dirs) {
        const subdir = path.join(installPath, d);
        if (fs.statSync(subdir).isDirectory()) {
          // Check subdir/bin/python3 (Unix) or subdir/python.exe (Windows)
          candidates.push(path.join(subdir, 'bin', pyExe));
          candidates.push(path.join(subdir, pyExe));
          // Check subdir/install/bin/python3 (some builds)
          candidates.push(path.join(subdir, 'install', 'bin', pyExe));
        }
      }
    }
    // Also check flat layout: installPath/bin/python3
    candidates.push(path.join(installPath, 'bin', pyExe));
    candidates.push(path.join(installPath, pyExe));

    for (const c of candidates) {
      if (fs.existsSync(c)) return c;
    }
    return null;
  }

  return null;
}

/**
 * Download and install a runtime (R or Python).
 * @param {object} manifest - Runtime manifest from runtime-manifest.json.
 * @param {function} onProgress - Progress callback: (message, percent) => void
 * @returns {Promise<string>} Path to installed executable (Rscript or python3).
 */
async function downloadRuntime(manifest, onProgress) {
  const installPath = path.normalize(manifest.install_path.replace('~', os.homedir()));
  const url = manifest.download_url;
  const lang = manifest.language === 'python' ? 'Python' : 'R';

  if (onProgress) onProgress(`Downloading ${lang} runtime...`, 0);

  // Download to temp file with random name to prevent symlink races
  const ext = path.extname(new URL(url).pathname) || '.tar.gz';
  const tempFile = path.join(os.tmpdir(), `shinyelectron-dl-${crypto.randomBytes(8).toString('hex')}${ext}`);

  await downloadFile(url, tempFile, (percent) => {
    if (onProgress) onProgress(`Downloading ${lang} runtime... ${percent}%`, percent);
  });

  // Verify SHA-256 checksum if provided in manifest
  if (manifest.sha256) {
    if (onProgress) onProgress('Verifying download integrity...', -1);
    const hash = crypto.createHash('sha256');
    const fileData = fs.readFileSync(tempFile);
    hash.update(fileData);
    const actual = hash.digest('hex');
    if (actual !== manifest.sha256.toLowerCase()) {
      fs.unlinkSync(tempFile);
      throw new Error(
        `Download integrity check failed.\n\n` +
        `Expected SHA-256: ${manifest.sha256}\n` +
        `Actual SHA-256:   ${actual}\n\n` +
        `The download may be corrupted or tampered with.`
      );
    }
    logDebug('SHA-256 checksum verified');
  } else {
    console.warn('No SHA-256 checksum in manifest — skipping integrity verification');
  }

  if (onProgress) onProgress(`Extracting ${lang} runtime...`, -1);

  // Create install directory
  fs.mkdirSync(installPath, { recursive: true });

  // Extract based on file type — capture stderr so failures surface the real error.
  //
  // On Windows, resolve tar to %SystemRoot%\System32\tar.exe explicitly. Windows
  // 10+ ships bsdtar at that path, which handles drive letters fine. A bare
  // "tar" invocation may resolve to GNU tar from Git for Windows / msys, which
  // mis-parses "C:\..." as a remote host ("Cannot connect to C: resolve failed").
  const tarCmd = process.platform === 'win32'
    ? path.join(process.env.SystemRoot || 'C:\\Windows', 'System32', 'tar.exe')
    : 'tar';

  const runExtract = (cmd, args) => {
    try {
      execFileSync(cmd, args, { stdio: ['ignore', 'pipe', 'pipe'] });
    } catch (err) {
      const stderr = (err.stderr && err.stderr.toString()) || '';
      const stdout = (err.stdout && err.stdout.toString()) || '';
      const detail = [stderr, stdout].filter(Boolean).join('\n').trim();
      throw new Error(
        `${cmd} ${args.join(' ')}\n` +
        `Exit code: ${err.status}\n` +
        (detail ? `Output:\n${detail}` : '(no output captured)')
      );
    }
  };

  try {
    if (ext === '.gz' || url.endsWith('.tar.gz')) {
      runExtract(tarCmd, ['-xzf', tempFile, '-C', installPath]);
    } else if (ext === '.zip' || ext === '.exe') {
      // Windows bsdtar handles .zip too; on Unix fall back to unzip
      if (process.platform === 'win32') {
        runExtract(tarCmd, ['-xf', tempFile, '-C', installPath]);
      } else {
        runExtract('unzip', ['-q', tempFile, '-d', installPath]);
      }
    } else if (ext === '.pkg') {
      runExtract('pkgutil', ['--expand-full', tempFile, installPath]);
    } else {
      throw new Error(`Unsupported archive extension: ${ext}`);
    }
  } finally {
    if (fs.existsSync(tempFile)) fs.unlinkSync(tempFile);
  }

  // Find the installed executable
  const executable = findCachedRuntime(manifest);
  if (!executable) {
    throw new Error(`${lang} was extracted to ${installPath} but the executable was not found`);
  }

  if (onProgress) onProgress(`${lang} runtime ready`, 100);

  return executable;
}

module.exports = { findCachedRuntime, downloadRuntime, downloadFile };
