#' Portable R Runtime Management
#'
#' Functions for downloading, installing, and managing portable R
#' distributions for bundled and auto-download runtime strategies.
#' Follows the same pattern as R/nodejs.R.
#'
#' @name runtime
#' @keywords internal
NULL

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
      # Windows: portable-r-windows releases
      # x64 uses "x64", ARM uses "aarch64"
      win_arch <- if (arch == "arm64") "aarch64" else "x64"
      paste0("https://github.com/portable-r/portable-r-windows/releases/download/v",
             version, "/portable-r-", version, "-win-", win_arch, ".zip")
    },
    "mac" = {
      # macOS: portable-r-macos releases
      # ARM uses "arm64", Intel uses "x86_64"
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

  # portable-r extracts to a subdirectory named portable-r-{version}-{platform}-{arch}
  # Try common portable-r layouts, then fall back to standard paths
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
    cli::cli_h1("Installing portable R {version}")
    cli::cli_alert_info("Platform: {platform}, Architecture: {arch}")
  }

  install_path <- r_install_path(version, platform, arch)
  if (r_is_installed(version, platform, arch) && !force) {
    if (verbose) {
      cli::cli_alert_success("R {version} already installed at {.path {install_path}}")
    }
    return(invisible(install_path))
  }

  url <- r_download_url(version, platform, arch)
  if (verbose) cli::cli_alert_info("Downloading from {.url {url}}")

  temp_file <- tempfile(fileext = paste0(".", tools::file_ext(url)))
  tryCatch({
    utils::download.file(url, temp_file, mode = "wb", quiet = !verbose)
  }, error = function(e) {
    cli::cli_abort(c(
      "Failed to download R {version}",
      "x" = "URL: {.url {url}}",
      "x" = "Error: {e$message}"
    ))
  })

  # Expand ~ to full path (tar doesn't handle ~)
  install_path <- path.expand(install_path)
  fs::dir_create(install_path, recurse = TRUE)

  if (verbose) cli::cli_alert_info("Extracting R {version}...")

  tryCatch({
    ext <- tools::file_ext(temp_file)
    if (ext == "gz") {
      # macOS: portable-r tar.gz. Use internal tar to avoid a GNU-tar-on-Windows
      # path resolution bug (misparses "C:\\..." as a remote host).
      utils::untar(temp_file, exdir = install_path, tar = "internal")
    } else if (ext == "zip") {
      # Windows: portable-r zip
      utils::unzip(temp_file, exdir = install_path)
    }
  }, error = function(e) {
    unlink(install_path, recursive = TRUE)
    cli::cli_abort(c(
      "Failed to extract R {version}",
      "x" = "Error: {e$message}"
    ))
  })

  unlink(temp_file)

  exe <- r_executable(version, platform, arch)
  if (is.null(exe)) {
    cli::cli_warn(c(
      "R {version} was extracted but Rscript executable was not found",
      "i" = "Installation path: {.path {install_path}}",
      "i" = "You may need to adjust the path manually"
    ))
  } else if (verbose) {
    cli::cli_alert_success("R {version} installed at {.path {install_path}}")
    cli::cli_alert_info("Rscript: {.path {exe}}")
  }

  invisible(install_path)
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

# ---- Python Runtime Functions ----

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
    cli::cli_h1("Installing portable Python {version}")
    cli::cli_alert_info("Platform: {platform}, Architecture: {arch}")
  }

  install_path <- python_install_path(version, platform, arch)
  if (python_is_installed(version, platform, arch) && !force) {
    if (verbose) {
      cli::cli_alert_success("Python {version} already installed at {.path {install_path}}")
    }
    return(invisible(install_path))
  }

  url <- python_download_url(version, platform, arch)
  if (verbose) cli::cli_alert_info("Downloading from {.url {url}}")

  temp_file <- tempfile(fileext = paste0(".", tools::file_ext(url)))
  tryCatch({
    utils::download.file(url, temp_file, mode = "wb", quiet = !verbose)
  }, error = function(e) {
    cli::cli_abort(c(
      "Failed to download Python {version}",
      "x" = "URL: {.url {url}}",
      "x" = "Error: {e$message}"
    ))
  })

  fs::dir_create(install_path, recurse = TRUE)

  if (verbose) cli::cli_alert_info("Extracting Python {version}...")

  tryCatch({
    ext <- tools::file_ext(temp_file)
    if (ext == "gz") {
      # Force R's internal tar: a system GNU tar (e.g. from Git for Windows)
      # misparses Windows paths like "C:\\..." as a remote host.
      utils::untar(temp_file, exdir = install_path, tar = "internal")
    } else if (ext == "zip") {
      utils::unzip(temp_file, exdir = install_path)
    }
  }, error = function(e) {
    unlink(install_path, recursive = TRUE)
    cli::cli_abort(c(
      "Failed to extract Python {version}",
      "x" = "Error: {e$message}"
    ))
  })

  unlink(temp_file)

  exe <- python_executable(version, platform, arch)
  if (is.null(exe)) {
    cli::cli_warn(c(
      "Python {version} was extracted but python executable was not found",
      "i" = "Installation path: {.path {install_path}}"
    ))
  } else if (verbose) {
    cli::cli_alert_success("Python {version} installed at {.path {install_path}}")
  }

  invisible(install_path)
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
