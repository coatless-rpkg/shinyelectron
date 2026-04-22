#' Enable Auto-Updates
#'
#' Configures automatic update checking for your Electron application.
#' Updates are distributed via GitHub Releases, S3 buckets, or generic
#' HTTP servers.
#'
#' @param appdir Character path to app directory containing `_shinyelectron.yml`
#' @param provider Character update provider: `"github"` (default), `"s3"`, or `"generic"`
#' @param owner Character GitHub username or organization (required for github provider)
#' @param repo Character GitHub repository name (required for github provider)
#' @param check_on_startup Logical whether to check for updates when app starts. Default `TRUE`.
#' @param auto_download Logical whether to download updates automatically. Default `FALSE`.
#' @param auto_install Logical whether to install updates automatically on quit. Default `FALSE`.
#' @param verbose Logical whether to show progress messages. Default `TRUE`.
#'
#' @return Invisibly returns the path to the updated config file.
#'
#' @details
#' Auto-updates require:
#' 1. A published application (e.g., to GitHub Releases)
#' 2. Proper code signing for macOS and Windows (recommended)
#' 3. The electron-updater package (automatically included in build)
#'
#' ## Update Providers
#'
#' **GitHub Releases** (recommended for open source):
#' - Automatically detects new releases by comparing semver tags
#' - Requires `owner` and `repo` parameters
#' - Private repos require `GH_TOKEN` environment variable
#'
#' **S3 Bucket**:
#' - For self-hosted updates behind a CDN
#' - Configure bucket, region, and path in `_shinyelectron.yml`
#' - Bucket must allow public reads or use CloudFront signed URLs
#' - Required bucket structure: `/{path}/latest-mac.yml`, `latest-linux.yml`, `latest.yml`
#'
#' **Generic HTTP Server**:
#' - For any HTTP server hosting update files
#' - Configure base URL in `_shinyelectron.yml`
#' - Server must host `latest-mac.yml`, `latest-linux.yml`, `latest.yml` at the URL root
#'
#' ## Publishing Updates (GitHub Releases)
#'
#' After enabling auto-updates, follow this workflow to publish updates:
#'
#' 1. **Bump version** in `_shinyelectron.yml` (e.g., `version: "1.1.0"`)
#' 2. **Rebuild** with `export(appdir, destdir, build = TRUE)`
#' 3. **Create a GitHub Release** with a semver tag matching the version:
#'    - Tag: `v1.1.0` (the `v` prefix is required)
#'    - Upload the built artifacts from `destdir/electron-app/dist/`:
#'      - macOS: `.dmg` and `latest-mac.yml`
#'      - Windows: `.exe` installer and `latest.yml`
#'      - Linux: `.AppImage` and `latest-linux.yml`
#' 4. The app checks for updates on startup (if `check_on_startup = TRUE`)
#'    and notifies the user when a new version is available
#'
#' ## Code Signing Requirement
#'
#' macOS and Windows require code-signed builds for auto-updates to work.
#' Unsigned apps will fail the update verification step. Set
#' `signing: sign: true` in your config and provide credentials via
#' environment variables (see `?validate_signing_config`).
#'
#' @examples
#' \dontrun{
#' # Enable GitHub-based updates
#' enable_auto_updates(
#'   "path/to/app",
#'   provider = "github",
#'   owner = "myusername",
#'   repo = "myapp"
#' )
#'
#' # Enable with automatic download
#' enable_auto_updates(
#'   "path/to/app",
#'   provider = "github",
#'   owner = "myorg",
#'   repo = "dashboard",
#'   auto_download = TRUE
#' )
#' }
#'
#' @seealso [init_config()] for creating initial configuration
#' @export
enable_auto_updates <- function(appdir,
                                 provider = c("github", "s3", "generic"),
                                 owner = NULL,
                                 repo = NULL,
                                 check_on_startup = TRUE,
                                 auto_download = FALSE,
                                 auto_install = FALSE,
                                 verbose = TRUE) {
  # Validate inputs
  validate_directory_exists(appdir, "Application directory")
  provider <- match.arg(provider)

  # Validate provider-specific requirements
  if (provider == "github") {
    if (is.null(owner) || is.null(repo)) {
      cli::cli_abort(c(
        "GitHub provider requires {.arg owner} and {.arg repo}",
        "i" = "Example: {.code enable_auto_updates(appdir, owner = 'myuser', repo = 'myapp')}"
      ))
    }
  }

  # Read existing config
  config_path <- find_config(appdir)

  if (is.null(config_path)) {
    if (verbose) {
      cli::cli_alert_info("No config file found, creating one...")
    }
    init_config(appdir, verbose = FALSE)
    config_path <- find_config(appdir)
  }

  # Read and update config
  config <- yaml::read_yaml(config_path)

  # Set updates configuration
  config$updates <- list(
    enabled = TRUE,
    provider = provider,
    check_on_startup = check_on_startup,
    auto_download = auto_download,
    auto_install = auto_install
  )

  # Add provider-specific settings
  if (provider == "github") {
    config$updates$github <- list(
      owner = owner,
      repo = repo,
      private = FALSE
    )
  }

  # Write updated config
  yaml::write_yaml(config, config_path)

  if (verbose) {
    cli::cli_alert_success("Auto-updates enabled with {.val {provider}} provider")

    if (provider == "github") {
      cli::cli_alert_info("Updates will be published to: {.url https://github.com/{owner}/{repo}/releases}")
    }

    cli::cli_alert_info("Settings:")
    cli::cli_bullets(c(
      "*" = "Check on startup: {.val {check_on_startup}}",
      "*" = "Auto-download: {.val {auto_download}}",
      "*" = "Auto-install on quit: {.val {auto_install}}"
    ))
  }

  invisible(config_path)
}

#' Disable Auto-Updates
#'
#' Disables automatic update checking in the configuration file.
#'
#' @param appdir Character path to app directory
#' @param verbose Logical whether to show progress messages. Default `TRUE`.
#'
#' @return Invisibly returns the path to the updated config file.
#'
#' @examples
#' \dontrun{
#' disable_auto_updates("path/to/app")
#' }
#'
#' @export
disable_auto_updates <- function(appdir, verbose = TRUE) {
  validate_directory_exists(appdir, "Application directory")

  config_path <- find_config(appdir)

  if (is.null(config_path)) {
    cli::cli_abort("No configuration file found in: {.path {appdir}}")
  }

  config <- yaml::read_yaml(config_path)

  if (is.null(config$updates) || !isTRUE(config$updates$enabled)) {
    if (verbose) {
      cli::cli_alert_info("Auto-updates are already disabled")
    }
    return(invisible(config_path))
  }

  config$updates$enabled <- FALSE
  yaml::write_yaml(config, config_path)

  if (verbose) {
    cli::cli_alert_success("Auto-updates disabled")
  }

  invisible(config_path)
}

#' Check Auto-Update Status
#'
#' Reports the current auto-update configuration status.
#'
#' @param appdir Character path to app directory
#'
#' @return Invisibly returns a list with: \code{enabled} (logical),
#'   \code{provider} (character or NULL), \code{repo} (character or NULL),
#'   and \code{settings} (list of check_on_startup, auto_download, auto_install).
#'
#' @examples
#' \dontrun{
#' check_auto_update_status("path/to/app")
#' }
#'
#' @export
check_auto_update_status <- function(appdir) {
  validate_directory_exists(appdir, "Application directory")

  config <- read_config(appdir)

  cli::cli_h2("Auto-Update Status")

  if (is.null(config$updates) || !isTRUE(config$updates$enabled)) {
    cli::cli_alert_warning("Auto-updates are {.strong disabled}")
    cli::cli_alert_info("Enable with: {.code shinyelectron::enable_auto_updates(appdir, owner = '...', repo = '...')}")
    return(invisible(config$updates))
  }

  cli::cli_alert_success("Auto-updates are {.strong enabled}")

  provider <- config$updates$provider %||% "github"
  cli::cli_alert_info("Provider: {.val {provider}}")

  if (provider == "github") {
    owner <- config$updates$github$owner
    repo <- config$updates$github$repo

    if (!is.null(owner) && !is.null(repo)) {
      cli::cli_alert_info("Repository: {.url https://github.com/{owner}/{repo}}")
    }
  }

  cli::cli_alert_info("Settings:")
  cli::cli_bullets(c(
    "*" = "Check on startup: {.val {config$updates$check_on_startup %||% TRUE}}",
    "*" = "Auto-download: {.val {config$updates$auto_download %||% FALSE}}",
    "*" = "Auto-install: {.val {config$updates$auto_install %||% FALSE}}"
  ))

  invisible(config$updates)
}
