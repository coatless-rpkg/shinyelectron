# Download Prebuilt Demos

Every demo is built with every runtime strategy on each supported
platform and published as a release asset. The only gap is the `bundled`
and `auto-download` strategies for R on Linux, which have no portable
runtime; those cells show `--`.

Each download is a desktop installer: run it to install the app, then
launch the demo. On Linux the download is a portable AppImage you can
run directly, with no install step. What changes between strategies is
what the app needs once it launches:

- `shinylive`: no runtime at all. The app runs in WebAssembly, offline.
- `bundled`: no runtime to install. A copy of R or Python is embedded in
  the app.
- `system`: R or Python already installed and on the PATH.
- `auto-download`: internet access on first launch to download the
  runtime, then cached.
- `container`: Docker or Podman installed.

On macOS these demos are signed with a Developer ID certificate and
notarized by Apple, so they launch without a warning. Windows demos are
unsigned, so the first launch shows a SmartScreen prompt; choose **More
info**, then **Run anyway**. When you build your own apps for
distribution, sign and notarize them so users never see these prompts.
The [Code
Signing](https://r-pkg.thecoatlessprofessor.com/shinyelectron/articles/code-signing.md)
article covers the setup.

Your platform’s downloads are shown first. Use **More downloads** for
every other platform.

## macOS (Apple Silicon)

### Python

#### Standalone (no R or Python needed)

| Demo | `shinylive` | `bundled` |
|----|----|----|
| Python demo suite | [download](https://github.com/coatless-rpkg/shinyelectron/releases/latest/download/demo-py-app-suite-shinylive-mac-arm64.dmg) | [download](https://github.com/coatless-rpkg/shinyelectron/releases/latest/download/demo-py-app-suite-bundled-mac-arm64.dmg) |
| Python single app | [download](https://github.com/coatless-rpkg/shinyelectron/releases/latest/download/demo-py-single-shinylive-mac-arm64.dmg) | [download](https://github.com/coatless-rpkg/shinyelectron/releases/latest/download/demo-py-single-bundled-mac-arm64.dmg) |

#### Needs a runtime or tooling

| Demo | `system` | `auto-download` | `container` |
|----|----|----|----|
| Python demo suite | [download](https://github.com/coatless-rpkg/shinyelectron/releases/latest/download/demo-py-app-suite-system-mac-arm64.dmg) | [download](https://github.com/coatless-rpkg/shinyelectron/releases/latest/download/demo-py-app-suite-auto-download-mac-arm64.dmg) | [download](https://github.com/coatless-rpkg/shinyelectron/releases/latest/download/demo-py-app-suite-container-mac-arm64.dmg) |
| Python single app | [download](https://github.com/coatless-rpkg/shinyelectron/releases/latest/download/demo-py-single-system-mac-arm64.dmg) | [download](https://github.com/coatless-rpkg/shinyelectron/releases/latest/download/demo-py-single-auto-download-mac-arm64.dmg) | [download](https://github.com/coatless-rpkg/shinyelectron/releases/latest/download/demo-py-single-container-mac-arm64.dmg) |

### R

#### Standalone (no R or Python needed)

| Demo | `shinylive` | `bundled` |
|----|----|----|
| R demo suite | [download](https://github.com/coatless-rpkg/shinyelectron/releases/latest/download/demo-r-app-suite-shinylive-mac-arm64.dmg) | [download](https://github.com/coatless-rpkg/shinyelectron/releases/latest/download/demo-r-app-suite-bundled-mac-arm64.dmg) |
| R single app | [download](https://github.com/coatless-rpkg/shinyelectron/releases/latest/download/demo-single-shinylive-mac-arm64.dmg) | [download](https://github.com/coatless-rpkg/shinyelectron/releases/latest/download/demo-single-bundled-mac-arm64.dmg) |

#### Needs a runtime or tooling

| Demo | `system` | `auto-download` | `container` |
|----|----|----|----|
| R demo suite | [download](https://github.com/coatless-rpkg/shinyelectron/releases/latest/download/demo-r-app-suite-system-mac-arm64.dmg) | [download](https://github.com/coatless-rpkg/shinyelectron/releases/latest/download/demo-r-app-suite-auto-download-mac-arm64.dmg) | [download](https://github.com/coatless-rpkg/shinyelectron/releases/latest/download/demo-r-app-suite-container-mac-arm64.dmg) |
| R single app | [download](https://github.com/coatless-rpkg/shinyelectron/releases/latest/download/demo-single-system-mac-arm64.dmg) | [download](https://github.com/coatless-rpkg/shinyelectron/releases/latest/download/demo-single-auto-download-mac-arm64.dmg) | [download](https://github.com/coatless-rpkg/shinyelectron/releases/latest/download/demo-single-container-mac-arm64.dmg) |

## macOS (Intel)

### Python

#### Standalone (no R or Python needed)

| Demo | `shinylive` | `bundled` |
|----|----|----|
| Python demo suite | [download](https://github.com/coatless-rpkg/shinyelectron/releases/latest/download/demo-py-app-suite-shinylive-mac-x64.dmg) | [download](https://github.com/coatless-rpkg/shinyelectron/releases/latest/download/demo-py-app-suite-bundled-mac-x64.dmg) |
| Python single app | [download](https://github.com/coatless-rpkg/shinyelectron/releases/latest/download/demo-py-single-shinylive-mac-x64.dmg) | [download](https://github.com/coatless-rpkg/shinyelectron/releases/latest/download/demo-py-single-bundled-mac-x64.dmg) |

#### Needs a runtime or tooling

| Demo | `system` | `auto-download` | `container` |
|----|----|----|----|
| Python demo suite | [download](https://github.com/coatless-rpkg/shinyelectron/releases/latest/download/demo-py-app-suite-system-mac-x64.dmg) | [download](https://github.com/coatless-rpkg/shinyelectron/releases/latest/download/demo-py-app-suite-auto-download-mac-x64.dmg) | [download](https://github.com/coatless-rpkg/shinyelectron/releases/latest/download/demo-py-app-suite-container-mac-x64.dmg) |
| Python single app | [download](https://github.com/coatless-rpkg/shinyelectron/releases/latest/download/demo-py-single-system-mac-x64.dmg) | [download](https://github.com/coatless-rpkg/shinyelectron/releases/latest/download/demo-py-single-auto-download-mac-x64.dmg) | [download](https://github.com/coatless-rpkg/shinyelectron/releases/latest/download/demo-py-single-container-mac-x64.dmg) |

### R

#### Standalone (no R or Python needed)

| Demo | `shinylive` | `bundled` |
|----|----|----|
| R demo suite | [download](https://github.com/coatless-rpkg/shinyelectron/releases/latest/download/demo-r-app-suite-shinylive-mac-x64.dmg) | [download](https://github.com/coatless-rpkg/shinyelectron/releases/latest/download/demo-r-app-suite-bundled-mac-x64.dmg) |
| R single app | [download](https://github.com/coatless-rpkg/shinyelectron/releases/latest/download/demo-single-shinylive-mac-x64.dmg) | [download](https://github.com/coatless-rpkg/shinyelectron/releases/latest/download/demo-single-bundled-mac-x64.dmg) |

#### Needs a runtime or tooling

| Demo | `system` | `auto-download` | `container` |
|----|----|----|----|
| R demo suite | [download](https://github.com/coatless-rpkg/shinyelectron/releases/latest/download/demo-r-app-suite-system-mac-x64.dmg) | [download](https://github.com/coatless-rpkg/shinyelectron/releases/latest/download/demo-r-app-suite-auto-download-mac-x64.dmg) | [download](https://github.com/coatless-rpkg/shinyelectron/releases/latest/download/demo-r-app-suite-container-mac-x64.dmg) |
| R single app | [download](https://github.com/coatless-rpkg/shinyelectron/releases/latest/download/demo-single-system-mac-x64.dmg) | [download](https://github.com/coatless-rpkg/shinyelectron/releases/latest/download/demo-single-auto-download-mac-x64.dmg) | [download](https://github.com/coatless-rpkg/shinyelectron/releases/latest/download/demo-single-container-mac-x64.dmg) |

## Windows

### Python

#### Standalone (no R or Python needed)

| Demo | `shinylive` | `bundled` |
|----|----|----|
| Python demo suite | [download](https://github.com/coatless-rpkg/shinyelectron/releases/latest/download/demo-py-app-suite-shinylive-win-x64.exe) | [download](https://github.com/coatless-rpkg/shinyelectron/releases/latest/download/demo-py-app-suite-bundled-win-x64.exe) |
| Python single app | [download](https://github.com/coatless-rpkg/shinyelectron/releases/latest/download/demo-py-single-shinylive-win-x64.exe) | [download](https://github.com/coatless-rpkg/shinyelectron/releases/latest/download/demo-py-single-bundled-win-x64.exe) |

#### Needs a runtime or tooling

| Demo | `system` | `auto-download` | `container` |
|----|----|----|----|
| Python demo suite | [download](https://github.com/coatless-rpkg/shinyelectron/releases/latest/download/demo-py-app-suite-system-win-x64.exe) | [download](https://github.com/coatless-rpkg/shinyelectron/releases/latest/download/demo-py-app-suite-auto-download-win-x64.exe) | [download](https://github.com/coatless-rpkg/shinyelectron/releases/latest/download/demo-py-app-suite-container-win-x64.exe) |
| Python single app | [download](https://github.com/coatless-rpkg/shinyelectron/releases/latest/download/demo-py-single-system-win-x64.exe) | [download](https://github.com/coatless-rpkg/shinyelectron/releases/latest/download/demo-py-single-auto-download-win-x64.exe) | [download](https://github.com/coatless-rpkg/shinyelectron/releases/latest/download/demo-py-single-container-win-x64.exe) |

### R

#### Standalone (no R or Python needed)

| Demo | `shinylive` | `bundled` |
|----|----|----|
| R demo suite | [download](https://github.com/coatless-rpkg/shinyelectron/releases/latest/download/demo-r-app-suite-shinylive-win-x64.exe) | [download](https://github.com/coatless-rpkg/shinyelectron/releases/latest/download/demo-r-app-suite-bundled-win-x64.exe) |
| R single app | [download](https://github.com/coatless-rpkg/shinyelectron/releases/latest/download/demo-single-shinylive-win-x64.exe) | [download](https://github.com/coatless-rpkg/shinyelectron/releases/latest/download/demo-single-bundled-win-x64.exe) |

#### Needs a runtime or tooling

| Demo | `system` | `auto-download` | `container` |
|----|----|----|----|
| R demo suite | [download](https://github.com/coatless-rpkg/shinyelectron/releases/latest/download/demo-r-app-suite-system-win-x64.exe) | [download](https://github.com/coatless-rpkg/shinyelectron/releases/latest/download/demo-r-app-suite-auto-download-win-x64.exe) | [download](https://github.com/coatless-rpkg/shinyelectron/releases/latest/download/demo-r-app-suite-container-win-x64.exe) |
| R single app | [download](https://github.com/coatless-rpkg/shinyelectron/releases/latest/download/demo-single-system-win-x64.exe) | [download](https://github.com/coatless-rpkg/shinyelectron/releases/latest/download/demo-single-auto-download-win-x64.exe) | [download](https://github.com/coatless-rpkg/shinyelectron/releases/latest/download/demo-single-container-win-x64.exe) |

## Linux

### Python

#### Standalone (no R or Python needed)

| Demo | `shinylive` | `bundled` |
|----|----|----|
| Python demo suite | [download](https://github.com/coatless-rpkg/shinyelectron/releases/latest/download/demo-py-app-suite-shinylive-linux-x64.AppImage) | [download](https://github.com/coatless-rpkg/shinyelectron/releases/latest/download/demo-py-app-suite-bundled-linux-x64.AppImage) |
| Python single app | [download](https://github.com/coatless-rpkg/shinyelectron/releases/latest/download/demo-py-single-shinylive-linux-x64.AppImage) | [download](https://github.com/coatless-rpkg/shinyelectron/releases/latest/download/demo-py-single-bundled-linux-x64.AppImage) |

#### Needs a runtime or tooling

| Demo | `system` | `auto-download` | `container` |
|----|----|----|----|
| Python demo suite | [download](https://github.com/coatless-rpkg/shinyelectron/releases/latest/download/demo-py-app-suite-system-linux-x64.AppImage) | [download](https://github.com/coatless-rpkg/shinyelectron/releases/latest/download/demo-py-app-suite-auto-download-linux-x64.AppImage) | [download](https://github.com/coatless-rpkg/shinyelectron/releases/latest/download/demo-py-app-suite-container-linux-x64.AppImage) |
| Python single app | [download](https://github.com/coatless-rpkg/shinyelectron/releases/latest/download/demo-py-single-system-linux-x64.AppImage) | [download](https://github.com/coatless-rpkg/shinyelectron/releases/latest/download/demo-py-single-auto-download-linux-x64.AppImage) | [download](https://github.com/coatless-rpkg/shinyelectron/releases/latest/download/demo-py-single-container-linux-x64.AppImage) |

### R

#### Standalone (no R or Python needed)

| Demo | `shinylive` | `bundled` |
|----|----|----|
| R demo suite | [download](https://github.com/coatless-rpkg/shinyelectron/releases/latest/download/demo-r-app-suite-shinylive-linux-x64.AppImage) | – |
| R single app | [download](https://github.com/coatless-rpkg/shinyelectron/releases/latest/download/demo-single-shinylive-linux-x64.AppImage) | – |

#### Needs a runtime or tooling

| Demo | `system` | `auto-download` | `container` |
|----|----|----|----|
| R demo suite | [download](https://github.com/coatless-rpkg/shinyelectron/releases/latest/download/demo-r-app-suite-system-linux-x64.AppImage) | – | [download](https://github.com/coatless-rpkg/shinyelectron/releases/latest/download/demo-r-app-suite-container-linux-x64.AppImage) |
| R single app | [download](https://github.com/coatless-rpkg/shinyelectron/releases/latest/download/demo-single-system-linux-x64.AppImage) | – | [download](https://github.com/coatless-rpkg/shinyelectron/releases/latest/download/demo-single-container-linux-x64.AppImage) |
