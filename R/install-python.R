#' Construct download URL for portable Python
#'
#' Uses python-build-standalone releases for portable Python builds.
#'
#' @param version Character string. Python version (e.g., "3.12.10").
#' @param platform Character string. Target platform.
#' @param arch Character string. Target architecture.
#' @return Character string. Download URL.
#' @keywords internal
python_download_url <- function(version, platform = NULL, arch = NULL,
                                release_date = "20250409") {
  # release_date must match an astral-sh/python-build-standalone release tag
  # Check https://github.com/astral-sh/python-build-standalone/releases for latest
  platform <- platform %||% detect_current_platform()
  arch <- arch %||% detect_current_arch()

  pbs_arch <- switch(arch, "arm64" = "aarch64", "x64" = "x86_64")
  pbs_os <- switch(platform,
    "win" = "pc-windows-msvc",
    "mac" = "apple-darwin",
    "linux" = "unknown-linux-gnu"
  )

  # python-build-standalone ships the `install_only` asset as tar.gz on every
  # platform — Windows included. Modern Windows (10+) has tar.exe with gzip
  # support built in, so extraction works the same way everywhere.
  paste0(
    "https://github.com/astral-sh/python-build-standalone/releases/download/",
    release_date, "/",
    "cpython-", version, "+", release_date, "-",
    pbs_arch, "-", pbs_os, "-install_only.tar.gz"
  )
}

#' Get the installation path for a cached Python version
#'
#' @param version Character string. Python version.
#' @param platform Character string. Platform (default: current).
#' @param arch Character string. Architecture (default: current).
#' @return Character string. Path to the cached Python installation.
#' @keywords internal
python_install_path <- function(version, platform = NULL, arch = NULL) {
  platform <- platform %||% detect_current_platform()
  arch <- arch %||% detect_current_arch()
  fs::path(cache_dir(), "python", platform, arch, version)
}

#' Check if a portable Python version is installed
#'
#' @param version Character string. Python version to check.
#' @param platform Character string. Platform (default: current).
#' @param arch Character string. Architecture (default: current).
#' @return Logical.
#' @keywords internal
python_is_installed <- function(version, platform = NULL, arch = NULL) {
  path <- python_install_path(version, platform, arch)
  fs::dir_exists(path)
}

#' Get the path to the Python executable in a cached installation
#'
#' @param version Character string. Python version.
#' @param platform Character string. Platform (default: current).
#' @param arch Character string. Architecture (default: current).
#' @return Character string or NULL.
#' @keywords internal
python_executable <- function(version, platform = NULL, arch = NULL) {
  platform <- platform %||% detect_current_platform()
  arch <- arch %||% detect_current_arch()
  install_path <- python_install_path(version, platform, arch)

  if (platform == "win") {
    exe_path <- fs::path(install_path, "python", "python.exe")
  } else {
    exe_path <- fs::path(install_path, "python", "bin", "python3")
  }

  if (fs::file_exists(exe_path)) exe_path else NULL
}

#' Install a portable Python distribution
#'
#' Downloads and caches a portable Python build from python-build-standalone.
#'
#' @param version Character string. Python version to install.
#' @param platform Character string. Target platform.
#' @param arch Character string. Target architecture.
#' @param force Logical. Whether to reinstall if already cached.
#' @param verbose Logical. Whether to show progress.
#' @return Character string. Path to the installed Python directory.
#'
#' @seealso [install_r()], [install_nodejs()] for other runtime installers;
#'   [python_executable()] to find the installed Python path.
#'
#' @examples
#' \dontrun{
#' # Install default Python version
#' install_python()
#'
#' # Install specific version
#' install_python(version = "3.12.0")
#' }
#'
#' @export
install_python <- function(version = "3.12.10", platform = NULL, arch = NULL,
                           force = FALSE, verbose = TRUE) {
  platform <- platform %||% detect_current_platform()
  arch <- arch %||% detect_current_arch()

  if (!grepl("^\\d+\\.\\d+\\.\\d+$", version)) {
    cli::cli_abort(c(
      "Invalid Python version format: {.val {version}}",
      "i" = "Expected format: major.minor.patch (e.g., 3.12.0)"
    ))
  }

  if (verbose) {
    cli::cli_alert_info("Platform: {platform}, Architecture: {arch}")
  }

  download_and_extract_portable_tool(
    label = "Python",
    version = version,
    install_path = python_install_path(version, platform, arch),
    download_url = python_download_url(version, platform, arch),
    executable_finder = function() python_executable(version, platform, arch),
    force = force,
    is_installed = python_is_installed(version, platform, arch),
    verbose = verbose
  )
}

#' Generate a Python runtime manifest for auto-download
#'
#' @param version Character string. Python version.
#' @param platform Character string. Target platform.
#' @param arch Character string. Target architecture.
#' @return Character string. JSON content.
#' @keywords internal
generate_python_runtime_manifest <- function(version, platform = NULL, arch = NULL) {
  platform <- platform %||% detect_current_platform()
  arch <- arch %||% detect_current_arch()

  manifest <- list(
    language = "python",
    version = version,
    download_url = python_download_url(version, platform, arch),
    install_path = paste0("~/.shinyelectron/runtimes/Python-", version),
    platform = platform,
    arch = arch
  )

  jsonlite::toJSON(manifest, pretty = TRUE, auto_unbox = TRUE)
}
