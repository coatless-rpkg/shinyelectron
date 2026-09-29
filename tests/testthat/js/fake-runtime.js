// Stand-in for Rscript and python3 used by backend-lifecycle.js.
// Called through small shell wrappers as: fake-runtime.js <R|python> <args...>
// A Shiny "run" reads <appDir>/fake-mode.json to decide how to behave:
//   serve  answer every HTTP request with 404 and log the request
//   hang   never bind the port
//   crash  print an error and exit with status 1
// With holdStdio: <ms>, it also starts a helper that keeps its stdout and
// stderr open for that long. Every run is recorded in <appDir>/fake-runs.log.
// `fake-runtime.js install <dir>` writes the Rscript and python3 wrappers.
'use strict';

const fs = require('fs');
const http = require('http');
const path = require('path');
const { spawn } = require('child_process');

const [lang, ...args] = process.argv.slice(2);

function appendLine(file, line) {
  fs.appendFileSync(file, line + '\n');
}

function runApp(appDir, port) {
  let mode = { mode: 'serve' };
  try {
    mode = JSON.parse(fs.readFileSync(path.join(appDir, 'fake-mode.json'), 'utf8'));
  } catch { /* default mode */ }
  appendLine(path.join(appDir, 'fake-runs.log'), `${process.pid} ${port}`);

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
  if (args[0] === '--version') {
    process.stdout.write('Rscript (R) version 4.5.1\n');
  } else if (run) {
    runApp(run[1], Number(run[2]));
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
  }
} else if (lang === 'install') {
  // fake-runtime.js install <binDir>: write the Rscript and python3 wrappers.
  makeWrapper(path.join(args[0], 'Rscript'), 'R');
  makeWrapper(path.join(args[0], 'python3'), 'python');
}
