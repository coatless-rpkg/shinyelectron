# Security Considerations

When you turn a Shiny app into a desktop app, it gains a lot of power.
On the web, the browser and a server fence in what your app can do. On
someone’s laptop, your app can do anything they can: read their files,
talk to the network, run programs. That power is what makes a desktop
app useful, and it is also why a desktop app needs more security thought
than a web one.

Three places things can go wrong, and the rest of this guide walks
through each in order:

1.  **The Electron window that shows your app.** Without care, it can be
    tricked into running anything. shinyelectron sets safe defaults;
    your job is to leave them alone.
2.  **Your Shiny code.** Whatever your app can read or run, a determined
    user can probably get it to read or run something else. A few habits
    cover most of it.
3.  **How the app reaches your users.** Unsigned downloads, plain-HTTP
    update channels, and passwords baked into the bundle are the classic
    ways a release goes wrong.

Two related topics live in their own guides: [code
signing](https://r-pkg.thecoatlessprofessor.com/shinyelectron/articles/code-signing.md)
and
[auto-updates](https://r-pkg.thecoatlessprofessor.com/shinyelectron/articles/auto-updates.md),
which rely on signed builds to work.

## Two processes, one trust boundary

An Electron app has two process types:

- **Main process.** Node.js with full OS access. Creates windows, drives
  the lifecycle, spawns R, Python, or a container.
- **Renderer process.** Chromium displaying your Shiny UI. Treat it as
  hostile territory.

The rule is unconditional: **the renderer never touches Node.js
directly**. With `nodeIntegration: true`, any script in the renderer,
including one injected through an XSS bug or a transitive HTML widget,
runs arbitrary OS commands. The defense is to give the renderer the
narrowest possible gate to the main process, and to keep that gate
auditable.

![Diagram of the Electron trust boundary. On the left, the renderer
process hosts Chromium with the Shiny UI, treated as an untrusted zone
with nodeIntegration false, contextIsolation true, sandbox true, and
webSecurity true. In the middle, a preload script using contextBridge
exposes only a narrow IPC surface: lifecycle.onStatus, lifecycle.retry,
and lifecycle.quit. On the right, the trusted main process runs Node.js
with full OS access and spawns R via shiny runApp, Python via shiny run,
container backends via docker run, or the Express server for
Shinylive.](../reference/figures/security-trust-boundary.svg)

Electron’s trust boundary: the renderer runs untrusted web content, the
preload script exposes a small IPC surface, the main process holds full
OS access.

The full picture lives in the [Electron Security
Checklist](https://www.electronjs.org/docs/latest/tutorial/security).
The rest of this section explains how shinyelectron implements each
item.

## What shinyelectron locks down

The generated `BrowserWindow` ships with the safe choice for every
webPreferences flag that has one. The block below is read live from the
template at `inst/electron/shared/main.js`:

``` js
webPreferences: {
  nodeIntegration: false,
  contextIsolation: true,
  sandbox: true,
  preload: path.join(__dirname, 'preload.js'),
  enableRemoteModule: false,
  webSecurity: true,
  // Isolate each app's session to prevent Service Worker cache
  // cross-contamination between multiple shinyelectron apps
  partition: 'persist:<app_slug>'
}
```

Each setting, in one line:

| Setting              | Value   | What it stops                                                                           |
|----------------------|---------|-----------------------------------------------------------------------------------------|
| `nodeIntegration`    | `false` | Renderer cannot call [`require()`](https://rdrr.io/r/base/library.html) or any Node API |
| `contextIsolation`   | `true`  | Page scripts cannot reach into the preload’s scope                                      |
| `sandbox`            | `true`  | Renderer runs inside the Chromium OS sandbox                                            |
| `enableRemoteModule` | `false` | Disables the deprecated `remote` module entirely                                        |
| `webSecurity`        | `true`  | Same-origin policy stays on                                                             |
| `partition`          | per-app | Each shinyelectron app gets its own session storage                                     |

**The preload script is the only bridge.** It exposes a short list of
named IPC methods (`lifecycle.onStatus`, `lifecycle.retry`,
`lifecycle.quit`, and a few peers) through
`contextBridge.exposeInMainWorld()`. The renderer can call those and
nothing else: it never sees `ipcRenderer`, never imports a Node module.

**DevTools default to off.** The DevTools menu item only appears when
`menu.show_dev_tools` is `true` in `_shinyelectron.yml` (the default is
`false`). Leave it that way for production. DevTools lets the user, or
anything injected into the page, execute JavaScript and inspect any
value the app holds.

## Cross-origin headers (Shinylive only)

Shinylive runs WebR or Pyodide in the browser, which needs
`SharedArrayBuffer`, which needs cross-origin isolation. The local
Express server attaches the right headers automatically:

    Cross-Origin-Opener-Policy: same-origin
    Cross-Origin-Embedder-Policy: require-corp
    Cross-Origin-Resource-Policy: cross-origin

Native R and Python apps load over plain `localhost` and need no extra
CSP work: the content originates from a process you started, not a third
party.

**Rule of thumb.** Avoid external scripts (CDNs, third-party widgets)
unless the app genuinely needs them. Each external resource is a trust
dependency you cannot audit. Bundle local copies when you can.

## Where your app still has to think

shinyelectron secures the shell. Inside the shell, your Shiny code runs
with the same OS permissions as the user who launched it. That is the
whole point of a desktop app, and it is also the part you have to defend
yourself.

### Inputs are user-controlled

Every reactive input arrives from the renderer. A determined user can
hand-craft any value, regardless of what the UI suggests. Two rules
cover most of it.

**Validate at the boundary.** Check types, ranges, and shape before you
act on a value, not after. Shiny’s `req()` and `validate(need(...))`
exist for this; use them.

**Never build shell commands by string concatenation.** Pass the program
and its arguments as separate values so the shell never sees a chance to
parse them. The pattern looks slightly different in each language but
the rule is the same.

**R.** [`system()`](https://rdrr.io/r/base/system.html) and
[`system2()`](https://rdrr.io/r/base/system2.html) (when given a single
command string) hand the assembled text to `/bin/sh -c`, where
metacharacters like `;`, `|`, and `$` are interpreted. Use
[`processx::run()`](http://processx.r-lib.org/reference/run.md) instead,
or [`system2()`](https://rdrr.io/r/base/system2.html) with the arguments
as a character vector, so the program and each argument reach the OS as
separate strings:

``` r
# Don't: paste() builds one string that the shell then parses
system(paste("convert", input$file, "out.png"))

# Do: program and args cross to the OS as separate values
processx::run("convert", c(input$file, "out.png"))
```

**Python.** `subprocess.run()` defaults to `shell=False`, which is the
safe form. The list form passes the program and its arguments straight
to the OS process API. Setting `shell=True` (or calling `os.system()`)
routes through `/bin/sh` and re-introduces the parsing problem:

``` python
# Don't: shell=True hands the f-string to /bin/sh -c
subprocess.run(f"convert {input.file} out.png", shell=True)

# Do: list form skips the shell entirely
subprocess.run(["convert", input.file, "out.png"], check=True)
```

In both cases, the difference is whether `; rm -rf ~` (or any other
crafted value the renderer hands you) is treated as data or as a
command.

### File access is user-wide

[`file.choose()`](https://rdrr.io/r/base/file.choose.html),
[`readLines()`](https://rdrr.io/r/base/readLines.html), Python’s
[`open()`](https://rdrr.io/r/base/connections.html): they inherit the
launching user’s permissions and can reach anything that user can reach.
SSH keys, browser history, the Documents folder. Expected for a desktop
app, worth remembering when porting from a sandboxed Shiny Server where
these calls quietly fail.

**Least privilege still applies.** If the app does not need to write
files or spawn processes, do not include code that can. Removed code
cannot be exploited.

### Secrets do not belong in the bundle

Anything you copy into the build is recoverable from the installed app.
`.asar` is not encryption.

    # These should NEVER be in your app directory
    .env
    .Renviron
    credentials.json
    service-account-key.json

Add them to `.gitignore` and check that your build pipeline does not
sweep them in. When the app needs an API key at runtime, the options
are:

- **An environment variable** the user sets on their machine.
- **The OS keychain** via
  [keyring](https://cran.r-project.org/package=keyring): free,
  encrypted, OS-managed.
- **A first-launch prompt** that stores an encrypted credential in the
  app’s user-data directory.

## Strategy-specific notes

The [runtime
strategy](https://r-pkg.thecoatlessprofessor.com/shinyelectron/articles/runtime-strategies.md)
you pick decides which sandbox actually contains your code.

### Shinylive

The strongest isolation of any strategy. WebR or Pyodide run inside the
browser’s WebAssembly sandbox, which has no syscalls of its own and no
filesystem outside an in-memory shim. Shell injection and arbitrary file
access are physically not on the menu. The trust boundary is the same as
any other web page, plus the Electron defaults above.

### System, bundled, auto-download

A real R or Python child process. Whatever is reachable from
[`system()`](https://rdrr.io/r/base/system.html) or `subprocess` is
reachable from the app. The defense is the input-validation discipline
from the previous section. None of these strategies adds additional
sandboxing.

### Container

Docker or Podman puts the app inside an OS-level container, which is a
stronger boundary than process isolation but weaker than a virtual
machine:

- **The app directory is mounted at `/app` inside the container** by the
  container backend, read–write. Anything under `container.volumes` is
  mounted explicitly on top of that.
- **Inbound network reaches the container only on the published port.**
  The container can still make outbound connections by default. Add a
  custom Docker network if you need to block them.
- **Default images run as root inside the container.** shinyelectron’s
  bundled Dockerfiles do not set a `USER` directive, and neither do
  their parent images. For trusted internal apps that is usually fine;
  otherwise override `USER` in a custom Dockerfile.
- **Docker’s daemon runs as root on Linux.** A container escape is a
  host root escape. Podman defaults to rootless mode and is the safer
  choice when available.

Containers buy isolation, not invulnerability. Mount only what you must,
keep the engine patched, and treat the container’s filesystem as a
useful constraint rather than a guarantee.

## Distribution

Two release-time concerns. Each has its own vignette; the rules of thumb
live here.

**Sign your production builds.** Unsigned macOS apps trip Gatekeeper,
unsigned Windows installers trip SmartScreen, and unsigned anything
cannot use `electron-updater`. See [Code Signing and
Distribution](https://r-pkg.thecoatlessprofessor.com/shinyelectron/articles/code-signing.md).

**Serve update manifests over HTTPS.** `electron-updater` verifies the
signature on each downloaded artifact, but the manifest that points it
at the artifact must reach the user untampered. Plain HTTP lets an
attacker swap that manifest. See [Auto
Updates](https://r-pkg.thecoatlessprofessor.com/shinyelectron/articles/auto-updates.md).

## What not to do

shinyelectron’s defaults block every common Electron footgun. You can
re-enable any of them by editing the generated files. Do not.

> **Do not modify these settings in the generated Electron code**
>
> - **`nodeIntegration: true`**: any script in the renderer, including
>   anything an XSS bug injects, gets full Node.js access.
> - **`contextIsolation: false`**: page scripts can then reach into the
>   preload scope, and the boundary is gone.
> - **`sandbox: false`**: the renderer leaves the Chromium OS sandbox.
> - **`webSecurity: false`**: same-origin policy goes off, and arbitrary
>   pages can call arbitrary origins.
> - **Loading remote URLs in the main window.** shinyelectron loads
>   `localhost` (native backends) or local files (lifecycle pages). An
>   external URL runs untrusted code with your app’s Electron
>   privileges.
> - **Shipping with `menu.show_dev_tools: true`.** DevTools lets anyone,
>   or anything, inspect values, run JavaScript, and dig toward the main
>   process.

## Summary

| Layer                | Owned by      | What to do                                                  |
|----------------------|---------------|-------------------------------------------------------------|
| Electron shell       | shinyelectron | Defaults are safe; do not edit them                         |
| Cross-origin headers | shinyelectron | Set automatically for Shinylive                             |
| Shiny app code       | You           | Validate inputs, parameterize commands, avoid shell strings |
| Filesystem use       | You           | Least privilege; the code you remove cannot be exploited    |
| Credentials          | You           | Never bundle; use env vars or the OS keychain               |
| Container image      | You           | Override `USER`, mount minimum, keep engine patched         |
| Code signing         | You           | Sign release builds; HTTPS for update manifests             |

Further reading: the [Electron Security
documentation](https://www.electronjs.org/docs/latest/tutorial/security).
