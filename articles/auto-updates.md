# Automatic Updates

Automatic updates allow your Electron application to check for,
download, and install new versions seamlessly. This guide explains how
to configure auto-updates using shinyelectron and electron-updater.

## Overview

shinyelectron uses
[electron-updater](https://www.electron.build/auto-update) to provide
automatic updates. electron-updater is the library electron-builder uses
to check for, download, and install updates. Updates can be distributed
via:

| Provider        | Best For               | Requirements               |
|-----------------|------------------------|----------------------------|
| GitHub Releases | Open source projects   | Public/private GitHub repo |
| S3              | Enterprise deployments | AWS S3 bucket              |
| Generic HTTP    | Custom infrastructure  | Any HTTP server            |

## Quick Start

### Enable Auto-Updates

Use
[`enable_auto_updates()`](https://r-pkg.thecoatlessprofessor.com/shinyelectron/reference/enable_auto_updates.md)
to configure your app:

``` r
# Enable GitHub-based updates
enable_auto_updates(
  "path/to/app",
  provider = "github",
  owner = "your-username",
  repo = "your-app-repo"
)
```

This modifies your `_shinyelectron.yml` configuration file.

### Check Status

Verify your configuration:

``` r
check_auto_update_status("path/to/app")
```

## GitHub Releases Setup

GitHub Releases is the recommended approach for open-source projects.

### Step 1: Configure Your App

``` r
enable_auto_updates(
  "path/to/app",
  provider = "github",
  owner = "myorg",
  repo = "my-shiny-dashboard",
  check_on_startup = TRUE,
  auto_download = FALSE   # Prompt user before downloading
)
```

### Step 2: Build Your App

Build your application normally:

``` r
export("path/to/app", destdir = "build")
```

### Step 3: Create a GitHub Release

1.  Navigate to your repository on GitHub
2.  Click “Releases” → “Create a new release”
3.  Create a tag (e.g., `v1.0.0`)
4.  Upload your built application files:
    - `MyApp-1.0.0.dmg` (macOS)
    - `MyApp-Setup-1.0.0.exe` (Windows)
    - `MyApp-1.0.0.AppImage` (Linux)
5.  Publish the release

> **Note**
>
> The file names must match the pattern `{productName}-{version}.{ext}`
> for electron-updater to detect them correctly.

### Step 4: Test Updates

When you publish a new release with a higher version number, the app
will:

1.  Check for updates on startup (if `check_on_startup = TRUE`)
2.  Notify the user that an update is available
3.  Download the update (automatically if `auto_download = TRUE`)
4.  Prompt to restart and install

## Configuration Options

### Full Configuration Reference

In `_shinyelectron.yml`:

``` yaml
updates:
  enabled: true
  provider: "github"
  check_on_startup: true    # Check when app starts
  auto_download: false      # Download without prompting
  auto_install: false       # Install on app quit

  github:
    owner: "your-username"
    repo: "your-repo"
    private: false          # Set true for private repos
```

### Update Behavior Matrix

These three settings control the update pipeline: `check_on_startup`
asks “is there an update?”, `auto_download` fetches it, and
`auto_install` applies it.

| Setting                  | Behavior                                 |
|--------------------------|------------------------------------------|
| `check_on_startup: true` | Checks for updates when app launches     |
| `auto_download: true`    | Downloads updates silently in background |
| `auto_install: true`     | Installs update when user quits app      |

**Recommended for most apps:**

``` yaml
updates:
  check_on_startup: true
  auto_download: false    # Let user decide
  auto_install: false     # Let user decide when to restart
```

**For critical updates:**

``` yaml
updates:
  check_on_startup: true
  auto_download: true     # Download immediately
  auto_install: true      # Install on next quit
```

## Private Repositories

For private GitHub repositories, users need a `GH_TOKEN` environment
variable:

``` yaml
updates:
  github:
    owner: "my-org"
    repo: "private-app"
    private: true
```

Users must set the token before running the app:

``` bash
# macOS/Linux
export GH_TOKEN=ghp_xxxxxxxxxxxx

# Windows
set GH_TOKEN=ghp_xxxxxxxxxxxx
```

## S3 Provider

For enterprise deployments using AWS S3:

``` yaml
updates:
  enabled: true
  provider: "s3"
  s3:
    bucket: "my-app-updates"
    region: "us-east-1"
    path: "/releases"
```

### S3 Bucket Structure

    my-app-updates/
    └── releases/
        ├── latest.yml           # Update manifest
        ├── latest-mac.yml       # macOS manifest
        ├── latest-linux.yml     # Linux manifest
        ├── MyApp-1.0.0.dmg
        ├── MyApp-Setup-1.0.0.exe
        └── MyApp-1.0.0.AppImage

### AWS Credentials

The app needs AWS credentials via environment variables:

``` bash
export AWS_ACCESS_KEY_ID=xxx
export AWS_SECRET_ACCESS_KEY=xxx
```

## Generic HTTP Server

For custom infrastructure:

``` yaml
updates:
  enabled: true
  provider: "generic"
  generic:
    url: "https://updates.example.com/releases"
```

### Server Requirements

Your server must host:

1.  **Update manifests** (`latest.yml`, `latest-mac.yml`,
    `latest-linux.yml`)
2.  **Application binaries**
3.  **CORS headers** if serving from different domain

Example `latest.yml`:

``` yaml
version: 1.1.0
files:
  - url: MyApp-Setup-1.1.0.exe
    sha512: abc123...
    size: 75000000
path: MyApp-Setup-1.1.0.exe
sha512: abc123...
releaseDate: '2024-01-15T12:00:00.000Z'
```

## Code Signing

> **Warning**
>
> Unsigned applications trigger security warnings on macOS and Windows.
> Code signing is strongly recommended for production apps.

### macOS Code Signing

Set environment variables in your build environment:

``` bash
export CSC_LINK=/path/to/certificate.p12
export CSC_KEY_PASSWORD=your-password
export APPLE_ID=your@email.com
export APPLE_APP_SPECIFIC_PASSWORD=xxxx-xxxx-xxxx-xxxx
```

### Windows Code Signing

``` bash
export CSC_LINK=/path/to/certificate.pfx
export CSC_KEY_PASSWORD=your-password
```

## Disabling Updates

To disable auto-updates:

``` r
disable_auto_updates("path/to/app")
```

Or manually set in `_shinyelectron.yml`:

``` yaml
updates:
  enabled: false
```

## Troubleshooting

### Update Check Fails

**Symptom:** “Error checking for updates”

**Solutions:** 1. Check internet connectivity 2. Verify GitHub
repository exists and is accessible 3. For private repos, ensure
`GH_TOKEN` is set 4. Check firewall settings

### Update Downloads but Doesn’t Install

**Symptom:** Update downloads but app doesn’t update on restart

**Solutions:** 1. Ensure app has write permissions to its directory 2.
On macOS, app must be in Applications folder 3. Check if antivirus is
blocking the update

### Version Not Detected

**Symptom:** App always shows “No updates available”

**Solutions:** 1. Verify version in `package.json` matches release tag
2. Ensure release artifacts follow naming convention 3. Check that
release is published (not draft)

### Debug Logging

Enable detailed logging by setting environment variable:

``` bash
export ELECTRON_ENABLE_LOGGING=1
```

Check logs in: - macOS: `~/Library/Logs/{app name}/` - Windows:
`%USERPROFILE%\AppData\Roaming\{app name}\logs\` - Linux:
`~/.config/{app name}/logs/`

## GitHub Actions Integration

Automate releases with GitHub Actions:

``` yaml
name: Release

on:
  push:
    tags: ['v*']

jobs:
  build:
    runs-on: ${{ matrix.os }}
    strategy:
      matrix:
        os: [macos-latest, windows-latest, ubuntu-latest]

    steps:
      - uses: actions/checkout@v6

      - name: Setup R
        uses: r-lib/actions/setup-r@v2

      - name: Build app
        run: |
          Rscript -e "shinyelectron::export('app', destdir = 'build')"

      - name: Upload to Release
        uses: softprops/action-gh-release@v3
        with:
          files: build/electron-app/dist/*
```

## Next Steps

- **[Configuration](https://r-pkg.thecoatlessprofessor.com/shinyelectron/articles/configuration.md)**:
  Full configuration reference
- **[GitHub
  Actions](https://r-pkg.thecoatlessprofessor.com/shinyelectron/articles/github-actions.md)**:
  Automated CI/CD builds
- **[Advanced
  Features](https://r-pkg.thecoatlessprofessor.com/shinyelectron/articles/advanced-features.md)**:
  Splash screens, system tray
