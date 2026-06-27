#' List python-build-standalone releases from GitHub
#'
#' Fetches release metadata from the astral-sh/python-build-standalone GitHub
#' API. Returns a list of release objects, each with a `tag_name` field and an
#' `assets` list whose elements have a `name` field. Releases are ordered
#' newest first (GitHub API default). This function is intentionally a thin
#' network wrapper so it can be stubbed in tests.
#'
#' @return List of release objects from the GitHub releases API.
#' @keywords internal
pbs_list_releases <- function() {
  url <- "https://api.github.com/repos/astral-sh/python-build-standalone/releases"
  tmp <- tempfile(fileext = ".json")
  on.exit(unlink(tmp), add = TRUE)

  status <- tryCatch(
    utils::download.file(url, tmp, mode = "wb", quiet = TRUE),
    error = function(e) {
      cli::cli_abort(c(
        "Could not reach the python-build-standalone release API.",
        "x" = "{e$message}",
        "i" = "Check your internet connection.",
        "i" = paste0(
          "Or pin a version in your config matching the maintained default: ",
          "{.val {SHINYELECTRON_DEFAULTS$runtime_versions$python$version}}."
        )
      ))
    }
  )
  if (!identical(status, 0L)) {
    cli::cli_abort(c(
      "Could not reach the python-build-standalone release API.",
      "x" = "HTTP request returned status {status}",
      "i" = "Check your internet connection.",
      "i" = paste0(
        "Or pin a version in your config matching the maintained default: ",
        "{.val {SHINYELECTRON_DEFAULTS$runtime_versions$python$version}}."
      )
    ))
  }

  jsonlite::fromJSON(tmp, simplifyVector = FALSE)
}

#' Resolve a Python version to its python-build-standalone release
#'
#' Scans release asset names of the form
#' `cpython-<ver>+<release>-<arch>-<os>-install_only.tar.gz`. For an explicit
#' version, returns the newest release that contains an asset for that version.
#' For `"latest"`, returns the newest release and the first CPython version
#' found in it. Network access is isolated to `pbs_list_releases()` so tests
#' can stub that function.
#'
#' @param version Character string. A concrete Python version such as
#'   `"3.14.6"`, or `"latest"` for the newest available build.
#' @return Named list with elements `version` (character) and `release`
#'   (character YYYYMMDD tag).
#' @keywords internal
python_resolve_pbs <- function(version = "latest") {
  releases <- pbs_list_releases()

  # Asset pattern: cpython-<ver>+<release_date>-<arch>-<os>-install_only.tar.gz
  asset_re <- "^cpython-(\\d+\\.\\d+\\.\\d+)\\+(\\d{8})-.*-install_only\\.tar\\.gz$"

  if (identical(version, "latest")) {
    for (rel in releases) {
      for (asset in rel$assets) {
        m <- regmatches(asset$name, regexec(asset_re, asset$name))[[1]]
        if (length(m) == 3L) {
          return(list(version = m[[2L]], release = m[[3L]]))
        }
      }
    }
    cli::cli_abort(c(
      "No python-build-standalone release with a CPython install_only asset was found.",
      "i" = "Check your internet connection.",
      "i" = paste0(
        "Or pin the maintained default version in your config: ",
        "{.val {SHINYELECTRON_DEFAULTS$runtime_versions$python$version}}."
      )
    ))
  } else {
    for (rel in releases) {
      for (asset in rel$assets) {
        m <- regmatches(asset$name, regexec(asset_re, asset$name))[[1]]
        if (length(m) == 3L && identical(m[[2L]], version)) {
          return(list(version = m[[2L]], release = m[[3L]]))
        }
      }
    }
    cli::cli_abort(c(
      "Python {.val {version}} was not found in any python-build-standalone release.",
      "i" = paste0(
        "Check available releases at ",
        "{.url https://github.com/astral-sh/python-build-standalone/releases}."
      ),
      "i" = paste0(
        "Or pin the maintained default: ",
        "{.val {SHINYELECTRON_DEFAULTS$runtime_versions$python$version}}."
      )
    ))
  }
}

#' Resolve a Python version to its python-build-standalone release (offline-first)
#'
#' Uses the offline default pin when the version matches it (no network), and
#' only queries the registry for a custom or "latest" version.
#'
#' @param version Character string. A concrete Python version such as
#'   `"3.14.6"`, or `"latest"` for the newest available build.
#' @return Named list with elements `version` (character) and `release`
#'   (character YYYYMMDD tag).
#' @keywords internal
resolve_python_pbs <- function(version) {
  pin <- SHINYELECTRON_DEFAULTS$runtime_versions$python
  if (identical(version, pin$version)) {
    return(list(version = pin$version, release = pin$release))
  }
  python_resolve_pbs(version)
}

#' Construct download URL for portable Python
#'
#' Uses python-build-standalone releases for portable Python builds.
#'
#' @param version Character string. Python version (e.g., "3.14.6").
#' @param platform Character string. Target platform.
#' @param arch Character string. Target architecture.
#' @param release_date Character string. python-build-standalone release tag
#'   (YYYYMMDD). Required; must match a release tag on
#'   \url{https://github.com/astral-sh/python-build-standalone/releases}.
#' @return Character string. Download URL.
#' @keywords internal
python_download_url <- function(version, platform = NULL, arch = NULL,
                                release_date) {
  # release_date must match an astral-sh/python-build-standalone release tag
  # Check https://github.com/astral-sh/python-build-standalone/releases for latest
  platform <- platform %||% detect_current_platform()
  arch <- arch %||% detect_current_arch()

  pbs_arch <- switch(arch,
    "arm64" = "aarch64",
    "x64" = "x86_64",
    cli::cli_abort("Unsupported architecture for portable Python: {.val {arch}}")
  )
  pbs_os <- switch(platform,
    "win" = "pc-windows-msvc",
    "mac" = "apple-darwin",
    "linux" = "unknown-linux-gnu",
    cli::cli_abort("Unsupported platform for portable Python: {.val {platform}}")
  )

  # python-build-standalone ships the `install_only` asset as tar.gz on every
  # platform, Windows included. Modern Windows (10+) has tar.exe with gzip
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
#' @param version Character string. Python version to install (e.g.,
#'   `"3.14.6"`). If NULL, the maintained pin in
#'   `SHINYELECTRON_DEFAULTS$runtime_versions$python$version` is used.
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
install_python <- function(version = NULL, platform = NULL, arch = NULL,
                           force = FALSE, verbose = TRUE) {
  platform <- platform %||% detect_current_platform()
  arch <- arch %||% detect_current_arch()

  if (is.null(version)) version <- SHINYELECTRON_DEFAULTS$runtime_versions$python$version

  if (!grepl("^\\d+\\.\\d+\\.\\d+$", version)) {
    cli::cli_abort(c(
      "Invalid Python version format: {.val {version}}",
      "i" = "Expected format: major.minor.patch (e.g., 3.12.0)"
    ))
  }

  pbs <- resolve_python_pbs(version)

  if (verbose) {
    cli::cli_alert_info("Platform: {platform}, Architecture: {arch}")
  }

  download_and_extract_portable_tool(
    label = "Python",
    version = version,
    install_path = python_install_path(version, platform, arch),
    download_url = python_download_url(version, platform, arch, release_date = pbs$release),
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
#' @param release_date Character string. python-build-standalone release tag
#'   (YYYYMMDD). If NULL, resolved automatically via `resolve_python_pbs()`.
#' @return Character string. JSON content.
#' @keywords internal
generate_python_runtime_manifest <- function(version, platform = NULL, arch = NULL,
                                             release_date = NULL) {
  platform <- platform %||% detect_current_platform()
  arch <- arch %||% detect_current_arch()

  if (is.null(release_date)) release_date <- resolve_python_pbs(version)$release

  manifest <- list(
    schema_version = MANIFEST_SCHEMA_VERSION,
    language = "python",
    version = version,
    download_url = python_download_url(version, platform, arch, release_date = release_date),
    install_path = paste0("~/.shinyelectron/runtimes/Python-", version),
    platform = platform,
    arch = arch
  )

  jsonlite::toJSON(manifest, pretty = TRUE, auto_unbox = TRUE)
}
