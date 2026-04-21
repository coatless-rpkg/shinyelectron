// Container backend — runs Shiny app inside Docker/Podman container
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
    this.dockerHost = null;
  }

  /**
   * Resolve the Docker daemon socket or named pipe.
   * Tries docker context, then platform-specific well-known locations.
   * @returns {string|null} Docker host URI or null if not found.
   */
  resolveDockerHost() {
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
        'npipe:////./pipe/dockerDesktopLinuxEngine',
        'npipe:////./pipe/podman-machine-default'
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
   * Build an environment object that includes DOCKER_HOST if resolved.
   * @returns {object} Environment variables for child processes.
   */
  getDockerEnv() {
    const env = { ...process.env };
    if (this.dockerHost) {
      env.DOCKER_HOST = this.dockerHost;
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
        execFileSync(engine, ['--version'], { stdio: 'ignore', env: this.getDockerEnv() });
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
    if (config && config.container_image) {
      const tag = (config && config.container_tag) || 'latest';
      return `${config.container_image}:${tag}`;
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
    const env = this.getDockerEnv();

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
    this.removeAllListeners();
    this.dockerHost = this.resolveDockerHost();
    if (!this.dockerHost) {
      const err = new Error(
        'Cannot find Docker daemon.\n\n' +
        'Ensure Docker Desktop is running, or check your Docker installation.\n' +
        'On macOS: Open Docker Desktop from Applications.\n' +
        'On Windows: Start Docker Desktop from the Start Menu.\n' +
        'On Linux: Run "sudo systemctl start docker"'
      );
      this.emit('status', { phase: 'error', message: err.message });
      throw err;
    }

    this.emit('status', { phase: 'finding_runtime', message: 'Detecting container engine...' });

    try {
      this.containerEngine = this.detectEngine(config || {});
    } catch (err) {
      this.emit('error', err);
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

    // Find an available host port (container always listens on its internal port)
    const { findAvailablePort } = require('./utils');
    const containerPort = port;
    const hostPort = await findAvailablePort(port, 10, (attempted, next) => {
      this.emit('status', { phase: 'port_conflict', message: `Port ${attempted} in use, trying ${next}...` });
    });

    // Build docker run arguments
    const args = [
      'run', '-d',
      '-p', `${hostPort}:${containerPort}`,
      '-v', `${appPath}:/app`,
      '-e', `PORT=${containerPort}`,
      '-e', `HOST=0.0.0.0`
    ];

    // App slug for volume naming
    const appSlug = (config && config.app_slug) || 'shinyelectron-app';
    const appType = (config && config.app_type) || 'r-shiny';
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
        env: this.getDockerEnv()
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
          this.emit('error', err);
          reject(err);
          return;
        }

        this.containerId = stdout.trim().substring(0, 12);
        logDebug(`Container started: ${this.containerId}`);

        // Stream container logs while waiting for startup
        const logProc = spawn(this.containerEngine, ['logs', '-f', this.containerId], {
          stdio: ['ignore', 'pipe', 'pipe'],
          env: this.getDockerEnv()
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
              const logs = execFileSync(this.containerEngine, ['logs', this.containerId], { encoding: 'utf8', env: this.getDockerEnv() });
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
            this.emit('error', startErr);
            reject(startErr);
          });
      });

      proc.on('error', (err) => {
        const runErr = new Error(`Failed to run ${this.containerEngine}: ${err.message}`);
        this.emit('error', runErr);
        reject(runErr);
      });
    });
  }

  /**
   * Stop and remove the container.
   */
  stop() {
    if (this.containerId && this.containerEngine) {
      this.emit('status', { phase: 'stopping_server', message: `Stopping container...` });
      logDebug(`Stopping container ${this.containerId}...`);
      try {
        execFileSync(this.containerEngine, ['stop', this.containerId], { stdio: 'ignore', timeout: 10000, env: this.getDockerEnv() });
      } catch (err) {
        console.warn(`Failed to stop container gracefully: ${err.message}`);
      }

      this.emit('status', { phase: 'cleanup', message: 'Removing container...' });
      try {
        execFileSync(this.containerEngine, ['rm', '-f', this.containerId], { stdio: 'ignore', env: this.getDockerEnv() });
      } catch (err) {
        console.warn(`Failed to remove container: ${err.message}`);
      }

      this.containerId = null;
      this.emit('status', { phase: 'app_exit' });
    }
  }
}

module.exports = new ContainerBackend();
