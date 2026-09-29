// Drives the real native-r.js, native-py.js, container.js and utils.js under
// plain Node (no Electron) against fake Rscript, python3 and docker
// executables (fake-runtime.js).
// Usage: node backend-lifecycle.js <backends-dir> <results.json> [name-regex]
// Writes a JSON array of { name, ok, ms, message } and exits 0.
'use strict';

const fs = require('fs');
const net = require('net');
const http = require('http');
const os = require('os');
const path = require('path');
const { execFileSync } = require('child_process');

const backendsDir = path.resolve(process.argv[2]);
const resultsFile = process.argv[3];
const filter = process.argv[4] ? new RegExp(process.argv[4]) : null;

const work = fs.mkdtempSync(path.join(os.tmpdir(), 'shinyelectron-lifecycle-'));
const binDir = path.join(work, 'bin');
const dockerState = path.join(work, 'docker');
execFileSync(process.execPath, [path.join(__dirname, 'fake-runtime.js'), 'install', binDir]);
process.env.PATH = binDir + path.delimiter + process.env.PATH;
process.env.FAKE_DOCKER_STATE = dockerState;
process.env.FAKE_HARNESS_PID = String(process.pid);

const utils = require(path.join(backendsDir, 'utils.js'));
const NativeR = require(path.join(backendsDir, 'native-r.js')).constructor;
const NativePy = require(path.join(backendsDir, 'native-py.js')).constructor;
const Container = require(path.join(backendsDir, 'container.js')).constructor;

// ---- helpers ----------------------------------------------------------------

const delay = (ms) => new Promise((resolve) => setTimeout(resolve, ms));

const usedPorts = new Set();
async function freePort() {
  for (;;) {
    const port = await new Promise((resolve, reject) => {
      const srv = net.createServer();
      srv.once('error', reject);
      srv.listen(0, '127.0.0.1', () => {
        const p = srv.address().port;
        srv.close(() => resolve(p));
      });
    });
    if (!usedPorts.has(port)) {
      usedPorts.add(port);
      return port;
    }
  }
}

let appCounter = 0;
function makeApp(mode) {
  const dir = path.join(work, 'apps', `app${++appCounter}`);
  fs.mkdirSync(dir, { recursive: true });
  fs.writeFileSync(path.join(dir, 'fake-mode.json'), JSON.stringify(mode));
  return dir;
}

function readLines(file) {
  if (!fs.existsSync(file)) return [];
  return fs.readFileSync(file, 'utf8').split('\n').filter(Boolean);
}
const runsOf = (app) => readLines(path.join(app, 'fake-runs.log'));
const requestsOf = (app) => readLines(path.join(app, 'fake-requests.log'));
const dockerCalls = () => readLines(path.join(dockerState, 'calls.log'));

function isAlive(pid) {
  try {
    process.kill(pid, 0);
    return true;
  } catch {
    return false;
  }
}

function record(backend) {
  const events = [];
  backend.on('status', (d) => events.push(d));
  return events;
}
const phases = (events) => events.map((e) => e.phase);

const isRunning = (child) => child.exitCode === null && child.signalCode === null;

async function waitFor(pred, ms, what) {
  const deadline = Date.now() + ms;
  for (;;) {
    const value = pred();
    if (value) return value;
    if (Date.now() > deadline) throw new Error(`timed out waiting for ${what}`);
    await delay(20);
  }
}

// Settle a promise within ms or fail; returns { ok, value, error }.
function within(promise, ms, what) {
  let timer;
  const timeout = new Promise((_, reject) => {
    timer = setTimeout(() => reject(new Error(`timed out waiting for ${what}`)), ms);
  });
  return Promise.race([
    Promise.resolve(promise).then((value) => ({ ok: true, value }), (error) => ({ ok: false, error })),
    timeout
  ]).finally(() => clearTimeout(timer));
}

// Mark a promise as handled now; scenarios inspect its result later.
function handled(promise) {
  promise.catch(() => {});
  return promise;
}

function assert(cond, message) {
  if (!cond) throw new Error(message);
}
function assertEqual(actual, expected, message) {
  const a = JSON.stringify(actual);
  const e = JSON.stringify(expected);
  if (a !== e) throw new Error(`${message}: expected ${e}, got ${a}`);
}

// Every backend a scenario creates, so the runner can stop them all even when
// a scenario fails halfway.
const created = [];
function newBackend(Backend) {
  const be = new Backend();
  created.push(be);
  return be;
}

const config = (extra) => Object.assign(
  { runtime_strategy: 'system', app_slug: 'lifecycle-test' },
  extra
);

// ---- scenarios --------------------------------------------------------------

// Scenarios in the same lane run one after another; lanes run concurrently.
const tests = [];
const test = (lane, name, fn) => tests.push({ lane, name, fn });

const PROBE = 'GET /__shinyelectron_ready__';
const SUPERSEDED = 'START_SUPERSEDED';

async function startRunning(be, handle, extra) {
  const app = makeApp({ mode: 'serve', ...extra });
  const res = await within(
    be.start({ appPath: app, port: await freePort(), config: config({ startup_timeout: 20000 }) }),
    25000, 'start()'
  );
  assert(res.ok, `start() failed: ${res.error && res.error.message}`);
  const child = be[handle];
  assert(child && isRunning(child), 'the server child is running');
  return { app, child };
}

for (const [label, Backend, handle] of [['R', NativeR, 'rProcess'], ['Python', NativePy, 'pyProcess']]) {
  const stopPhases = ['stopping_server', 'app_exit'];
  const idleStopPhases = label === 'R' ? ['stopping_server', 'app_exit'] : ['app_exit'];

  test(label, `${label}: start() probes readiness without requesting the UI`, async () => {
    const be = newBackend(Backend);
    const { app } = await startRunning(be, handle);
    const requests = requestsOf(app);
    assert(requests.length > 0, 'the server saw the probe');
    assert(requests.every((r) => r === PROBE), `requests: ${requests}`);
    await be.stop();
  });

  test(label, `${label}: stop() emits its statuses at once and resolves after the child exits`, async () => {
    const be = newBackend(Backend);
    const events = record(be);
    const { child } = await startRunning(be, handle);
    const mark = events.length;
    const stopped = be.stop();
    assertEqual(phases(events.slice(mark)), stopPhases, 'statuses emitted by stop()');
    assert(stopped && typeof stopped.then === 'function', 'stop() returns a promise');
    const res = await within(stopped, 5000, 'stop() to resolve');
    assert(res.ok, 'stop() resolves');
    assert(!isRunning(child), 'the child has exited when stop() resolves');
    assert(be[handle] === null, 'handle cleared');
    await delay(300);
    const all = phases(events);
    assert(!all.includes('server_crashed') && !all.includes('error'), `statuses: ${all}`);
  });

  test(label, `${label}: stop() without a running server`, async () => {
    const be = newBackend(Backend);
    const events = record(be);
    const res = await within(be.stop(), 1000, 'stop() to resolve');
    assert(res.ok, 'stop() resolves');
    assertEqual(phases(events), idleStopPhases, 'statuses');
  });

  test(label, `${label}: a crash of the current child is reported`, async () => {
    const be = newBackend(Backend);
    const events = record(be);
    const app = makeApp({ mode: 'crash' });
    const res = await within(
      be.start({ appPath: app, port: await freePort(), config: config({ startup_timeout: 20000 }) }),
      25000, 'start()'
    );
    assert(!res.ok, 'start() rejects');
    assert(/exited unexpectedly \(code 1\)/.test(res.error.message), `message: ${res.error.message}`);
    assert(phases(events).includes('server_crashed'), `statuses: ${phases(events)}`);
    assert(be[handle] === null, 'handle cleared');
  });

  test(label, `${label}: a startup timeout ends on the error status`, async () => {
    const be = newBackend(Backend);
    const events = record(be);
    const app = makeApp({ mode: 'hang' });
    const p = handled(be.start({ appPath: app, port: await freePort(), config: config({ startup_timeout: 1200 }) }));
    const child = await waitFor(() => be[handle], 10000, 'the child to spawn');
    const res = await within(p, 15000, 'start() to settle');
    assert(!res.ok, 'start() rejects');
    assert(/within 1\.2 seconds/.test(res.error.message), `message: ${res.error.message}`);
    await waitFor(() => !isRunning(child), 5000, 'the timed-out child to exit');
    await delay(700);
    const all = phases(events);
    assertEqual(all[all.length - 1], 'error', 'last status');
    for (const phase of ['stopping_server', 'app_exit', 'server_crashed']) {
      assert(!all.includes(phase), `unexpected ${phase} in ${all}`);
    }
    assert(events[events.length - 1].detail && typeof events[events.length - 1].detail.stderr === 'string',
      'the error carries the stderr detail');
    assert(be[handle] === null, 'handle cleared');
  });

  test(label, `${label}: stop() during startup keeps the start from spawning`, async () => {
    const be = newBackend(Backend);
    const events = record(be);
    const app = makeApp({ mode: 'serve' });
    const p = handled(be.start({ appPath: app, port: await freePort(), config: config({ startup_timeout: 10000 }) }));
    const mark = events.length;
    be.stop();
    const res = await within(p, 5000, 'start() to settle');
    assert(!res.ok && res.error.code === SUPERSEDED, `start() result: ${res.ok ? 'resolved' : res.error.message}`);
    await delay(700);
    assertEqual(runsOf(app).length, 0, 'servers spawned');
    assert(be[handle] === null, 'no handle');
    assertEqual(phases(events.slice(mark)), idleStopPhases, 'statuses after stop()');
  });

  test(label, `${label}: stop() during the readiness wait settles the start quietly`, async () => {
    const be = newBackend(Backend);
    const events = record(be);
    const app = makeApp({ mode: 'hang' });
    const p = handled(be.start({ appPath: app, port: await freePort(), config: config({ startup_timeout: 10000 }) }));
    const child = await waitFor(() => be[handle], 10000, 'the child to spawn');
    const mark = events.length;
    be.stop();
    const res = await within(p, 3000, 'start() to settle');
    assert(!res.ok && res.error.code === SUPERSEDED, `start() result: ${res.ok ? 'resolved' : res.error.message}`);
    await waitFor(() => !isRunning(child), 5000, 'the child to exit');
    await delay(500);
    assertEqual(phases(events.slice(mark)), stopPhases, 'statuses after stop()');
  });

  test(label, `${label}: a superseded start leaves the next server alone`, async () => {
    const be = newBackend(Backend);
    const events = record(be);
    const appA = makeApp({ mode: 'hang' });
    const t0 = Date.now();
    const a = handled(be.start({ appPath: appA, port: await freePort(), config: config({ startup_timeout: 1500 }) }));
    await waitFor(() => be[handle], 10000, 'A to spawn');
    be.stop();
    const ra = await within(a, 3000, 'A to settle');
    assert(!ra.ok && ra.error.code === SUPERSEDED, `A result: ${ra.ok ? 'resolved' : ra.error.message}`);
    const { child: childB } = await startRunning(be, handle);
    const mark = events.length;
    await delay(Math.max(0, t0 + 3000 - Date.now()));
    assert(be[handle] === childB && isRunning(childB), 'B is still the running server after A\'s deadline');
    assertEqual(phases(events.slice(mark)), [], 'statuses after B was ready');
    await be.stop();
  });

  test(label, `${label}: a superseded start never reports its child's exit as a crash`, async () => {
    const be = newBackend(Backend);
    const events = record(be);
    const app = makeApp({ mode: 'hang', termExitCode: 1 });
    const p = handled(be.start({ appPath: app, port: await freePort(), config: config({ startup_timeout: 10000 }) }));
    const child = await waitFor(() => be[handle], 10000, 'the child to spawn');
    const mark = events.length;
    // Supersede the start the way a newer start() does before it has spawned
    // a child of its own, so this start's child is still the current one.
    be.startToken++;
    const res = await within(p, 3000, 'start() to settle');
    assert(!res.ok && res.error.code === SUPERSEDED, `start() result: ${res.ok ? 'resolved' : res.error.message}`);
    await waitFor(() => !isRunning(child), 5000, 'the child to exit');
    await delay(300);
    assertEqual(phases(events.slice(mark)), [], 'statuses after the start was superseded');
    assert(be[handle] === null, 'the exited child is no longer the handle');
  });

  test(label, `${label}: a newer start() stops the child of the start it replaces`, async () => {
    const be = newBackend(Backend);
    const appA = makeApp({ mode: 'hang' });
    const a = handled(be.start({ appPath: appA, port: await freePort(), config: config({ startup_timeout: 10000 }) }));
    const childA = await waitFor(() => be[handle], 10000, 'A to spawn');
    const { child: childB } = await startRunning(be, handle);
    const ra = await within(a, 3000, 'A to settle');
    assert(!ra.ok && ra.error.code === SUPERSEDED, `A result: ${ra.ok ? 'resolved' : ra.error.message}`);
    await waitFor(() => !isRunning(childA), 5000, 'A\'s child to exit');
    assert(be[handle] === childB && isRunning(childB), 'B is the running server');
    await be.stop();
  });
}

const containerConfig = (extra) => config({ container_engine: 'docker', ...extra });

test('container', 'Container: a startup timeout ends on the error status and removes its container', async () => {
  const be = newBackend(Container);
  const events = record(be);
  const app = makeApp({ mode: 'hang' });
  const res = await within(
    be.start({ appPath: app, port: 3838, config: containerConfig({ startup_timeout: 1200 }) }),
    20000, 'start()'
  );
  assert(!res.ok, 'start() rejects');
  assert(/within 1\.2 seconds/.test(res.error.message), `message: ${res.error.message}`);
  const id = (/Container ID: ([0-9a-f]{12})\n/.exec(res.error.message) || [])[1];
  assert(id, `the message names the container: ${res.error.message}`);
  await waitFor(() => dockerCalls().includes(`rm -f ${id}`), 5000, 'the container to be removed');
  const pid = Number(runsOf(app)[0].split(' ')[0]);
  await waitFor(() => !isAlive(pid), 5000, 'the container to exit');
  await delay(500);
  const all = phases(events);
  assertEqual(all[all.length - 1], 'error', 'last status');
  for (const phase of ['stopping_server', 'cleanup', 'app_exit']) {
    assert(!all.includes(phase), `unexpected ${phase} in ${all}`);
  }
  assert(be.containerId === null, 'containerId cleared');
});

test('container', 'Container: stop() during startup keeps the start from creating a container', async () => {
  const be = newBackend(Container);
  const events = record(be);
  const app = makeApp({ mode: 'serve' });
  const p = handled(be.start({ appPath: app, port: 3838, config: containerConfig({ startup_timeout: 10000 }) }));
  const mark = events.length;
  be.stop();
  const res = await within(p, 5000, 'start() to settle');
  assert(!res.ok && res.error.code === SUPERSEDED, `start() result: ${res.ok ? 'resolved' : res.error.message}`);
  await delay(700);
  assert(!dockerCalls().some((c) => c.startsWith('run ') && c.includes(app)), 'no container was created');
  assertEqual(phases(events.slice(mark)), ['app_exit'], 'statuses after stop()');
});

test('container', 'Container: stop() during the readiness wait settles the start quietly', async () => {
  const be = newBackend(Container);
  const events = record(be);
  const app = makeApp({ mode: 'hang' });
  const p = handled(be.start({ appPath: app, port: 3838, config: containerConfig({ startup_timeout: 10000 }) }));
  const id = await waitFor(() => be.containerId, 10000, 'the container to start');
  const mark = events.length;
  const stopped = be.stop();
  const res = await within(p, 4000, 'start() to settle');
  assert(!res.ok && res.error.code === SUPERSEDED, `start() result: ${res.ok ? 'resolved' : res.error.message}`);
  const rs = await within(stopped, 5000, 'stop() to resolve');
  assert(rs.ok, 'stop() resolves');
  await delay(300);
  assertEqual(phases(events.slice(mark)), ['stopping_server', 'cleanup', 'app_exit'], 'statuses after stop()');
  assertEqual(dockerCalls().filter((c) => c === `rm -f ${id}`).length, 1, 'removals of the container');
});

test('container', 'Container: a superseded start leaves the next container alone', async () => {
  const be = newBackend(Container);
  const events = record(be);
  const appA = makeApp({ mode: 'hang' });
  const t0 = Date.now();
  const a = handled(be.start({ appPath: appA, port: 3838, config: containerConfig({ startup_timeout: 1500 }) }));
  await waitFor(() => be.containerId, 10000, 'A\'s container to start');
  be.stop();
  const ra = await within(a, 4000, 'A to settle');
  assert(!ra.ok && ra.error.code === SUPERSEDED, `A result: ${ra.ok ? 'resolved' : ra.error.message}`);
  const appB = makeApp({ mode: 'serve' });
  const rb = await within(
    be.start({ appPath: appB, port: 3838, config: containerConfig({ startup_timeout: 20000 }) }),
    20000, 'B to start'
  );
  assert(rb.ok, `B failed: ${rb.error && rb.error.message}`);
  const idB = be.containerId;
  const mark = events.length;
  await delay(Math.max(0, t0 + 3500 - Date.now()));
  assert(be.containerId === idB, 'B is still the current container after A\'s deadline');
  const calls = dockerCalls();
  assert(!calls.includes(`stop -t 3 ${idB}`) && !calls.includes(`rm -f ${idB}`), 'B was not torn down');
  assertEqual(phases(events.slice(mark)), [], 'statuses after B was ready');
  assert(requestsOf(appB).every((r) => r === PROBE), `requests: ${requestsOf(appB)}`);
  // The teardown runs in detached, unreferenced processes, so give the event
  // loop a timer to stay alive on while it finishes.
  await within(be.stop(), 10000, 'stop() to resolve');
});

test('R', 'stop() does not wait for helpers holding the child\'s output open', async () => {
  const be = newBackend(NativeR);
  const { app, child } = await startRunning(be, 'rProcess', { holdStdio: 5000 });
  let closed = false;
  child.once('close', () => { closed = true; });
  try {
    const res = await within(be.stop(), 2500, 'stop() to resolve');
    assert(res.ok, 'stop() resolves');
    assert(!closed, 'stop() resolved before the output pipes closed');
  } finally {
    for (const pid of readLines(path.join(app, 'fake-helpers.log'))) {
      try { process.kill(Number(pid)); } catch { /* already gone */ }
    }
  }
});

test('probe', 'waitForServer probes 127.0.0.1 on a path apps do not serve', async () => {
  const seen = [];
  const server = http.createServer((req, res) => {
    seen.push(`${req.method} ${req.url}`);
    res.statusCode = 404;
    res.end();
  });
  await new Promise((resolve) => server.listen(0, '127.0.0.1', resolve));
  try {
    const res = await within(utils.waitForServer(server.address().port, { timeout: 5000 }), 6000, 'waitForServer');
    assert(res.ok, `waitForServer failed: ${res.error && res.error.message}`);
    assertEqual(seen, [PROBE], 'requests');
  } finally {
    server.close();
  }
});

test('probe', 'waitForServer keeps one attempt in flight when the server never answers', async () => {
  let connections = 0;
  const sockets = new Set();
  const server = net.createServer((socket) => {
    connections++;
    sockets.add(socket);
    socket.on('close', () => sockets.delete(socket));
  });
  await new Promise((resolve) => server.listen(0, '127.0.0.1', resolve));
  try {
    const res = await within(
      utils.waitForServer(server.address().port, { timeout: 2000, interval: 100, attemptTimeout: 300 }),
      5000, 'waitForServer'
    );
    assert(!res.ok, 'waitForServer rejects');
    // One attempt every ~400 ms gives about 5; doubling retries would give 31.
    assert(connections >= 2 && connections <= 8, `connections: ${connections}`);
  } finally {
    for (const s of sockets) s.destroy();
    server.close();
  }
});

test('probe', 'waitForServer stops polling once cancelled', async () => {
  const port = await freePort();
  const t0 = Date.now();
  const res = await within(
    utils.waitForServer(port, { timeout: 10000, interval: 100, isCancelled: () => Date.now() - t0 > 300 }),
    3000, 'waitForServer'
  );
  assert(!res.ok, 'waitForServer rejects');
  assert(Date.now() - t0 < 2000, 'rejected soon after cancellation');
});

// ---- runner -----------------------------------------------------------------

(async () => {
  const selected = tests.filter((t) => !filter || filter.test(t.name));
  const lanes = new Map();
  for (const t of selected) {
    if (!lanes.has(t.lane)) lanes.set(t.lane, []);
    lanes.get(t.lane).push(t);
  }
  const results = [];
  await Promise.all([...lanes.values()].map(async (lane) => {
    for (const t of lane) {
      const t0 = Date.now();
      try {
        await t.fn();
        results.push({ name: t.name, ok: true, ms: Date.now() - t0 });
      } catch (err) {
        results.push({ name: t.name, ok: false, ms: Date.now() - t0, message: String(err && err.stack || err) });
      }
    }
  }));
  fs.writeFileSync(resultsFile, JSON.stringify(results, null, 1));
  try {
    await within(Promise.all(created.map((be) => be.stop())), 5000, 'backends to stop');
  } catch { /* the fake runtimes also exit on their own once we are gone */ }
  try { fs.rmSync(work, { recursive: true, force: true }); } catch { /* best effort */ }
  process.exit(0);
})();
