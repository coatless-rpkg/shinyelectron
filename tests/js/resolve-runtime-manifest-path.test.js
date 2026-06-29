// tests/js/resolve-runtime-manifest-path.test.js
const test = require('node:test');
const assert = require('node:assert');
const path = require('path');
const { resolveRuntimeManifestPath } = require('../../inst/electron/backends/utils');

test('resolveRuntimeManifestPath: single-app src/app', () => {
  const appPath = path.join('/opt', 'app', 'src', 'app');
  assert.strictEqual(
    resolveRuntimeManifestPath(appPath),
    path.join(appPath, 'runtime-manifest.json')
  );
});

test('resolveRuntimeManifestPath: multi-app src/apps/<id>', () => {
  const appPath = path.join('/opt', 'app', 'src', 'apps', 'dashboard');
  assert.strictEqual(
    resolveRuntimeManifestPath(appPath),
    path.join(appPath, 'runtime-manifest.json')
  );
});
