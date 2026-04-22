# Runtime Strategies

When you export a Shiny app with shinyelectron, the package needs to
decide how the R or Python runtime reaches the end user’s machine. This
decision is controlled by the **runtime strategy**. Choosing the right
strategy depends on your audience, distribution channel, and dependency
complexity.

## Which Strategy Should I Use?

| Scenario                                                   | Recommended Strategy           |
|------------------------------------------------------------|--------------------------------|
| Public distribution, minimal friction                      | `bundled`                      |
| Internal tool for developers who have R/Python             | `system`                       |
| Public distribution, smaller initial download              | `auto-download`                |
| Complex system dependencies or reproducibility needs       | `container`                    |
| App can run entirely in the browser (no native extensions) | `r-shinylive` / `py-shinylive` |
| You want the simplest possible setup                       | `r-shinylive` / `py-shinylive` |

## Comparison Table

|                           | Shinylive              | System                | Bundled                   | Auto-download               | Container                   |
|---------------------------|------------------------|-----------------------|---------------------------|-----------------------------|-----------------------------|
| **App size**              | 50–100 MB              | ~5 MB                 | 150–300 MB                | ~5 MB                       | ~5 MB                       |
| **First launch**          | Fast                   | Fast                  | Fast                      | Slow (downloads runtime)    | Medium (pulls image)        |
| **Offline support**       | Full                   | Full                  | Full                      | First launch needs internet | First launch needs internet |
| **User requirements**     | None                   | R or Python installed | None                      | Internet on first run       | Docker or Podman            |
| **Dependency isolation**  | WebR/Pyodide sandbox   | None                  | Full                      | Full                        | Full                        |
| **Package compatibility** | Limited (WebR/Pyodide) | Complete              | Complete                  | Complete                    | Complete                    |
| **Linux support**         | Yes                    | Yes                   | No (use system/container) | No (use system/container)   | Yes                         |

## Shinylive (r-shinylive / py-shinylive)

Shinylive does not use a runtime strategy. When you choose
`app_type = "r-shinylive"` or `app_type = "py-shinylive"`, the Shiny app
runs entirely in the browser using [WebR](https://docs.r-wasm.org/webr/)
or [Pyodide](https://pyodide.org/). There is no server-side R or Python
process — everything executes client-side inside the Electron window.

Because shinylive types run in the browser, the `runtime_strategy`
parameter is ignored. You do not set it:

``` r
# Shinylive R app -- no runtime_strategy needed
export(
  appdir = "my-app",
  destdir = "output",
  app_type = "r-shinylive"
)

# Shinylive Python app
export(
  appdir = "my-py-app",
  destdir = "output",
  app_type = "py-shinylive"
)
```

### How It Works

1.  [`export()`](https://r-pkg.thecoatlessprofessor.com/shinyelectron/reference/export.md)
    calls the [shinylive](https://posit-dev.github.io/r-shinylive/) R
    package (for R) or the `shinylive` CLI (for Python) to convert your
    app into static assets.
2.  The Electron app serves these assets via a local Express server with
    the required COOP/COEP headers. These are browser security headers
    that enable the shared memory WebR needs to run efficiently.
3.  WebR or Pyodide boots inside the browser and runs your app code.

### Pros

- Zero runtime dependencies for the end user.
- No native process to manage or clean up.
- Works on all platforms (Windows, macOS, Linux).

### Cons

- Large app size due to WebR/Pyodide assets (~50–100 MB for R).
- Not all R packages work in WebR. Packages with compiled C/Fortran code
  need WebR-compatible WASM builds.
- Python packages must be available in Pyodide.
- Slower initial page load as the WASM runtime boots.

### When to Use

Choose shinylive when your app uses packages that are available in
WebR/Pyodide and you want the simplest deployment with no runtime
management.

## System Strategy

The system strategy assumes R or Python is already installed on the end
user’s machine. The Electron app launches Rscript or Python directly
from the system PATH.

``` r
export(
  appdir = "my-app",
  destdir = "output",
  app_type = "r-shiny",
  runtime_strategy = "system"
)
```

### How It Works

1.  [`export()`](https://r-pkg.thecoatlessprofessor.com/shinyelectron/reference/export.md)
    packages the Shiny app files into the Electron project.
2.  At launch, the Electron backend (`native-r.js` or `native-py.js`)
    spawns `Rscript` or `python3` as a child process.
3.  The child process starts the Shiny server, and Electron connects to
    it.

### Pros

- Smallest possible app size (just your app code + Electron shell).
- No download step, no container engine required.
- Full package compatibility — whatever the user has installed works.

### Cons

- User must have R or Python installed and on their PATH.
- Different users may have different package versions, leading to
  inconsistencies.
- No dependency isolation.

### When to Use

Best for internal tools distributed to developers or data scientists who
already have R or Python installed. Also useful during development and
testing.

## Bundled Strategy

The bundled strategy embeds a complete portable R or Python runtime
inside the Electron app at build time. The end user needs nothing beyond
the app itself.

Bundled is like shipping a laptop with the OS pre-installed — larger
package, but the user opens it and everything works. Auto-download
(covered below) is like including a setup script that fetches the OS on
first boot — smaller download, but needs internet once.

``` r
export(
  appdir = "my-app",
  destdir = "output",
  app_type = "r-shiny",
  runtime_strategy = "bundled"
)
```

### How It Works

1.  During
    [`export()`](https://r-pkg.thecoatlessprofessor.com/shinyelectron/reference/export.md),
    shinyelectron downloads a portable runtime and embeds it in the
    Electron project’s `resources/` directory.
2.  App dependencies are installed into the bundled runtime’s library.
3.  At launch, the Electron backend uses the bundled Rscript/Python
    instead of the system one.

### Platform-Specific Runtimes

Portable R builds come from the
[portable-r](https://github.com/portable-r) project:

- **Windows**: `portable-r-windows` releases (x64 and aarch64)
- **macOS**: `portable-r-macos` releases (arm64 and x86_64)
- **Linux**: No portable R builds exist for Linux. The bundled and
  auto-download strategies for R apps require macOS or Windows. Use
  `system` or `container` on Linux.

Portable Python builds come from
[python-build-standalone](https://github.com/astral-sh/python-build-standalone)
by Astral, available for all three platforms (Windows, macOS, and
Linux). Python apps can use any strategy on any platform.

### Pros

- Zero dependencies for the end user.
- Works offline immediately — no first-launch download.
- Complete package compatibility (native R/Python, not WASM).
- Fully isolated from the user’s system R/Python.

### Cons

- Large app size (150–300 MB depending on runtime + packages).
- Portable R not available for Linux.
- Build time is longer due to runtime download and dependency
  installation.

### When to Use

Best for public-facing applications where you cannot assume the user has
R or Python. Ideal when offline support is required from the first
launch.

## Auto-download Strategy

Auto-download is the default strategy for native app types. The app
ships without a runtime, downloads it on first launch, and caches it
locally for subsequent runs.

``` r
# auto-download is the default for native types, so these are equivalent:
export(
  appdir = "my-app",
  destdir = "output",
  app_type = "r-shiny"
)

export(
  appdir = "my-app",
  destdir = "output",
  app_type = "r-shiny",
  runtime_strategy = "auto-download"
)
```

### How It Works

1.  [`export()`](https://r-pkg.thecoatlessprofessor.com/shinyelectron/reference/export.md)
    packages the app without a runtime, but includes the
    `runtime-downloader.js` backend module.
2.  On first launch, the downloader checks a local cache directory. If
    no runtime is found, it downloads and extracts a portable R or
    Python build.
3.  The runtime is cached in a platform-appropriate location (e.g.,
    `~/.shinyelectron/cache/` on macOS/Linux,
    `%LOCALAPPDATA%\shinyelectron\cache\` on Windows).
4.  Subsequent launches skip the download and use the cached runtime.

The download sources are the same as the bundled strategy: portable-r
for R and python-build-standalone for Python.

### Pros

- Small initial app size (just app code + Electron shell).
- Full package compatibility after runtime is downloaded.
- Runtime is shared across multiple shinyelectron apps on the same
  machine.

### Cons

- First launch requires an internet connection and is slower (runtime
  download).
- Users see a download progress screen on first run.
- Same Linux limitation as bundled: portable R is not available for
  Linux.

### When to Use

Good middle ground when you want a smaller download but cannot assume
the user has R/Python. Works well for apps distributed via GitHub
releases or a website where download size matters.

## Container Strategy

The container strategy runs your Shiny app inside a Docker or Podman
container. The Electron shell communicates with the containerized app
over a local port.

``` r
export(
  appdir = "my-app",
  destdir = "output",
  app_type = "r-shiny",
  runtime_strategy = "container"
)
```

You can also configure the container engine and image in
`_shinyelectron.yml`:

``` yaml
build:
  type: "r-shiny"
  runtime_strategy: "container"

container:
  engine: "docker"       # or "podman"
  image: "my-org/my-app"
  tag: "latest"
  pull_on_start: true
```

### How It Works

1.  [`export()`](https://r-pkg.thecoatlessprofessor.com/shinyelectron/reference/export.md)
    packages the app and includes the `container.js` backend module.
2.  At launch, Electron detects Docker or Podman on the system.
3.  It pulls the specified image (if `pull_on_start` is true) and starts
    a container with the app directory mounted.
4.  The Shiny server runs inside the container and Electron connects to
    it via the exposed port.
5.  When the Electron window closes, the container is stopped and
    removed.

### Pros

- Complete environment isolation (OS-level, not just packages).
- Works on all platforms where Docker/Podman runs.
- Handles complex system dependencies (C libraries, system tools) that
  are hard to bundle portably.
- Reproducible across machines.

### Cons

- User must have Docker or Podman installed and running.
- First launch may be slow (image pull).
- Container images can be large.
- Docker Desktop requires a license for commercial use in larger
  organizations.

### When to Use

Best for apps with complex system dependencies (e.g., geospatial
libraries, database drivers) or when you need exact environment
reproducibility. Also useful when your team already uses containers.

## Setting the Strategy via Configuration

Instead of passing `runtime_strategy` to
[`export()`](https://r-pkg.thecoatlessprofessor.com/shinyelectron/reference/export.md),
you can set it in `_shinyelectron.yml`:

``` yaml
build:
  type: "r-shiny"
  runtime_strategy: "auto-download"
```

Function parameters always take precedence over the config file. If you
pass `runtime_strategy = "bundled"` to
[`export()`](https://r-pkg.thecoatlessprofessor.com/shinyelectron/reference/export.md)
but the config says `auto-download`, the bundled strategy is used.

## Platform Considerations

### Linux

Portable R builds are not available for Linux. If you are targeting
Linux users, use the `system` or `container` strategy for R apps. Python
apps can use any strategy on Linux since python-build-standalone
provides Linux builds.

### macOS Code Signing

Bundled and auto-download strategies that embed or download a runtime
may require re-signing the runtime binaries for macOS notarization. Pass
`sign = TRUE` to
[`export()`](https://r-pkg.thecoatlessprofessor.com/shinyelectron/reference/export.md)
and configure your signing credentials.

### Windows

The portable-r-windows builds are self-contained and do not require the
user to install R. They include Rtools where needed. Python builds from
python-build-standalone are similarly self-contained.

### Cross-Platform Builds

You can only build bundled apps for the platform you are currently on,
because the runtime must match the target. To build for Windows and
macOS, you need to run the export on each platform (or use CI — see the
[GitHub
Actions](https://r-pkg.thecoatlessprofessor.com/shinyelectron/articles/github-actions.md)
article).

## Next Steps

- **[Container
  Strategy](https://r-pkg.thecoatlessprofessor.com/shinyelectron/articles/container-strategy.md)**:
  Deep dive into Docker/Podman setup, custom Dockerfiles, and platform
  considerations
- **[Code Signing and
  Distribution](https://r-pkg.thecoatlessprofessor.com/shinyelectron/articles/code-signing.md)**:
  Sign your builds for macOS notarization and Windows SmartScreen trust
- **[Security
  Considerations](https://r-pkg.thecoatlessprofessor.com/shinyelectron/articles/security.md)**:
  Electron security model, secure defaults, and what to avoid
