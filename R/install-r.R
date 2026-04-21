#' Get the latest R release version
#'
#' Queries the R API for the current release version.
#'
#' @return Character string. The latest R version (e.g., "4.4.1").
#' @keywords internal
r_latest_version <- function() {
  tryCatch({
    url <- "https://api.r-hub.io/rversions/r-release"
    content <- readLines(url, warn = FALSE)
    parsed <- jsonlite::fromJSON(paste(content, collapse = ""))
    parsed$version
  }, error = function(e) {
    cli::cli_abort(c(
      "Failed to query latest R version",
      "x" = "Error: {e$message}",
      "i" = "Check your internet connection"
    ))
  })
}

#' Construct download URL for portable R
#'
#' Generates the download URL for an R build from CRAN.
#'
#' @param version Character string. R version (e.g., "4.4.0").
#' @param platform Character string. Target platform: "win", "mac", "linux".
#' @param arch Character string. Target architecture: "x64", "arm64".
#' @return Character string. Download URL.
#' @keywords internal
r_download_url <- function(version, platform = NULL, arch = NULL) {
  platform <- platform %||% detect_current_platform()
  arch <- arch %||% detect_current_arch()

  switch(platform,
    "win" = {
      win_arch <- if (arch == "arm64") "aarch64" else "x64"
      paste0("https://github.com/portable-r/portable-r-windows/releases/download/v",
             version, "/portable-r-", version, "-win-", win_arch, ".zip")
    },
    "mac" = {
      mac_arch <- if (arch == "arm64") "arm64" else "x86_64"
      paste0("https://github.com/portable-r/portable-r-macos/releases/download/v",
             version, "/portable-r-", version, "-macos-", mac_arch, ".tar.gz")
    },
    "linux" = {
      cli::cli_abort(c(
        "Portable R for Linux is not yet supported for bundled/auto-download strategies",
        "i" = "Use {.val system} or {.val container} runtime strategy on Linux"
      ))
    },
    cli::cli_abort("Unsupported platform: {.val {platform}}")
  )
}

#' Get the installation path for a cached R version
#'
#' @param version Character string. R version.
#' @param platform Character string. Platform (default: current).
#' @param arch Character string. Architecture (default: current).
#' @return Character string. Path to the cached R installation.
#' @keywords internal
r_install_path <- function(version, platform = NULL, arch = NULL) {
  platform <- platform %||% detect_current_platform()
  arch <- arch %||% detect_current_arch()
  path.expand(cache_r_path(version, platform, arch))
}

#' Check if a portable R version is installed
#'
#' @param version Character string. R version to check.
#' @param platform Character string. Platform (default: current).
#' @param arch Character string. Architecture (default: current).
#' @return Logical.
#' @keywords internal
r_is_installed <- function(version, platform = NULL, arch = NULL) {
  path <- r_install_path(version, platform, arch)
  fs::dir_exists(path)
}

#' Get the path to the Rscript executable in a cached installation
#'
#' @param version Character string. R version.
#' @param platform Character string. Platform (default: current).
#' @param arch Character string. Architecture (default: current).
#' @return Character string or NULL. Path to Rscript, or NULL if not found.
#' @keywords internal
r_executable <- function(version, platform = NULL, arch = NULL) {
  platform <- platform %||% detect_current_platform()
  arch <- arch %||% detect_current_arch()
  install_path <- r_install_path(version, platform, arch)

  candidates <- character(0)

  if (platform == "win") {
    win_arch <- if (arch == "arm64") "aarch64" else "x64"
    portable_dir <- paste0("portable-r-", version, "-win-", win_arch)
    candidates <- c(
      fs::path(install_path, portable_dir, "bin", "Rscript.exe"),
      fs::path(install_path, "bin", "Rscript.exe")
    )
  } else if (platform == "mac") {
    mac_arch <- if (arch == "arm64") "arm64" else "x86_64"
    portable_dir <- paste0("portable-r-", version, "-macos-", mac_arch)
    candidates <- c(
      fs::path(install_path, portable_dir, "bin", "Rscript"),
      fs::path(install_path, "bin", "Rscript")
    )
  } else {
    candidates <- c(
      fs::path(install_path, "bin", "Rscript")
    )
  }

  for (exe_path in candidates) {
    if (fs::file_exists(exe_path)) return(exe_path)
  }
  NULL
}

#' Install a portable R distribution
#'
#' Downloads and caches a portable R build. Follows the same pattern
#' as \code{\link{install_nodejs}()}.
#'
#' @param version Character string. R version to install. If NULL, installs latest.
#' @param platform Character string. Target platform.
#' @param arch Character string. Target architecture.
#' @param force Logical. Whether to reinstall if already cached.
#' @param verbose Logical. Whether to show progress.
#' @return Character string. Path to the installed R directory.
#'
#' @seealso [install_python()], [install_nodejs()] for other runtime installers;
#'   [r_executable()] to find the installed Rscript path.
#'
#' @examples
#' \dontrun{
#' # Install latest R release
#' install_r()
#'
#' # Install specific version for a target platform
#' install_r(version = "4.4.0", platform = "win", arch = "x64")
#' }
#'
#' @export
install_r <- function(version = NULL, platform = NULL, arch = NULL,
                      force = FALSE, verbose = TRUE) {
  platform <- platform %||% detect_current_platform()
  arch <- arch %||% detect_current_arch()

  if (is.null(version)) {
    if (verbose) cli::cli_alert_info("Querying latest R release...")
    version <- r_latest_version()
  }

  if (!grepl("^\\d+\\.\\d+\\.\\d+$", version)) {
    cli::cli_abort(c(
      "Invalid R version format: {.val {version}}",
      "i" = "Expected format: major.minor.patch (e.g., 4.4.0)"
    ))
  }

  if (verbose) {
    cli::cli_alert_info("Platform: {platform}, Architecture: {arch}")
  }

  download_and_extract_portable_tool(
    label = "R",
    version = version,
    install_path = r_install_path(version, platform, arch),
    download_url = r_download_url(version, platform, arch),
    executable_finder = function() r_executable(version, platform, arch),
    force = force,
    is_installed = r_is_installed(version, platform, arch),
    verbose = verbose
  )
}

#' Generate a runtime manifest for auto-download
#'
#' Creates a JSON manifest that the Electron app reads on first launch
#' to download the R runtime.
#'
#' @param version Character string. R version.
#' @param platform Character string. Target platform.
#' @param arch Character string. Target architecture.
#' @return Character string. JSON content.
#' @keywords internal
generate_runtime_manifest <- function(version, platform = NULL, arch = NULL) {
  platform <- platform %||% detect_current_platform()
  arch <- arch %||% detect_current_arch()

  download_url <- r_download_url(version, platform, arch)

  manifest <- list(
    language = "r",
    version = version,
    download_url = download_url,
    install_path = paste0("~/.shinyelectron/runtimes/R-", version),
    platform = platform,
    arch = arch
    # sha256: set at build time if the archive is pre-downloaded for integrity verification.
    # The Electron runtime-downloader verifies this hash before extraction when present.
  )

  jsonlite::toJSON(manifest, pretty = TRUE, auto_unbox = TRUE)
}
