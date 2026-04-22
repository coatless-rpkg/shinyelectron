# Enable Auto-Updates

Configures automatic update checking for your Electron application.
Updates are distributed via GitHub Releases, S3 buckets, or generic HTTP
servers.

## Usage

``` r
enable_auto_updates(
  appdir,
  provider = c("github", "s3", "generic"),
  owner = NULL,
  repo = NULL,
  check_on_startup = TRUE,
  auto_download = FALSE,
  auto_install = FALSE,
  verbose = TRUE
)
```

## Arguments

- appdir:

  Character path to app directory containing `_shinyelectron.yml`

- provider:

  Character update provider: `"github"` (default), `"s3"`, or
  `"generic"`

- owner:

  Character GitHub username or organization (required for github
  provider)

- repo:

  Character GitHub repository name (required for github provider)

- check_on_startup:

  Logical whether to check for updates when app starts. Default `TRUE`.

- auto_download:

  Logical whether to download updates automatically. Default `FALSE`.

- auto_install:

  Logical whether to install updates automatically on quit. Default
  `FALSE`.

- verbose:

  Logical whether to show progress messages. Default `TRUE`.

## Value

Invisibly returns the path to the updated config file.

## Details

Auto-updates require:

1.  A published application (e.g., to GitHub Releases)

2.  Proper code signing for macOS and Windows (recommended)

3.  The electron-updater package (automatically included in build)

### Update Providers

**GitHub Releases** (recommended for open source):

- Automatically detects new releases by comparing semver tags

- Requires `owner` and `repo` parameters

- Private repos require `GH_TOKEN` environment variable

**S3 Bucket**:

- For self-hosted updates behind a CDN

- Configure bucket, region, and path in `_shinyelectron.yml`

- Bucket must allow public reads or use CloudFront signed URLs

- Required bucket structure: `/{path}/latest-mac.yml`,
  `latest-linux.yml`, `latest.yml`

**Generic HTTP Server**:

- For any HTTP server hosting update files

- Configure base URL in `_shinyelectron.yml`

- Server must host `latest-mac.yml`, `latest-linux.yml`, `latest.yml` at
  the URL root

### Publishing Updates (GitHub Releases)

After enabling auto-updates, follow this workflow to publish updates:

1.  **Bump version** in `_shinyelectron.yml` (e.g., `version: "1.1.0"`)

2.  **Rebuild** with `export(appdir, destdir, build = TRUE)`

3.  **Create a GitHub Release** with a semver tag matching the version:

    - Tag: `v1.1.0` (the `v` prefix is required)

    - Upload the built artifacts from `destdir/electron-app/dist/`:

      - macOS: `.dmg` and `latest-mac.yml`

      - Windows: `.exe` installer and `latest.yml`

      - Linux: `.AppImage` and `latest-linux.yml`

4.  The app checks for updates on startup (if `check_on_startup = TRUE`)
    and notifies the user when a new version is available

### Code Signing Requirement

macOS and Windows require code-signed builds for auto-updates to work.
Unsigned apps will fail the update verification step. Set
`signing: sign: true` in your config and provide credentials via
environment variables (see
[`?validate_signing_config`](https://r-pkg.thecoatlessprofessor.com/shinyelectron/reference/validate_signing_config.md)).

## See also

[`init_config()`](https://r-pkg.thecoatlessprofessor.com/shinyelectron/reference/init_config.md)
for creating initial configuration

## Examples

``` r
if (FALSE) { # \dontrun{
# Enable GitHub-based updates
enable_auto_updates(
  "path/to/app",
  provider = "github",
  owner = "myusername",
  repo = "myapp"
)

# Enable with automatic download
enable_auto_updates(
  "path/to/app",
  provider = "github",
  owner = "myorg",
  repo = "dashboard",
  auto_download = TRUE
)
} # }
```
