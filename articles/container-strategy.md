# Container Strategy

A container holds your app, its runtime, and every system library it
needs. Electron is the window onto that container. The user installs
Docker or Podman; you ship an image.

![Diagram showing the runtime layout of a shinyelectron container app on
the user's machine. A dashed outer frame labeled USER'S MACHINE encloses
three components. On the left, an Electron app card with traffic-light
window controls and a viewport that says WebView pointing to
http://localhost:3838. Below it, an App files on disk card showing a
folder icon, the path path/to/my-app/, and a list of files (app.R,
server.R, ui.R, dependencies.json). On the right, a sky-blue Container
Engine card labeled Docker or Podman wraps a Container Instance card
containing two layers: an Image layer with a purple stripe describing OS
base plus R or Python plus Shiny sourced from rocker/r2u,
python:3.12-slim, your Dockerfile, or a registry; and a /app bind mount
layer with an amber stripe describing your app code mounted from disk,
with edits visible inside the container live, and noting that extra
volumes such as /data and /models attach the same way. Two arrows
connect the host components to the container: an HTTP arrow labeled
localhost:3838 from the Electron card to the Image layer, and a bind
mount arrow from the App files card to the /app
layer.](../reference/figures/container-anatomy.svg)

Anatomy of a containerized shinyelectron app on the user’s machine.
Electron talks to a Shiny server inside a container over
`http://localhost:3838`, and your app code on disk is bind-mounted into
the container at `/app` so the running container reads your files live.

## When to reach for a container

Pick the container strategy when any of these are true:

- Your app leans on **heavy system libraries** (GDAL, PROJ, database
  drivers, C toolchains) that are painful to bundle portably.
- **Reproducibility** is the point. The image pins every layer, OS up.
- Your team **already builds with Docker** and you want the desktop and
  server to share an environment.
- You are shipping to a **known audience** (internal users, a lab, a
  team) who can install a container engine.

For apps with only R or Python packages and no system extras, use
`auto-download` or `bundled`. Those ask nothing of the user.

## Prerequisites

The end user needs one of:

- **Docker Desktop**: <https://docs.docker.com/get-docker/>
- **[Colima](https://github.com/abiosoft/colima)** (macOS, free Docker
  drop-in without the Desktop subscription)
- **Podman**: <https://podman.io/getting-started/installation>

The engine has to be running when Electron launches. shinyelectron picks
whichever it finds, checking Docker first, then Podman.

On the build machine a container engine is optional. If present,
shinyelectron confirms the daemon is reachable. If absent, it warns and
keeps going: the image is built or pulled on the user’s machine at first
launch.

## The launch flow

When a user opens the packaged app, shinyelectron walks four phases:

![Horizontal flow diagram with four phase cards connected by arrows
under the title What happens when the user opens the app. Phase 1,
Engine, blue, covers steps 1 to 3 to find and pick: Electron splash
starts, locate the engine socket, pick Docker or Podman. Phase 2, Image,
purple, covers step 4 to make available: pull from registry, or build
the embedded Dockerfile locally; cached after first launch. Phase 3,
Run, green, covers steps 5 to 7 to start and connect: docker run -d,
poll Shiny for up to 120 seconds, WebView loads the URL. Phase 4, Quit,
amber, covers step 8 cleanup: stop the container, remove it; the image
stays cached for the next
launch.](../reference/figures/container-launch-flow.svg)

Four phases of launching a containerized shinyelectron app. Each phase
groups one or more of the eight low-level steps and is colored
consistently with later sections of this guide.

The eight underlying steps:

1.  **Electron starts** and shows the lifecycle splash.
2.  The `container.js` backend **locates the socket**:
    `docker context inspect` first, then well-known Unix sockets
    (`/var/run/docker.sock`, `~/.docker/run/docker.sock`,
    `~/.colima/docker.sock`) or Windows named pipes.
3.  It **selects an engine** (Docker or Podman) based on what is
    available.
4.  If the image is missing, it is **built from an embedded Dockerfile**
    or **pulled from a registry**.
5.  `docker run -d` starts the container. The host port is mapped
    through; the app directory is bind-mounted to `/app` so the
    container reads your files live.
6.  The backend **polls** the Shiny server for up to 120 seconds.
7.  Electron loads `http://localhost:<port>`.
8.  On quit, the container is stopped and removed.

## Configuration

Set `runtime_strategy: container` in `_shinyelectron.yml`:

``` yaml
app:
  name: "My Containerized App"
  version: "1.0.0"

build:
  type: "r-shiny"
  runtime_strategy: "container"

container:
  engine: "docker"         # "docker" or "podman"
  image: null              # null = use embedded Dockerfile
  tag: "latest"
  pull_on_start: true
  volumes: {}              # extra host:container volume mounts
  env: {}                  # extra environment variables

server:
  port: 3838
```

`image: null` (the default) embeds a Dockerfile in the package and
builds locally on first launch. Set `image` to a registry reference like
`ghcr.io/myorg/myapp` to pull instead.

## Where the image comes from

There are three paths. The first two are generated automatically; the
third is for when you need more than the built-ins offer.

![Three-card horizontal layout under the title Where the image comes
from. Card one, blue, Built-in R, generated when type is r-shiny,
configured with type r-shiny and image null, uses rocker/r2u:24.04 as
base, and installs dependencies as r-cran-\* apt packages baked into the
image at build. Card two, green, Built-in Python, generated when type is
py-shiny, configured with type py-shiny and image null, uses
python:3.12-slim as base, and pip-installs dependencies at first launch
via the entrypoint script. Card three, amber, Registry pull, any image
you publish, configured with image set to a reference like
ghcr.io/org/app and a tag, base is whatever you built, dependencies are
already inside the image, and shinyelectron does no Dockerfile
generation.](../reference/figures/container-image-sources.svg)

Three ways an image is sourced for a containerized shinyelectron app.
Each card shows the configuration, the base image, and when extra
dependencies install.

### Built-in R image

The built-in R Dockerfile is based on
[`rocker/r2u:24.04`](https://github.com/rocker-org/r2u), which serves
pre-compiled R packages via apt. It supports amd64 and arm64.

``` r
export(
  appdir = "path/to/my-r-app",
  destdir = "path/to/output",
  app_name = "My R App",
  app_type = "r-shiny",
  runtime_strategy = "container"
)
```

The exact Dockerfile that ships with the package, read live from
`inst/dockerfiles/r-shiny/Dockerfile`:

``` dockerfile
# Minimal R + Shiny image for shinyelectron container strategy
# Uses rocker/r2u which provides pre-built binary R packages via apt
# Supports both amd64 and arm64 (Apple Silicon)
FROM rocker/r2u:24.04

# Install R packages as system packages — pre-compiled, no source compilation
# This works on both amd64 and arm64
RUN apt-get update && apt-get install -y --no-install-recommends \
    r-cran-shiny \
    r-cran-jsonlite \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /app

COPY entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh

EXPOSE 3838

ENTRYPOINT ["/entrypoint.sh"]
```

The image’s `ENTRYPOINT` is the bundled `entrypoint.sh`. It honors
`PORT` and `HOST` env vars (defaulting to `3838` / `0.0.0.0`) and
launches the app with the apt-installed R libraries on
[`.libPaths()`](https://rdrr.io/r/base/libPaths.html). R package
dependencies are baked into the image at build time as `r-cran-*` apt
packages, not installed by the entrypoint.

``` bash
#!/bin/bash
set -e

PORT=${PORT:-3838}
HOST=${HOST:-0.0.0.0}

echo "Starting Shiny app on $HOST:$PORT..."
exec Rscript --vanilla -e ".libPaths(c('/usr/local/lib/R/site-library', '/usr/lib/R/site-library', '/usr/lib/R/library')); shiny::runApp('/app', port = ${PORT}, host = '${HOST}', launch.browser = FALSE)"
```

### Built-in Python image

The built-in Python Dockerfile uses `python:3.12-slim` with `shiny`
pre-installed via pip.

``` r
export(
  appdir = "path/to/my-py-app",
  destdir = "path/to/output",
  app_name = "My Python App",
  app_type = "py-shiny",
  runtime_strategy = "container"
)
```

Read live from `inst/dockerfiles/py-shiny/Dockerfile`:

``` dockerfile
# Minimal Python + Shiny image for shinyelectron container strategy
FROM python:3.12-slim

RUN pip install --no-cache-dir shiny

WORKDIR /app

COPY entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh

EXPOSE 3838

ENTRYPOINT ["/entrypoint.sh"]
```

The `ENTRYPOINT` is `entrypoint.sh`. Unlike the R image, it installs
Python packages listed in `/app/dependencies.json` at startup using
`pip --only-binary :all:`, then launches the Shiny server:

``` bash
#!/bin/bash
set -e

PORT=${PORT:-3838}
HOST=${HOST:-0.0.0.0}

# Install dependencies from manifest if present
if [ -f /app/dependencies.json ]; then
  echo "Installing Python package dependencies..."
  python3 -c "
import json
with open('/app/dependencies.json') as f:
    deps = json.load(f)
if deps.get('packages'):
    import subprocess
    pkgs = deps['packages']
    index = deps.get('index_urls', ['https://pypi.org/simple'])[0]
    subprocess.run(['pip', 'install', '--only-binary', ':all:', '-i', index] + pkgs, check=True)
"
fi

echo "Starting Shiny app on $HOST:$PORT..."
exec python3 -m shiny run --port "$PORT" --host "$HOST" --app-dir /app --no-dev-mode app:app
```

### Registry image

For dependencies that go beyond what the built-ins offer (heavy system
libraries like GDAL or PROJ, custom Python ML stacks, database drivers),
build your own image, publish it to a registry, and point shinyelectron
at the reference:

``` yaml
container:
  image: "ghcr.io/myorg/myapp"
  tag: "v1.2.0"
  pull_on_start: true
```

Any OCI registry works: GHCR, Docker Hub, ECR, or an internal registry
the user’s machine can reach. shinyelectron skips Dockerfile generation
entirely and just pulls + runs.

Your published image has three obligations:

1.  **Listen on the `PORT` env variable** (default 3838).
2.  **Use `/app` as the working directory.** That is where the app is
    bind-mounted.
3.  **Honor `PORT` and `HOST`** for the server bind address.

A reference R image with spatial libraries:

``` dockerfile
FROM rocker/r2u:24.04
RUN apt-get update && apt-get install -y --no-install-recommends \
    r-cran-shiny r-cran-sf r-cran-terra libgdal-dev libproj-dev \
    && rm -rf /var/lib/apt/lists/*
WORKDIR /app
EXPOSE 3838
CMD ["Rscript", "--vanilla", "-e", \
     "shiny::runApp('/app', port=as.integer(Sys.getenv('PORT',3838)), host=Sys.getenv('HOST','0.0.0.0'), launch.browser=FALSE)"]
```

A reference Python image with ML dependencies:

``` dockerfile
FROM python:3.12-slim
RUN pip install --no-cache-dir shiny pandas scikit-learn
WORKDIR /app
EXPOSE 3838
CMD ["python3", "-m", "shiny", "run", "--port", "3838", \
     "--host", "0.0.0.0", "--app-dir", "/app", "--no-dev-mode"]
```

Build, push to your registry, and reference it from
`_shinyelectron.yml`. The user’s machine pulls on first launch and
caches afterward.

## Passing volumes and env vars

Extra mounts and variables from the config are forwarded as `-v` and
`-e` flags to `docker run`.

``` yaml
container:
  engine: "docker"
  volumes:
    "/path/to/data": "/data"
    "/path/to/models": "/models"
  env:
    SHINY_LOG_LEVEL: "debug"
    DATABASE_URL: "postgresql://localhost:5432/mydb"
```

## Verifying the engine

Check what shinyelectron sees on this machine:

``` r
sitrep_electron_system()
```

The report names the container engine it would use (Docker or Podman),
where the socket lives, and whether the daemon is reachable. Run it
before a release build to catch a missing or stopped engine cheaply.

## Limitations

For the security side (volumes, root, escapes), see [Security
Considerations](https://r-pkg.thecoatlessprofessor.com/shinyelectron/articles/security.html#container-strategy-security).

**Your users need a container engine.** That puts containers out of
reach for the casual download-and-launch crowd. For a broader audience,
reach for `bundled` or `auto-download`. Those ask nothing of the host.

**First launch is slow.** Pulling or building a fresh image takes a
minute or two. Every launch after that is seconds, since the image is
cached.

**Docker inside another VM is touchy.** Docker Desktop running under
Parallels or VMware on macOS sometimes refuses to cooperate, and rarely
says why. Native Podman on the host is the usual escape hatch.

**The daemon must be running first.** If Docker Desktop is off, the app
surfaces a lifecycle error asking the user to start it. shinyelectron
cannot start the daemon on their behalf.

## Platform notes

**Docker Desktop is paid at scale.** Larger organizations need a
subscription. [Podman](https://podman.io/) is a free, daemonless
drop-in: set `engine: "podman"` in your config, or let auto-detection
sort it out.

**Architecture matching.** shinyelectron pulls or builds for the host’s
CPU: `linux/arm64` on Apple Silicon, `linux/amd64` elsewhere. That keeps
Apple Silicon off the Rosetta emulation path and the performance tax it
carries.

**Colima on macOS.** [Colima](https://github.com/abiosoft/colima) is a
Docker drop-in, not a third engine: same `docker` CLI, daemon hosted in
a Lima VM rather than Docker Desktop. Keep `engine: "docker"` in your
config; shinyelectron finds the socket at `~/.colima/docker.sock`
automatically.
