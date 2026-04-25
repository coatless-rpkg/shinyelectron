# Troubleshooting Guide

shinyelectron problems break down into three phases: install, build, and
runtime. The `sitrep_*` (situation report) functions check the
environment first, so you can narrow the search before reading error
messages. This guide covers the diagnostics, then walks through the
common failures in each phase.

![Three columns side by side, labelled INSTALL, BUILD, and RUNTIME. The
INSTALL column has an amber stripe and the heading Before any build,
with the diagnostic functions sitrep_electron_system,
sitrep_electron_dependencies, and sitrep_electron_build_tools, plus four
error pills: Node.js not found, R package missing, Build tools missing,
and Python or shinylive CLI. The BUILD column has a blue stripe and the
heading During export(), with the diagnostic function
sitrep_electron_project (checks package.json, main.js, node_modules,
build scripts) and four error pills: package.json or node_modules,
Container pull failure, tar or EBUSY (Windows), and Slow npm install.
The RUNTIME column has a green stripe and the heading After packaging,
when the app launches, noting that there is no sitrep at this stage and
the only diagnostic is launching the app with SHINYELECTRON_DEBUG=1 to
read its own log output, plus four error pills: Gatekeeper (macOS),
SmartScreen (Windows), R not on PATH (Windows), and App crashes on
launch. A caption at the bottom reads: Run the matching sitrep first. If
every check is green, scroll to the phase that contains your
error.](../reference/figures/troubleshooting-phases.svg)

Three-phase troubleshooting map. Each phase lists the matching sitrep
functions and the common errors users hit there.

## Start with a full report

When you hit a problem, run the full diagnostic first.

``` r
sitrep_shinyelectron()
```

    -- Complete shinyelectron Diagnostic Report ----------------------------------
    -------------------------------------------------------------------------------

    -- System Requirements Report -----------------------------------------------
    v Platform: darwin
    v Architecture: arm64
    v Local Node.js (shinyelectron): v22.11.0
    v Active Node.js: v22.11.0 (local)
    v npm: v10.9.0
    v R: v4.4.2

    -- Python
    v Python 3.12.4
    v Python shinylive: 0.7.0 (ready)
    v Python shiny: 1.2.1 (ready)

    -- Container Engine
    v Container engine: docker

    -- Cached Runtimes
    i No cached runtimes found

    v All system requirements satisfied
    -------------------------------------------------------------------------------

    -- Dependencies Report ------------------------------------------------------
    -- Required Packages
    v cli: v3.6.5
    v fs: v1.6.6
    v jsonlite: v2.0.0
    v processx: v3.8.6
    v whisker: v0.4.1
    v utils: v4.4.2
    v tools: v4.4.2
    v All required dependencies satisfied
    -------------------------------------------------------------------------------

    -- Build Tools Report -------------------------------------------------------
    i Checking build tools for platform: darwin
    v Xcode Command Line Tools: Found
    v Build tools ready
    -------------------------------------------------------------------------------

    -- Overall Summary ----------------------------------------------------------
    v All systems ready! You should be able to build Electron apps successfully

This runs every check and ranks any issues by priority. A red `x` is a
hard failure; a yellow `!` is a warning the build will probably get
past.

## Targeted diagnostics

Once you know which subsystem is unhappy, run its check directly.

| Function                                                                                                                           | What it checks                                                                                                          |
|------------------------------------------------------------------------------------------------------------------------------------|-------------------------------------------------------------------------------------------------------------------------|
| [`sitrep_electron_system()`](https://r-pkg.thecoatlessprofessor.com/shinyelectron/reference/sitrep_electron_system.md)             | Node.js, npm, platform, R, Python (plus the `shinylive` and `shiny` Python packages), container engine, cached runtimes |
| [`sitrep_electron_dependencies()`](https://r-pkg.thecoatlessprofessor.com/shinyelectron/reference/sitrep_electron_dependencies.md) | Required and optional R packages                                                                                        |
| [`sitrep_electron_build_tools()`](https://r-pkg.thecoatlessprofessor.com/shinyelectron/reference/sitrep_electron_build_tools.md)   | Platform-specific build tools                                                                                           |
| [`sitrep_electron_project()`](https://r-pkg.thecoatlessprofessor.com/shinyelectron/reference/sitrep_electron_project.md)           | Electron project structure                                                                                              |

> **Local versus system Node.js**
>
> shinyelectron prefers its own Node.js install whenever one exists. See
> [Node.js
> Management](https://r-pkg.thecoatlessprofessor.com/shinyelectron/articles/nodejs-management.md)
> for the full resolution order.

## Reading sitrep results in code

Every `sitrep_*` function returns its results invisibly. Capture them
when you want to automate checks (CI, custom dashboards, pre-flight
scripts):

``` r
results <- sitrep_shinyelectron(verbose = FALSE)

# Surface system issues
if (length(results$system$issues) > 0) {
  cat("System issues found:\n")
  print(results$system$issues)
}

# Inspect Node.js status
if (results$system$node$installed) {
  cat("Node.js version:", results$system$node$version, "\n")
}
```

The structure mirrors what gets printed: each `sitrep_*` family returns
a list with `installed`, `version`, `issues`, and `recommendations`
slots where they apply.

## Install-time problems

These break before you run a build: missing runtimes, missing R
packages, missing compilers.

### Node.js not found

    x Node.js: Not found

Pick one:

1.  Install locally with shinyelectron (recommended).

    ``` r
    install_nodejs()
    ```

2.  Install from <https://nodejs.org/>.

3.  Enable auto-install in `_shinyelectron.yml`.

    ``` yaml
    nodejs:
      auto_install: true
    ```

### Node.js version too old

    ! Node.js: v18.20.0 (version 22+ required)

shinyelectron requires Node.js 22.0.0 or newer because Electron 41
requires it. Older LTS lines (18.x, 20.x) miss features the bundled
Electron version needs.

Install a newer local copy:

``` r
# Latest LTS (currently 22.x)
install_nodejs()

# Or pin a specific version
install_nodejs(version = "22.11.0")
```

### npm not found

    x npm: Not found

npm ships with Node.js. If Node is installed but npm is gone, the
install is broken; reinstall it.

``` r
install_nodejs(force = TRUE)
```

### Missing R packages

    x shinylive: Not installed

Install whichever package is missing:

``` r
install.packages("shinylive")
```

Multiple at once:

``` r
install.packages(c("shinylive", "cli", "fs"))
```

### Xcode Command Line Tools missing (macOS)

    ! Xcode Command Line Tools: Not found

In Terminal:

``` bash
xcode-select --install
```

### Visual Studio Build Tools missing (Windows)

    ! Visual Studio Build Tools: Not found

1.  Download from <https://visualstudio.microsoft.com/downloads/>.
2.  Install the “Desktop development with C++” workload.
3.  Restart your R session so the new tools are picked up.

### Build tools missing (Linux)

    ! Build tools: Incomplete

Ubuntu and Debian:

``` bash
sudo apt-get update
sudo apt-get install build-essential
```

Fedora and RHEL:

``` bash
sudo dnf groupinstall "Development Tools"
```

### Python not found

    i Python: not found (needed for py-shiny apps)

1.  Install Python 3.9 or newer from
    <https://www.python.org/downloads/>.

2.  On **Windows**, tick “Add python.exe to PATH” during install. If you
    skipped that step, add the install directory manually. It usually
    lives at `C:\Users\<you>\AppData\Local\Programs\Python\Python3XX\`.

3.  On **macOS**, the `python3` that ships with Xcode Command Line Tools
    usually works. If it does not, install via Homebrew:
    `brew install python`.

4.  Verify it is reachable from R:

    ``` r
    Sys.which("python3")
    # On Windows, Sys.which("python") is also checked
    ```

### Python `shinylive` CLI not working

    x The shinylive Python package CLI is required for the shinylive strategy with Python apps
      ... cannot be directly executed
      ... No module named shinylive.__main__

The `shinylive` package ships a console script, not a `__main__.py`, so
`python -m shinylive` fails. The actual problem is that the console
script is not on `PATH`.

1.  Reinstall to recreate the script.

    ``` bash
    pip install --upgrade --force-reinstall shinylive
    ```

2.  On **Windows**, pip installs scripts in
    `%APPDATA%\Python\Python3XX\Scripts`. Add that directory to `PATH`:

    ``` powershell
    # Find where pip installed the script
    python -c "import sysconfig; print(sysconfig.get_path('scripts'))"

    # Add it to your user PATH
    $scriptsDir = python -c "import sysconfig; print(sysconfig.get_path('scripts'))"
    [Environment]::SetEnvironmentVariable('Path', "$env:Path;$scriptsDir", 'User')
    ```

    Restart your R session.

3.  Verify:

    ``` bash
    shinylive --version
    ```

### Python `shiny` package not installed

    i Python shiny: not usable

``` bash
pip install shiny
```

You need this for `py-shiny` apps under any non-shinylive strategy
(`system`, `bundled`, `auto-download`, `container`). The `shinylive`
strategy uses the `shinylive` Python package instead.

### Docker or Podman not found

    i Docker/Podman: not found (needed for container strategy)

Install one:

- Docker Desktop: <https://docs.docker.com/get-docker/>
- Podman: <https://podman.io/getting-started/installation>

Confirm the engine is running:

``` bash
docker info
# or
podman info
```

> **Docker on Parallels and other nested virtualization**
>
> Docker Desktop needs hardware virtualization. If you run macOS inside
> a Parallels VM (common on Apple Silicon), Docker Desktop will fail
> because Parallels does not expose nested virtualization to the guest.
>
> Workaround: use the `system`, `bundled`, or `auto-download` runtime
> strategy, or run the Docker build on the host.

## Build-time problems

These appear during
[`export()`](https://r-pkg.thecoatlessprofessor.com/shinyelectron/reference/export.md),
`npm install`, or the electron-builder packaging step.

### `package.json` not found

    x package.json: Not found

You pointed the diagnostic at the wrong directory. Point it at the
Electron sub-project:

``` r
sitrep_electron_project("my-export/electron-app")
```

### `node_modules` not found

    i node_modules: Not found (run 'npm install')

Install the project’s dependencies:

``` r
setwd("my-export/electron-app")
system("npm install")
```

Or from a terminal:

``` bash
cd my-export/electron-app
npm install
```

### Container image pull failure

    Error: ... manifest unknown ... or image not found

1.  Check the image name in `_shinyelectron.yml`.

    ``` yaml
    container:
      image: "shinyelectron/r-shiny"
      tag: "latest"
    ```

2.  Pull the image manually to rule out a network or auth problem.

    ``` bash
    docker pull shinyelectron/r-shiny:latest
    ```

3.  For private registries, run `docker login` first.

### Container port conflict

    Error: ... bind: address already in use

Something else is on the port already, often a container you forgot to
stop.

1.  Move to a different port in `_shinyelectron.yml`.

    ``` yaml
    server:
      port: 3839
    ```

2.  Or stop the offending container.

    ``` bash
    docker ps                     # find the running container
    docker stop <container-id>    # stop it
    ```

### GNU `tar` versus `bsdtar` on Windows

A runtime archive fails to extract with:

    Cannot connect to C: resolve failed

Git for Windows puts GNU `tar` on the `PATH`. GNU `tar` reads `C:\...`
as a remote host spec (`host:path`), not a drive letter. The runtime
downloader needs Windows 10’s bundled bsdtar at
`%SystemRoot%\System32\tar.exe`, which understands drive letters.

shinyelectron already handles this: the JavaScript downloader resolves
the full path to `System32\tar.exe`, and the R-side extraction uses R’s
internal tar. If you still hit the error, check what is actually on
`PATH`:

``` bash
where tar
```

The first hit should be `C:\Windows\System32\tar.exe`, not
`C:\Program Files\Git\usr\bin\tar.exe`.

### `EBUSY` file locks when rebuilding (Windows)

    Error: EBUSY: resource busy or locked, unlink '...\electron.exe'

A running Electron process on Windows holds a lock on its own executable
and DLLs, so a rebuild cannot overwrite the locked files.

1.  Close the running Electron app.
2.  If the process lingers, kill `electron.exe` from Task Manager.
3.  Re-run the build.

### Slow builds (Windows)

Symptom: builds crawl, especially the `npm install` step and the final
packaging.

Cause: Windows Defender real-time scanning inspects every file `npm`
writes inside `node_modules`, and there are thousands of small files.

1.  Add a Defender exclusion for the project directory.

    Settings \> Privacy & Security \> Virus & threat protection \>
    Manage settings \> Exclusions \> Add an exclusion \> Folder.

2.  Add an exclusion for the shinyelectron cache directory. Run
    [`cache_dir()`](https://r-pkg.thecoatlessprofessor.com/shinyelectron/reference/cache_dir.md)
    in R to see the exact path on your machine; on Windows it is
    typically under `%LOCALAPPDATA%\shinyelectron\Cache\assets\`.

## Runtime problems

These show up after the app is packaged, when the end user (or you)
launches it.

### R not on `PATH` (Windows)

Symptom: a packaged app using the `system` runtime cannot find `Rscript`
on the user’s machine.

Cause: the default R installer on Windows puts R under
`C:\Program Files` (or `C:\Program Files (x86)` for 32-bit) and does not
add it to `PATH`.

1.  During R installation, tick the option to add R to `PATH`.

2.  After installation, add the R `bin` directory manually, for example:

        C:\Program Files\R\R-4.4.2\bin

3.  For production, use the `bundled` or `auto-download` runtime
    strategy so end users do not need R pre-installed.

### Gatekeeper blocks the app (macOS)

Symptom: users see “app is damaged and can’t be opened” or “app can’t be
opened because Apple cannot check it for malicious software”.

Cause: Gatekeeper blocks unsigned or unnotarized apps.

For **distribution**, sign and notarize. Configure in
`_shinyelectron.yml`:

``` yaml
signing:
  sign: true
  mac:
    identity: "Developer ID Application: Your Name (TEAMID)"
    team_id: "TEAMID"
    notarize: true
```

Set `APPLE_TEAM_ID`, `APPLE_ID`, and `APPLE_APP_SPECIFIC_PASSWORD`
before building.

For **local testing**, right-click the app and choose Open, then
confirm. That bypasses Gatekeeper for that app only. Or strip the
quarantine attribute:

``` bash
xattr -cr /Applications/MyApp.app
```

### SmartScreen blocks the installer (Windows)

Symptom: SmartScreen shows “Windows protected your PC” when the
installer or app is run.

Cause: the executable is unsigned or lacks SmartScreen reputation.

For **distribution**, sign the app with a code signing certificate.

``` yaml
signing:
  sign: true
  win:
    certificate_file: "path/to/cert.pfx"
```

Set `CSC_LINK` and `CSC_KEY_PASSWORD` before building.

For **local testing**, click “More info” then “Run anyway”.

EV certificates receive SmartScreen reputation immediately. Standard
certificates build reputation over time, as more users run the signed
installer.

## Clear the cache

When nothing else explains a problem, clear the cache. shinyelectron
stores downloaded Node.js, runtimes, and npm assets under your user
cache directory; a stale or partial download in there is a common silent
failure.

``` r
# Clear everything
cache_clear("all")

# Or only the relevant subset
cache_clear("nodejs")
cache_clear("npm")
```

Reinstall Node.js after a clear:

``` r
install_nodejs()
```

Run
[`cache_dir()`](https://r-pkg.thecoatlessprofessor.com/shinyelectron/reference/cache_dir.md)
to see the exact path on your machine. See the [Node.js
Management](https://r-pkg.thecoatlessprofessor.com/shinyelectron/articles/nodejs-management.md)
vignette for the full layout.

## Debugging a packaged app

A packaged Electron app is quiet by default; only warnings and errors
print. To watch runtime detection, dependency installation, and server
startup, launch the app with `SHINYELECTRON_DEBUG=1`:

``` bash
# macOS / Linux
SHINYELECTRON_DEBUG=1 /path/to/YourApp.app/Contents/MacOS/YourApp

# Windows (PowerShell)
$env:SHINYELECTRON_DEBUG = "1"; & "C:\Path\To\YourApp.exe"
```

Debug messages are prefixed with `[shinyelectron]` and include which
runtime was found, the spawn command for R or Python, port retries, and
server-ready events. Include this output when you file a bug report.

## Deprecation warnings: shinylive as an app type

Earlier releases treated shinylive as an app type. `app_type` accepted
`r-shinylive` and `py-shinylive` alongside `r-shiny` and `py-shiny`.
That is gone. shinylive is now a runtime strategy.

| Old API                     | New API                                                   |
|-----------------------------|-----------------------------------------------------------|
| `app_type = "r-shinylive"`  | `app_type = "r-shiny"`, `runtime_strategy = "shinylive"`  |
| `app_type = "py-shinylive"` | `app_type = "py-shiny"`, `runtime_strategy = "shinylive"` |
| `app_type = "r-shiny"`      | `app_type = "r-shiny"` (pick any `runtime_strategy`)      |
| `app_type = "py-shiny"`     | `app_type = "py-shiny"` (pick any `runtime_strategy`)     |

`app_type` is now optional. shinyelectron autodetects `r-shiny` or
`py-shiny` from the files in `appdir`, and `runtime_strategy` defaults
to `"shinylive"` when neither the function argument nor the config sets
one.

The legacy values still work, but they emit a deprecation warning. If
you see a warning about `r-shinylive` or `py-shinylive`, rewrite the
call to the new two-axis form. Update `_shinyelectron.yml` the same way:
replace `build.type: "r-shinylive"` with either
`build.runtime_strategy: "shinylive"` (relying on autodetect) or
`build.type: "r-shiny"` plus `build.runtime_strategy: "shinylive"`
(explicit).

## Getting help

If every diagnostic is green but something still breaks:

1.  Read the console output for the exact error message. Enable
    `SHINYELECTRON_DEBUG=1` for verbose backend logs.
2.  Confirm your Shiny app runs locally with `shiny::runApp()` (R) or
    `shiny run` (Python).
3.  Check file permissions on your project directory.
4.  Open an issue at
    <https://github.com/coatless-rpkg/shinyelectron/issues>.

When you file an issue, include the output of:

``` r
sitrep_shinyelectron()
```

## Next steps

- **[Getting
  Started](https://r-pkg.thecoatlessprofessor.com/shinyelectron/articles/getting-started.md)**:
  first-time walkthrough.
- **[Configuration](https://r-pkg.thecoatlessprofessor.com/shinyelectron/articles/configuration.md)**:
  customise your builds.
- **[Node.js
  Management](https://r-pkg.thecoatlessprofessor.com/shinyelectron/articles/nodejs-management.md)**:
  manage Node.js installs and the cache.
