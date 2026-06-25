// Container backend -- runs Shiny app inside Docker/Podman container
const { EventEmitter } = require('events');
const { spawn, execFileSync } = require('child_process');
const fs = require('fs');
const os = require('os');
const path = require('path');
const { waitForServer, logDebug } = require('./utils');

class ContainerBackend extends EventEmitter {
  constructor() {
    super();
    this.containerId = null;
    this.containerEngine = null;
    this.containerHost = null;
  }

  /**
   * Resolve the container engine's daemon socket or named pipe.
   * For Podman, uses the machine socket or its default connection; for Docker,
   * tries the active context then platform-specific well-known locations.
   * @returns {string|null} Engine host URI (or "podman-default") or null.
   */
  resolveContainerHost() {
    const engine = this.containerEngine || 'docker';

    // Podman resolves its machine/connection from ~/.config/containers, so it
    // generally works without an explicit host env. Use the machine's socket
    // when one is exposed; otherwise verify it is reachable via the default
    // connection. (Runs cross-platform: `podman machine inspect` works the
    // same on macOS, Windows, and Linux.)
    if (engine === 'podman') {
      try {
        const sock = execFileSync('podman', ['machine', 'inspect', '--format', '{{.ConnectionInfo.PodmanSocket.Path}}'], {
          encoding: 'utf8', timeout: 5000, stdio: ['ignore', 'pipe', 'pipe']
        }).trim();
        if (sock && fs.existsSync(sock)) {
          logDebug(`Podman socket found: ${sock}`);
          return `unix://${sock}`;
        }
      } catch { /* no machine (e.g. native Linux Podman); fall through */ }
      try {
        execFileSync('podman', ['info'], { stdio: 'ignore', timeout: 8000 });
        return 'podman-default';
      } catch { /* not reachable */ }
      console.warn('Podman is not reachable');
      return null;
    }

    try {
      const ctx = execFileSync('docker', ['context', 'inspect', '--format', '{{.Endpoints.docker.Host}}'], {
        encoding: 'utf8', timeout: 5000, stdio: ['ignore', 'pipe', 'pipe']
      });
      const host = ctx.trim();
      if (host) {
        logDebug(`Docker endpoint from context: ${host}`);
        return host;
      }
    } catch { /* fall through */ }

    if (process.platform === 'win32') {
      const pipes = [
        'npipe:////./pipe/docker_engine',
        'npipe:////./pipe/dockerDesktopLinuxEngine'
      ];
      for (const pipe of pipes) {
        try {
          execFileSync('docker', ['-H', pipe, 'info'], { stdio: 'ignore', timeout: 5000 });
          logDebug(`Docker endpoint found: ${pipe}`);
          return pipe;
        } catch { /* try next */ }
      }
    } else {
      const sockets = [
        process.env.DOCKER_HOST,
        'unix:///var/run/docker.sock',
        `unix://${os.homedir()}/.docker/run/docker.sock`,
        `unix://${os.homedir()}/.colima/docker.sock`
      ].filter(Boolean);

      for (const sock of sockets) {
        const sockPath = sock.replace('unix://', '');
        if (fs.existsSync(sockPath)) {
          logDebug(`Docker socket found: ${sock}`);
          return sock;
        }
      }
    }

    console.warn('No Docker socket found');
    return null;
  }

  /**
   * Build an environment object with the engine host set: CONTAINER_HOST for
   * Podman, DOCKER_HOST for Docker (when a host was resolved).
   * @returns {object} Environment variables for child processes.
   */
  getContainerEnv() {
    const env = { ...process.env };
    // "podman-default" is a sentinel meaning "reachable via Podman's own
    // default connection", so no host override is needed in that case.
    if (this.containerHost && this.containerHost !== 'podman-default') {
      if (this.containerEngine === 'podman') {
        env.CONTAINER_HOST = this.containerHost;
      } else {
        env.DOCKER_HOST = this.containerHost;
      }
    }
    return env;
  }

  /**
   * Detect the container engine (docker or podman).
   * @param {object} config - Backend configuration.
   * @returns {string} Engine command ("docker" or "podman").
   */
  detectEngine(config) {
    if (config && config.container_engine) {
      return config.container_engine;
    }

    for (const engine of ['docker', 'podman']) {
      try {
        execFileSync(engine, ['--version'], { stdio: 'ignore', env: this.getContainerEnv() });
        return engine;
      } catch {
        // Not found, try next
      }
    }

    throw new Error(
      'Neither Docker nor Podman was found.\n\n' +
      'Install Docker: https://docs.docker.com/get-docker/\n' +
      'Install Podman: https://podman.io/getting-started/installation'
    );
  }

  /**
   * Select the appropriate container image for the app type.
   * @param {object} config - Backend configuration.
   * @returns {string} Full image reference.
   */
  selectImage(config) {
    if (config && typeof config.container_image === 'string' && config.container_image) {
      // If the image reference already carries a tag or digest, use it as-is;
      // only append the configured tag when none is present. A tag is the part
      // after the last ':' that follows the final '/' (host:port colons aside).
      const image = config.container_image;
      const lastSlash = image.lastIndexOf('/');
      const lastColon = image.lastIndexOf(':');
      const hasTag = image.includes('@') || lastColon > lastSlash;
      if (hasTag) return image;
      const tag = (config && config.container_tag) || 'latest';
      return `${image}:${tag}`;
    }

    const appType = (config && config.app_type) || 'r-shiny';
    const tag = (config && config.container_tag) || 'latest';

    let image;
    if (appType === 'r-shiny') {
      image = 'shinyelectron/r-shiny';
    } else if (appType === 'py-shiny') {
      image = 'shinyelectron/py-shiny';
    } else {
      image = 'shinyelectron/r-py-shiny';
    }

    return `${image}:${tag}`;
  }

  /**
   * Ensure the container image is available locally.
   * Tries local inspect first, then builds from an embedded Dockerfile,
   * or pulls from a registry as a fallback.
   * @param {string} image - Full image reference (name:tag).
   * @param {object} config - Backend configuration.
   */
  async ensureImage(image, config) {
    const env = this.getContainerEnv();
    const pullOnStart = config?.pull_on_start !== false; // default true
    const arch = process.arch === 'arm64' ? 'linux/arm64' : 'linux/amd64';

    // For a configured registry image with pull_on_start, refresh from the
    // registry rather than reusing a possibly-stale local copy.
    if (config?.container_image && pullOnStart) {
      this.emit('status', {
        phase: 'downloading_runtime',
        message: `Pulling image ${image}...`,
        percent: -1
      });
      try {
        execFileSync(this.containerEngine, ['pull', '--platform', arch, image],
          { stdio: 'inherit', env, timeout: 600000 });
        return;
      } catch (err) {
        // Pull failed (offline?); fall back to a local copy if one exists.
        try {
          execFileSync(this.containerEngine, ['image', 'inspect', image],
            { stdio: 'ignore', env, timeout: 10000 });
          logDebug(`Pull failed but image ${image} exists locally; using local copy`);
          return;
        } catch {
          throw new Error(
            `Failed to pull container image.\n\nImage: ${image}\n` +
            `Platform: ${arch}\nError: ${err.message}`
          );
        }
      }
    }

    // Check if image exists locally
    try {
      execFileSync(this.containerEngine, ['image', 'inspect', image], {
        stdio: 'ignore', env, timeout: 10000
      });
      logDebug(`Image ${image} found locally`);
      return;
    } catch {
      // Image not found locally
    }

    // Check if we have an embedded Dockerfile (local build)
    // Resolve ASAR-unpacked path for Dockerfile access
    let appBasePath = path.join(__dirname, '..');
    const unpackedBase = appBasePath.replace('app.asar', 'app.asar.unpacked');
    if (unpackedBase !== appBasePath && fs.existsSync(unpackedBase)) {
      appBasePath = unpackedBase;
    }
    const dockerfilePath = path.join(appBasePath, 'dockerfiles', 'Dockerfile');

    if (!config?.container_image && fs.existsSync(dockerfilePath)) {
      this.emit('status', {
        phase: 'downloading_runtime',
        message: 'Building container image (first launch)...',
        percent: -1
      });

      const dockerfileDir = path.join(appBasePath, 'dockerfiles');
      const platform = process.arch === 'arm64' ? 'linux/arm64' : 'linux/amd64';

      // Use buildx for reliable multi-platform builds
      let buildArgs;
      try {
        execFileSync(this.containerEngine, ['buildx', 'version'], { stdio: 'ignore', env });
        buildArgs = ['buildx', 'build', '--platform', platform, '--load', '--pull', '--progress=plain', '-t', image, dockerfileDir];
      } catch {
        buildArgs = ['build', '--platform', platform, '--pull', '--progress=plain', '-t', image, dockerfileDir];
      }

      // Use spawn (not execFileSync) so the event loop stays alive and
      // status events reach the lifecycle page during the build
      await new Promise((resolve, reject) => {
        const buildProc = spawn(this.containerEngine, buildArgs, {
          stdio: ['ignore', 'pipe', 'pipe'], env
        });

        let stderr = '';
        buildProc.stdout.on('data', (data) => {
          const line = data.toString().trim();
          if (line) {
            logDebug(`[docker build] ${line}`);
            this.emit('status', {
              phase: 'downloading_runtime',
              message: line.substring(0, 100)
            });
          }
        });
        buildProc.stderr.on('data', (data) => {
          const line = data.toString().trim();
          stderr += line + '\n';
          if (line) {
            logDebug(`[docker build] ${line}`);
            this.emit('status', {
              phase: 'downloading_runtime',
              message: line.substring(0, 100)
            });
          }
        });
        buildProc.on('close', (code) => {
          if (code === 0) {
            logDebug(`Built image: ${image}`);
            resolve();
          } else {
            reject(new Error(
              `Failed to build container image.\n\n` +
              `Image: ${image}\n` +
              `Error: ${stderr.trim()}\n\n` +
              `Ensure Docker is running and has internet access for pulling base images.`
            ));
          }
        });
        buildProc.on('error', (err) => {
          reject(new Error(`Failed to run docker build: ${err.message}`));
        });
      });
    } else if (config?.container_image) {
      this.emit('status', {
        phase: 'downloading_runtime',
        message: `Pulling image ${image}...`,
        percent: -1
      });

      const arch = process.arch === 'arm64' ? 'linux/arm64' : 'linux/amd64';
      try {
        execFileSync(
          this.containerEngine, ['pull', '--platform', arch, image],
          { stdio: 'inherit', env, timeout: 600000 }
        );
      } catch (err) {
        throw new Error(
          `Failed to pull container image.\n\n` +
          `Image: ${image}\n` +
          `Platform: ${arch}\n` +
          `Error: ${err.message}`
        );
      }
    } else {
      throw new Error(
        `Container image ${image} not found locally and no Dockerfile available.\n\n` +
        `Either:\n` +
        `- Set container.image in _shinyelectron.yml to a registry image\n` +
        `- Rebuild the app with the container strategy to embed the Dockerfile`
      );
    }
  }

  /**
   * Start the containerized Shiny server.
   * @param {object} options
   * @param {string} options.appPath - Path to the Shiny app directory.
   * @param {number} options.port - Port to expose.
   * @param {object} options.config - Backend configuration.
   * @returns {Promise<{port: number}>} Resolves when container is ready.
   */
  async start({ appPath, port, config }) {
    // Note: do NOT removeAllListeners() here; it would wipe the main process's
    // 'status'/'error' subscribers. This backend registers no one-shot
    // internal listeners, so there is nothing to clear.
    // Detect the engine first so the host resolution below is engine-aware
    // (detectEngine only runs `<engine> --version`, which needs no daemon).
    this.emit('status', { phase: 'finding_runtime', message: 'Detecting container engine...' });

    try {
      this.containerEngine = this.detectEngine(config || {});
    } catch (err) {
      this.emit('status', { phase: 'error', message: err.message });
      throw err;
    }

    this.containerHost = this.resolveContainerHost();
    if (!this.containerHost) {
      const isPodman = this.containerEngine === 'podman';
      const err = new Error(
        `Cannot connect to ${isPodman ? 'Podman' : 'Docker'}.\n\n` +
        (isPodman
          ? 'Start the Podman machine with: podman machine start\n' +
            '(On native Linux, ensure the Podman service is available.)'
          : 'Ensure Docker Desktop is running, or check your Docker installation.\n' +
            'On macOS: Open Docker Desktop from Applications.\n' +
            'On Windows: Start Docker Desktop from the Start Menu.\n' +
            'On Linux: Run "sudo systemctl start docker"')
      );
      this.emit('status', { phase: 'error', message: err.message });
      throw err;
    }

    const image = this.selectImage(config || {});

    this.emit('status', {
      phase: 'runtime_found',
      message: `Using ${this.containerEngine === 'docker' ? 'Docker' : 'Podman'}`
    });

    logDebug(`Starting container with ${this.containerEngine}...`);
    logDebug(`Image: ${image}`);
    logDebug(`App path: ${appPath}`);
    logDebug(`Port: ${port}`);

    // Ensure image is available (build locally or pull from registry)
    await this.ensureImage(image, config);

    this.emit('status', { phase: 'starting_server', message: 'Starting container...' });

    // Let Docker assign a free host port on the loopback interface. Picking a
    // port ourselves races other container apps (two can both see a port as
    // free and then collide on `docker run -p`); Docker's allocation is atomic.
    // Binding to 127.0.0.1 also keeps the container off the local network.
    // The assigned host port is read back from `docker port` after the run.
    const containerPort = port;

    // Build docker run arguments
    const args = [
      'run', '-d',
      '-p', `127.0.0.1::${containerPort}`,
      '-v', `${appPath}:/app`,
      '-e', `PORT=${containerPort}`,
      '-e', `HOST=0.0.0.0`
    ];

    // Note: dependencies are baked into the image at build time.
    // We no longer mount a cache volume over the package directory
    // as that hides the pre-installed packages.

    // Add extra volumes from config
    if (config && config.container_volumes && typeof config.container_volumes === 'object') {
      for (const [hostPath, containerPath] of Object.entries(config.container_volumes)) {
        args.push('-v', `${hostPath}:${containerPath}`);
      }
    }

    // Add extra env vars from config
    if (config && config.container_env && typeof config.container_env === 'object') {
      for (const [key, value] of Object.entries(config.container_env)) {
        args.push('-e', `${key}=${value}`);
      }
    }

    args.push(image);

    return new Promise((resolve, reject) => {
      logDebug(`Running: ${this.containerEngine} ${args.join(' ')}`);

      const proc = spawn(this.containerEngine, args, {
        stdio: ['ignore', 'pipe', 'pipe'],
        env: this.getContainerEnv()
      });

      let stdout = '';
      let stderr = '';

      proc.stdout.on('data', (data) => { stdout += data.toString(); });
      proc.stderr.on('data', (data) => { stderr += data.toString(); });

      proc.on('close', (code) => {
        if (code !== 0) {
          const err = new Error(
            `Failed to start container (exit code ${code})\n` +
            `Engine: ${this.containerEngine}\n` +
            `Image: ${image}\n` +
            `Error: ${stderr}`
          );
          this.emit('status', { phase: 'error', message: err.message, detail: { stderr } });
          reject(err);
          return;
        }

        this.containerId = stdout.trim().substring(0, 12);
        logDebug(`Container started: ${this.containerId}`);

        // Read the host port Docker assigned (output like "127.0.0.1:54321").
        let hostPort;
        try {
          const portOut = execFileSync(
            this.containerEngine, ['port', this.containerId, `${containerPort}/tcp`],
            { encoding: 'utf8', env: this.getContainerEnv() }
          ).trim();
          const match = portOut.split('\n')[0].match(/:(\d+)\s*$/);
          hostPort = match ? parseInt(match[1], 10) : null;
        } catch {
          hostPort = null;
        }
        if (!hostPort) {
          this.emit('status', { phase: 'error', message: 'Could not determine the container host port' });
          reject(new Error('Could not determine the container host port'));
          return;
        }
        logDebug(`Container ${this.containerId} mapped ${containerPort} -> host ${hostPort}`);

        // Stream container logs while waiting for startup
        const logProc = spawn(this.containerEngine, ['logs', '-f', this.containerId], {
          stdio: ['ignore', 'pipe', 'pipe'],
          env: this.getContainerEnv()
        });
        logProc.on('error', () => {}); // ignore EPIPE
        logProc.stdout.on('data', (data) => {
          try {
            const msg = data.toString().trim();
            if (msg) {
              logDebug(`[container] ${msg}`);
              this.emit('status', { phase: 'starting_server', message: msg });
            }
          } catch { /* ignore write errors after shutdown */ }
        });
        logProc.stderr.on('data', (data) => {
          try {
            const msg = data.toString().trim();
            if (msg) logDebug(`[container] ${msg}`);
          } catch { /* ignore */ }
        });

        // Wait for the server to be ready (longer timeout for container startup)
        waitForServer(hostPort, { timeout: 120000, interval: 1000 })
          .then(() => {
            logProc.kill();
            logDebug(`Container server ready on http://localhost:${hostPort}`);
            this.emit('status', { phase: 'server_ready', message: 'Container ready' });
            resolve({ port: hostPort });
          })
          .catch((err) => {
            logProc.kill();
            // Get container logs for debugging
            try {
              const logs = execFileSync(this.containerEngine, ['logs', this.containerId], { encoding: 'utf8', env: this.getContainerEnv() });
              console.error(`Container logs:\n${logs}`);
            } catch { /* ignore */ }

            this.stop();
            const startErr = new Error(
              `Container server failed to start within 120 seconds.\n\n` +
              `Container ID: ${this.containerId}\n` +
              `Image: ${image}\n\n` +
              `Possible causes:\n` +
              `- Container image does not contain required dependencies\n` +
              `- App has errors that prevent it from starting\n` +
              `- Port ${port} conflict inside the container`
            );
            this.emit('status', { phase: 'error', message: startErr.message });
            reject(startErr);
          });
      });

      proc.on('error', (err) => {
        const runErr = new Error(`Failed to run ${this.containerEngine}: ${err.message}`);
        this.emit('status', { phase: 'error', message: runErr.message });
        reject(runErr);
      });
    });
  }

  /**
   * Stop and remove the container.
   */
  stop() {
    if (this.containerId && this.containerEngine) {
      const id = this.containerId;
      const engine = this.containerEngine;
      const env = this.getContainerEnv();
      this.containerId = null; // mark stopped so a repeat stop() is a no-op

      const short = id.substring(0, 12);
      this.emit('status', { phase: 'stopping_server', message: `Stopping container ${short}...` });
      logDebug(`Stopping container ${id}...`);

      // Stop and remove asynchronously and detached. `docker/podman stop` blocks
      // for the container's stop grace period (10s by default), and doing that
      // synchronously freezes the main/UI thread so the shutdown screen can't
      // render. Run it detached (and `-t 3` to shorten the grace) so the UI is
      // free immediately; the child finishes even if the app quits first. Each
      // stage emits a status so the shutdown screen can show the breakdown.
      const done = (message) => this.emit('status', { phase: 'app_exit', message });
      try {
        const proc = spawn(engine, ['stop', '-t', '3', id], { stdio: 'ignore', env, detached: true });
        proc.on('error', (err) => {
          console.warn(`Failed to stop container: ${err.message}`);
          done('Shutdown complete');
        });
        proc.on('close', () => {
          this.emit('status', { phase: 'cleanup', message: 'Removing container...' });
          try {
            const rm = spawn(engine, ['rm', '-f', id], { stdio: 'ignore', env, detached: true });
            rm.on('error', () => done('Shutdown complete'));
            rm.on('close', () => done('Container removed. Shutting down...'));
            rm.unref();
          } catch { done('Shutdown complete'); }
        });
        proc.unref();
      } catch (err) {
        console.warn(`Failed to stop container: ${err.message}`);
        done('Shutdown complete');
      }
    } else {
      // Nothing to tear down, but still signal completion so the shutdown
      // flow can proceed promptly.
      this.emit('status', { phase: 'app_exit', message: 'Shutting down...' });
    }
  }
}

module.exports = new ContainerBackend();
