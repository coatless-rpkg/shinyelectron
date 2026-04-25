# Building with GitHub Actions

A desktop installer has to be built on the OS it targets: a `.dmg` on
macOS, an `.exe` on Windows, an `.AppImage` on Linux, and once again per
architecture. That is six builds for full coverage, and most teams do
not have all six machines on a desk. GitHub Actions rents them by the
minute, runs them in parallel, and hands back the installers as
artifacts. One push, six builds, no hardware juggling.

![A git push node on the left fans out to six runner rows (macos-latest,
macos-15-intel, windows-latest, windows-11-arm, ubuntu-latest,
ubuntu-24.04-arm), each producing a platform-specific installer, which
fan back in to a Release job on the right that runs only on tag
pushes.](../reference/figures/ci-build-matrix.svg)

The build matrix: one push fans out across platform runners, each
producing an installer; a tag push adds a release job that attaches them
all.

## Why automate

Doing this by hand is slow and hard to reproduce. CI fixes four specific
things at once:

| Problem                                      | What CI gives you                                           |
|----------------------------------------------|-------------------------------------------------------------|
| You need macOS, Windows, and Linux hardware  | Hosted runners for each                                     |
| Local builds drift with your laptop’s state  | Fresh, versioned environments every run                     |
| Uploading binaries to a Release page by hand | Artifacts and releases produced by a workflow step          |
| Platform-specific regressions slip through   | The matrix runs in parallel and surfaces them on every push |

## Before you start

You need:

1.  A GitHub repo containing your Shiny app.
2.  The app in a subdirectory, `app/` by default.
3.  Optionally, a `_shinyelectron.yml` alongside the app.

A typical layout:

    my-shiny-project/
    ├── .github/
    │   └── workflows/
    │       └── build-electron.yml
    ├── app/
    │   ├── app.R
    │   └── ...
    ├── _shinyelectron.yml
    └── README.md

## Use the bundled workflow

shinyelectron ships a ready-to-run workflow at
`inst/templates/github-actions-build.yml`. Copy it into your repo:

``` r
template <- system.file(
  "templates", "github-actions-build.yml",
  package = "shinyelectron"
)

dir.create(".github/workflows", recursive = TRUE, showWarnings = FALSE)
file.copy(
  template,
  ".github/workflows/build-electron.yml"
)
```

Or grab it directly from
[GitHub](https://github.com/coatless-rpkg/shinyelectron/blob/main/inst/templates/github-actions-build.yml).

The workflow runs three jobs in sequence: a build matrix, a release step
gated on tag pushes, and a summary recap.

### Configure the env vars

Edit four variables at the top of the workflow. They are the only fields
most projects need to change:

``` yaml
env:
  # Configure these for your project
  APP_DIR: 'app'           # Directory containing your Shiny app
  APP_NAME: 'MyApp'        # Name of your application
  NODE_VERSION: '22'       # Node.js version
  R_VERSION: 'release'     # R version (release, devel, or specific version)
```

`APP_DIR` is the path to your Shiny app inside the repo. `APP_NAME`
becomes the installer’s display name. `NODE_VERSION` and `R_VERSION` pin
the toolchain; leave them at the defaults unless you have a reason to
deviate.

### What the matrix builds

The matrix spreads installers across six runners. Each runner starts
from a clean image:

| Runner             | Platform | Architecture          | Output      |
|--------------------|----------|-----------------------|-------------|
| `macos-latest`     | macOS    | arm64 (Apple Silicon) | `.dmg`      |
| `macos-15-intel`   | macOS    | x64 (Intel)           | `.dmg`      |
| `windows-latest`   | Windows  | x64                   | `.exe`      |
| `windows-11-arm`   | Windows  | arm64                 | `.exe`      |
| `ubuntu-latest`    | Ubuntu   | x64                   | `.AppImage` |
| `ubuntu-24.04-arm` | Ubuntu   | arm64                 | `.AppImage` |

CPU and RAM allocations come from GitHub’s hosted-runner specs, which
evolve over time; check [the GitHub-hosted runners
documentation](https://docs.github.com/en/actions/using-github-hosted-runners/about-github-hosted-runners)
for current numbers.

Every runner steps through the same recipe:

1.  Checkout the repo.
2.  Set up R with `r-lib/actions/setup-r`.
3.  Set up Node.js (version from `NODE_VERSION`).
4.  Install `shinyelectron` and dependencies.
5.  Run
    [`shinyelectron::export()`](https://r-pkg.thecoatlessprofessor.com/shinyelectron/reference/export.md).
6.  Upload the build output as a run artifact.

A release job runs after the matrix when the trigger is a tag push,
downloading every artifact and attaching them to a fresh GitHub Release.

### Push and tag

Commit and push to fire the workflow on `main` or `master`:

``` bash
git add .github/workflows/build-electron.yml
git commit -m "Add Electron build workflow"
git push
```

Tag a version to cut a release:

``` bash
git tag v1.0.0
git push origin v1.0.0
```

Tags containing `-alpha` or `-beta` are marked as pre-releases
automatically.

### Status badge

Drop a badge in your README so contributors see build state at a glance:

``` markdown
[![Release](https://github.com/YOUR-USERNAME/YOUR-REPO/actions/workflows/build-electron.yml/badge.svg)](https://github.com/YOUR-USERNAME/YOUR-REPO/actions/workflows/build-electron.yml)
```

## Customising

The bundled workflow expects most projects to adjust four things: where
the app lives, which platforms to ship, what icons to use, and whether
to cache R packages aggressively. Each can be edited in place.

### App in a different folder

Override `APP_DIR`:

``` yaml
env:
  APP_DIR: 'src/shiny-app'
```

### Narrower platform list

Trim the matrix to what you ship. Each entry corresponds to one runner;
remove the rest:

``` yaml
strategy:
  matrix:
    include:
      - os: macos-latest
        platform: mac
        arch: arm64
      - os: windows-latest
        platform: win
        arch: x64
```

### Custom icons

Ship icons from the repo and pass them to
[`export()`](https://r-pkg.thecoatlessprofessor.com/shinyelectron/reference/export.md):

``` yaml
- name: Build Electron app
  run: |
    Rscript -e "
      shinyelectron::export(
        appdir = '${{ env.APP_DIR }}',
        destdir = 'build',
        icon = 'assets/icon.icns'
      )
    "
```

> **Note**
>
> Icon requirements: macOS uses `.icns` (build with `iconutil`), Windows
> uses `.ico` (multi-resolution recommended), Linux uses `.png` at
> 512x512.

### Caching R packages

`npm` caching is on by default. R packages are worth caching too:

``` yaml
- name: Setup R
  uses: r-lib/actions/setup-r@v2
  with:
    r-version: ${{ env.R_VERSION }}
    use-public-rspm: true

- name: Cache R packages
  uses: actions/cache@v5
  with:
    path: ${{ env.R_LIBS_USER }}
    key: ${{ runner.os }}-r-${{ hashFiles('**/DESCRIPTION') }}
```

### Config file wins, workflow overrides

A `_shinyelectron.yml` in the app directory is picked up automatically.
Workflow parameters passed to
[`shinyelectron::export()`](https://r-pkg.thecoatlessprofessor.com/shinyelectron/reference/export.md)
override its values when set.

``` yaml
app:
  name: "My Shiny Dashboard"
  version: "1.0.0"

window:
  width: 1400
  height: 900

build:
  type: "r-shiny"
  runtime_strategy: "shinylive"
```

## Signing in CI

Signing keeps the same `electron-builder` environment variables as a
local build, just stored as GitHub Secrets instead. Open Settings,
Secrets and variables, Actions, and add each value by name. Reference
them from the build job’s `env`:

``` yaml
- name: Build Electron app
  env:
    # macOS
    CSC_LINK: ${{ secrets.MAC_CERTIFICATE }}
    CSC_KEY_PASSWORD: ${{ secrets.MAC_CERTIFICATE_PASSWORD }}
    APPLE_ID: ${{ secrets.APPLE_ID }}
    APPLE_APP_SPECIFIC_PASSWORD: ${{ secrets.APPLE_APP_SPECIFIC_PASSWORD }}
    # Windows
    WIN_CSC_LINK: ${{ secrets.WIN_CERTIFICATE }}
    WIN_CSC_KEY_PASSWORD: ${{ secrets.WIN_CERTIFICATE_PASSWORD }}
  run: |
    Rscript -e "
      shinyelectron::export(
        appdir = '${{ env.APP_DIR }}',
        destdir = 'build',
        sign = TRUE
      )
    "
```

> **Warning**
>
> Certificates come from Apple (macOS) and a commercial CA (Windows).
> Unsigned apps trigger Gatekeeper and SmartScreen warnings on end-user
> machines. See [Code Signing and
> Distribution](https://r-pkg.thecoatlessprofessor.com/shinyelectron/articles/code-signing.md)
> for the full setup.

## Coming soon: a composite action

A composite GitHub Action at
[`coatless-actions/shiny-to-electron`](https://github.com/coatless-actions/shiny-to-electron)
is in development. The goal is to wrap the whole build pipeline so a
workflow shrinks to a few lines:

``` yaml
on:
  push:
    tags: ['v*']
jobs:
  build:
    runs-on: ${{ matrix.os }}
    strategy:
      matrix:
        os: [ubuntu-latest, macos-latest, windows-latest]
    steps:
      - uses: actions/checkout@v6
      - uses: coatless-actions/shiny-to-electron@v1
        with:
          appdir: app
```

The action does not have a published release yet, so the bundled
template above is the path to use today. Once the action ships, this
section will become the recommended quickstart.

## CI-specific troubleshooting

The general guide in
[Troubleshooting](https://r-pkg.thecoatlessprofessor.com/shinyelectron/articles/troubleshooting.md)
covers symptoms that show up on any machine. The items below are CI-only
or turn up much more often on hosted runners than on a developer laptop.

### Linux build fails on missing libraries

Hosted Ubuntu runners are minimal. Install whatever system packages your
R or Python dependencies need before the build:

``` yaml
- name: Install system dependencies (Linux)
  if: runner.os == 'Linux'
  run: |
    sudo apt-get update
    sudo apt-get install -y libcurl4-openssl-dev libxml2-dev
```

### `appdir` points at the wrong directory

A workflow that hardcodes `appdir: app` will fail with
`App directory 'app' not found` if your repo puts the Shiny code
somewhere else. Update `APP_DIR` to match the actual path.

### R package install fails on a runner but not locally

Most often the package is not on CRAN and the workflow never told
`setup-r-dependencies` where to find it. Add the repo or the GitHub
source explicitly:

``` yaml
- name: Install R dependencies
  uses: r-lib/actions/setup-r-dependencies@v2
  with:
    extra-packages: |
      any::shinyelectron
      github::user/package
```

### Job hits the six-hour limit

GitHub-hosted runners cap individual jobs at six hours. If a build comes
close, shrink the matrix, cache packages more aggressively, or split the
build into separate workflows that run in parallel.

### Run sitrep on the runner

When a build is failing in CI but works on your laptop, run the
diagnostic on the runner itself to compare environments:

``` yaml
- name: Run diagnostics
  run: |
    Rscript -e "
      library(shinyelectron)
      sitrep_shinyelectron()
    "
```

## Next steps

- [Getting
  Started](https://r-pkg.thecoatlessprofessor.com/shinyelectron/articles/getting-started.md):
  local development workflow.
- [Configuration](https://r-pkg.thecoatlessprofessor.com/shinyelectron/articles/configuration.md):
  customize with `_shinyelectron.yml`.
- [Troubleshooting](https://r-pkg.thecoatlessprofessor.com/shinyelectron/articles/troubleshooting.md):
  diagnose build issues.
