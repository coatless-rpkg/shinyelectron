// Stand-in for Rscript, python3 and docker used by backend-lifecycle.js.
// Called through small shell wrappers as: fake-runtime.js <R|python|docker> ...
// A Shiny "run" (or a container) reads <appDir>/fake-mode.json to decide how
// to behave:
//   serve  answer every HTTP request with 404 and log the request
//   hang   never bind the port
//   crash  print an error and exit with status 1
//   signal die by `signal` (default SIGKILL) after `delay` ms, never listening
//   exit   exit with `code` (default 0) after `delay` ms, never listening
// With holdStdio: <ms>, it also starts a helper that keeps its stdout and
// stderr open for that long. With termExitCode: <n>, it exits with status n
// on SIGTERM, as a process killed by taskkill /f does on Windows. Every run
// is recorded in <appDir>/fake-runs.log.
// The fake docker keeps its containers in $FAKE_DOCKER_STATE and logs every
// call there in calls.log. With lateLogs: <ms>, `docker logs -f` ignores
// SIGTERM and prints one more line after that long, like log output still
// in the pipe when the backend stops following the logs. With noPort: true,
// `docker port` fails for the container.
// `fake-runtime.js install <dir>` writes the Rscript, python3 and docker
// wrappers.
'use strict';

const crypto = require('crypto');
const fs = require('fs');
const http = require('http');
const net = require('net');
const path = require('path');
const { spawn } = require('child_process');

const [lang, ...args] = process.argv.slice(2);

function appendLine(file, line) {
  fs.appendFileSync(file, line + '\n');
}

// Exit once the test harness is gone, so a failed test never leaves a fake
// server behind. Containers are detached from the short-lived `docker run`,
// so everything watches the harness process itself.
function exitWithHarness() {
  const harness = Number(process.env.FAKE_HARNESS_PID);
  if (!harness) return;
  setInterval(() => {
    try {
      process.kill(harness, 0);
    } catch {
      process.exit(0);
    }
  }, 500).unref();
}

function readMode(appDir) {
  try {
    return JSON.parse(fs.readFileSync(path.join(appDir, 'fake-mode.json'), 'utf8'));
  } catch {
    return { mode: 'serve' };
  }
}

function runApp(appDir, port) {
  exitWithHarness();

  const mode = readMode(appDir);
  appendLine(path.join(appDir, 'fake-runs.log'), `${process.pid} ${port}`);

  if (mode.termExitCode !== undefined) {
    process.on('SIGTERM', () => process.exit(mode.termExitCode));
  }

  if (mode.holdStdio) {
    // A helper that inherits our stdio keeps the parent's pipes open after
    // we exit, which delays the child's 'close' event but not its 'exit'.
    const helper = spawn(process.execPath, ['-e', `setTimeout(() => {}, ${mode.holdStdio})`], {
      stdio: 'inherit',
      detached: true
    });
    appendLine(path.join(appDir, 'fake-helpers.log'), String(helper.pid));
    helper.unref();
  }

  if (mode.mode === 'signal' || mode.mode === 'exit') {
    setTimeout(() => {
      appendLine(path.join(appDir, 'fake-died.log'), String(Date.now()));
      if (mode.mode === 'signal') process.kill(process.pid, mode.signal || 'SIGKILL');
      else process.exit(mode.code || 0);
    }, mode.delay || 1000);
    return;
  }
  if (mode.mode === 'crash') {
    process.stderr.write('Error in runApp(): boom\n');
    setTimeout(() => process.exit(1), mode.delay || 100);
    return;
  }
  if (mode.mode === 'hang') {
    setInterval(() => {}, 1 << 30);
    return;
  }
  const server = http.createServer((req, res) => {
    appendLine(path.join(appDir, 'fake-requests.log'), `${req.method} ${req.url}`);
    res.statusCode = 404;
    res.end('Not Found');
  });
  server.listen(port, '127.0.0.1', () => {
    process.stderr.write(`Listening on http://127.0.0.1:${port}\n`);
  });
}

function fakeDocker() {
  const state = process.env.FAKE_DOCKER_STATE;
  fs.mkdirSync(state, { recursive: true });
  appendLine(path.join(state, 'calls.log'), args.join(' '));
  const containerFile = (id) => path.join(state, `${id}.json`);
  const readContainer = (id) => {
    try {
      return JSON.parse(fs.readFileSync(containerFile(id), 'utf8'));
    } catch {
      return null;
    }
  };
  const killContainer = (id) => {
    const container = readContainer(id);
    if (!container) return;
    try { process.kill(container.pid); } catch { /* already gone */ }
  };

  switch (args[0]) {
    case '--version':
      process.stdout.write('Docker version 27.0.0\n');
      return;
    case 'context':
      process.stdout.write('unix:///fake/docker.sock\n');
      return;
    case 'image':
      return; // `image inspect`: the image is always there
    case 'run': {
      // The first -v mounts the app directory at /app.
      const mount = args[args.indexOf('-v') + 1];
      const appDir = mount.slice(0, mount.lastIndexOf(':/app'));
      const probe = net.createServer();
      probe.listen(0, '127.0.0.1', () => {
        const port = probe.address().port;
        probe.close(() => {
          const id = crypto.randomBytes(32).toString('hex');
          const container = spawn(process.execPath, [__filename, 'container', appDir, String(port)], {
            detached: true,
            stdio: 'ignore'
          });
          container.unref();
          fs.writeFileSync(containerFile(id.slice(0, 12)), JSON.stringify({ pid: container.pid, port, appDir }));
          process.stdout.write(id + '\n');
        });
      });
      return;
    }
    case 'port': {
      const container = readContainer(args[1]);
      if (!container || readMode(container.appDir).noPort) process.exit(1);
      process.stdout.write(`127.0.0.1:${container.port}\n`);
      return;
    }
    case 'logs': {
      process.stdout.write('fake container log line\n');
      if (args[1] !== '-f') {
        process.stderr.write('fake container error line\n');
        return;
      }
      exitWithHarness();
      const id = args[args.length - 1];
      const container = readContainer(id);
      const lateLogs = container && readMode(container.appDir).lateLogs;
      if (lateLogs) {
        process.on('SIGTERM', () => {});
        setTimeout(() => {
          process.stdout.write('late container log line\n');
          appendLine(path.join(state, 'calls.log'), `late-log ${id}`);
          process.exit(0);
        }, lateLogs);
      } else {
        setInterval(() => {}, 1 << 30);
      }
      return;
    }
    case 'stop':
      killContainer(args[args.length - 1]);
      return;
    case 'rm': {
      const id = args[args.length - 1];
      killContainer(id);
      try { fs.unlinkSync(containerFile(id)); } catch { /* already removed */ }
      return;
    }
    default:
      process.exit(1);
  }
}

function makeWrapper(file, which) {
  fs.mkdirSync(path.dirname(file), { recursive: true });
  fs.writeFileSync(
    file,
    `#!/bin/sh\nexec "${process.execPath}" "${__filename}" ${which} "$@"\n`
  );
  fs.chmodSync(file, 0o755);
}

if (lang === 'R') {
  const code = args[args.indexOf('-e') + 1] || '';
  const run = /shiny::runApp\('([^']*)', port = (\d+)/.exec(code);
  const missingCheck = /setdiff\(c\(([^)]*)\)/.exec(code);
  if (args[0] === '--version') {
    process.stdout.write('Rscript (R) version 4.5.1\n');
  } else if (run) {
    runApp(run[1], Number(run[2]));
  } else if (missingCheck) {
    // The missing-package check: every requested package is missing.
    const pkgs = [...missingCheck[1].matchAll(/"([^"]+)"/g)].map((m) => m[1]);
    process.stdout.write(pkgs.join('\n'));
  } else {
    // The minimum-version probe: cat(paste(R.version$major, ...)).
    process.stdout.write('4.5.1');
  }
} else if (lang === 'python') {
  if (args[0] === '--version') {
    process.stdout.write('Python 3.12.1\n');
  } else if (args[0] === '-c') {
    process.stdout.write('3.12.1\n');
  } else if (args[0] === '-m' && args[1] === 'venv') {
    const venvDir = args[args.length - 1];
    const exe = process.platform === 'win32' ? 'python.exe' : 'python3';
    makeWrapper(path.join(venvDir, 'bin', exe), 'python');
  } else if (args[0] === '-m' && args[1] === 'shiny') {
    runApp(args[args.indexOf('--app-dir') + 1], Number(args[args.indexOf('--port') + 1]));
  } else if (args[0] && args[0].endsWith('.py')) {
    // The missing-package check script: every requested package is missing.
    const pkgs = /pkgs = (\[.*\])/.exec(fs.readFileSync(args[0], 'utf8'));
    process.stdout.write(`${pkgs ? pkgs[1] : '[]'}\n`);
  }
} else if (lang === 'docker') {
  fakeDocker();
} else if (lang === 'container') {
  // A fake container: fake-runtime.js container <appDir> <hostPort>
  runApp(args[0], Number(args[1]));
} else if (lang === 'install') {
  // fake-runtime.js install <binDir>: write the wrappers.
  makeWrapper(path.join(args[0], 'Rscript'), 'R');
  makeWrapper(path.join(args[0], 'python3'), 'python');
  makeWrapper(path.join(args[0], 'docker'), 'docker');
}
