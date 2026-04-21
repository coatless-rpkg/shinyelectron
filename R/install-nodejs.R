#' Get latest Node.js LTS version
#'
#' Queries the Node.js distribution API to find the latest LTS version.
#'
#' @return Character string with version number (without 'v' prefix)
#' @keywords internal
nodejs_latest_lts <- function() {
  url <- "https://nodejs.org/dist/index.json"

  tryCatch({
    versions <- jsonlite::fromJSON(url)
    # Filter for LTS versions (lts field is not FALSE/NA)
    lts_versions <- versions[!is.na(versions$lts) & versions$lts != FALSE, ]

    if (nrow(lts_versions) == 0) {
      cli::cli_abort("No LTS versions found from Node.js API")
    }

    # Return the first (latest) version without 'v' prefix
    gsub("^v", "", lts_versions$version[1])
  }, error = function(e) {
    cli::cli_abort(c(
      "Failed to fetch Node.js version information",
      "x" = "Error: {e$message}",
      "i" = "Check your internet connection",
      "i" = "Or specify a version manually: {.code install_nodejs(version = \"22.0.0\")}"
    ))
  })
}

#' Generate Node.js download URL
#'
#' @param version Character Node.js version (e.g., "22.0.0")
#' @param platform Character platform ("win", "mac", "linux")
#' @param arch Character architecture ("x64", "arm64")
#' @return Character URL to download Node.js
#' @keywords internal
nodejs_download_url <- function(version, platform, arch) {
  # Map platform names to Node.js naming convention
node_platform <- switch(platform,
    "mac" = "darwin",
    "win" = "win",
    "linux" = "linux",
    cli::cli_abort("Unsupported platform: {platform}")
  )

  # File extension based on platform
  ext <- if (platform == "win") "zip" else "tar.gz"

  sprintf(
    "https://nodejs.org/dist/v%s/node-v%s-%s-%s.%s",
    version, version, node_platform, arch, ext
  )
}

#' Get Node.js SHASUMS URL
#'
#' @param version Character Node.js version
#' @return Character URL to SHASUMS256.txt
#' @keywords internal
nodejs_shasums_url <- function(version) {
  sprintf("https://nodejs.org/dist/v%s/SHASUMS256.txt", version)
}

#' Download Node.js checksums
#'
#' @param version Character Node.js version
#' @return Named character vector (filename = checksum)
#' @keywords internal
nodejs_download_checksums <- function(version) {
  url <- nodejs_shasums_url(version)

  tryCatch({
    # Download SHASUMS file
    content <- readLines(url, warn = FALSE)

    # Parse: each line is "checksum  filename"
    checksums <- vapply(strsplit(content, "\\s+"), function(x) {
      if (length(x) >= 2) x[1] else NA_character_
    }, character(1))

    names(checksums) <- vapply(strsplit(content, "\\s+"), function(x) {
      if (length(x) >= 2) x[2] else NA_character_
    }, character(1))

    checksums[!is.na(checksums)]
  }, error = function(e) {
    cli::cli_warn(c(
      "Failed to download checksums for Node.js v{version}",
      "i" = "Skipping checksum verification"
    ))
    character(0)
  })
}

#' Compute SHA256 checksum
#'
#' Uses tools::sha256sum() to compute SHA256 hash.
#'
#' @param file_path Character path to file
#' @return Character SHA256 hash, or NULL if unable to compute
#' @keywords internal
compute_sha256 <- function(file_path) {
  tryCatch({
    hash <- tools::sha256sum(file_path)
    unname(hash)
  }, error = function(e) {
    NULL
  })
}

#' Verify file checksum
#'
#' @param file_path Character path to file
#' @param expected_checksum Character expected SHA256 checksum
#' @return Logical TRUE if valid (or if verification unavailable)
#' @keywords internal
nodejs_verify_checksum <- function(file_path, expected_checksum) {
  if (is.na(expected_checksum) || expected_checksum == "") {
    return(TRUE)  # Skip verification if no checksum
  }

  actual_checksum <- compute_sha256(file_path)

  if (is.null(actual_checksum)) {
    cli::cli_warn(c(
      "Could not compute SHA-256 for {.file {basename(file_path)}}",
      "i" = "Integrity check skipped; install continuing",
      "i" = "If the install behaves oddly, remove {.path {dirname(file_path)}} and retry"
    ))
    return(TRUE)  # Don't fail if verification unavailable
  }

  tolower(actual_checksum) == tolower(expected_checksum)
}

#' Get Node.js installation path in cache
#'
#' @param version Character Node.js version (NULL for base path)
#' @param platform Character platform (defaults to current)
#' @param arch Character architecture (defaults to current)
#' @return Character path to Node.js installation
#' @keywords internal
nodejs_install_path <- function(version = NULL, platform = NULL, arch = NULL) {
  base_path <- fs::path(cache_dir(), "nodejs")

  if (is.null(version)) {
    return(base_path)
  }

  platform <- platform %||% detect_current_platform()
  arch <- arch %||% detect_current_arch()

  # Map platform for directory naming
  node_platform <- switch(platform,
    "mac" = "darwin",
    platform
  )

  fs::path(base_path, paste0("v", version), paste0(node_platform, "-", arch))
}

#' Check if Node.js is installed locally
#'
#' @param version Character Node.js version (NULL = any version)
#' @return Logical TRUE if installed
#' @keywords internal
nodejs_is_installed <- function(version = NULL) {
  if (is.null(version)) {
    # Check if any version is installed
    base_path <- nodejs_install_path()
    if (!fs::dir_exists(base_path)) return(FALSE)

    versions <- nodejs_list_installed()
    return(length(versions) > 0)
  }

  install_path <- nodejs_install_path(version)
  fs::dir_exists(install_path)
}

#' Get path to local Node.js executable
#'
#' @param version Character Node.js version (NULL = latest installed)
#' @return Character path to node executable, or NULL if not found
#' @keywords internal
nodejs_executable <- function(version = NULL) {
  if (is.null(version)) {
    versions <- nodejs_list_installed()
    if (length(versions) == 0) return(NULL)
    version <- versions[1]  # Use latest/first
  }

  install_path <- nodejs_install_path(version)
  platform <- detect_current_platform()

  if (platform == "win") {
    node_path <- fs::path(install_path, "node.exe")
  } else {
    node_path <- fs::path(install_path, "bin", "node")
  }

  if (fs::file_exists(node_path)) node_path else NULL
}

#' Get path to local npm executable
#'
#' @param version Character Node.js version (NULL = latest installed)
#' @return Character path to npm executable, or NULL if not found
#' @keywords internal
npm_executable <- function(version = NULL) {
  if (is.null(version)) {
    versions <- nodejs_list_installed()
    if (length(versions) == 0) return(NULL)
    version <- versions[1]
  }

  install_path <- nodejs_install_path(version)
  platform <- detect_current_platform()

  if (platform == "win") {
    npm_path <- fs::path(install_path, "npm.cmd")
  } else {
    npm_path <- fs::path(install_path, "bin", "npm")
  }

  if (fs::file_exists(npm_path)) npm_path else NULL
}

#' List installed Node.js versions
#'
#' @return Character vector of installed versions (sorted newest first)
#' @keywords internal
nodejs_list_installed <- function() {
  base_path <- nodejs_install_path()

  if (!fs::dir_exists(base_path)) {
    return(character(0))
  }

  # List version directories (v22.0.0, etc.)
  version_dirs <- list.dirs(base_path, recursive = FALSE, full.names = FALSE)
  version_dirs <- version_dirs[grepl("^v\\d+", version_dirs)]

  # Check each has actual binaries for current platform
  platform <- detect_current_platform()
  arch <- detect_current_arch()

  node_platform <- switch(platform, "mac" = "darwin", platform)
  target_dir <- paste0(node_platform, "-", arch)

  valid_versions <- vapply(version_dirs, function(v) {
    full_path <- fs::path(base_path, v, target_dir)
    fs::dir_exists(full_path)
  }, logical(1))

  versions <- gsub("^v", "", version_dirs[valid_versions])

  # Sort by version number (newest first)
  if (length(versions) > 0) {
    versions[order(numeric_version(versions), decreasing = TRUE)]
  } else {
    character(0)
  }
}

#' Install Node.js locally
#'
#' Downloads and installs Node.js to the shinyelectron cache directory.
#' This allows using Node.js/npm without requiring system-wide installation.
#'
#' @param version Character Node.js version to install. If NULL (default),
#'   automatically detects the latest LTS version.
#' @param platform Character target platform ("win", "mac", "linux").
#'   Default is current platform.
#' @param arch Character target architecture ("x64", "arm64").
#'   Default is current architecture.
#' @param force Logical whether to reinstall if already exists. Default FALSE.
#' @param verbose Logical whether to show progress. Default TRUE.
#'
#' @return Invisibly returns the path to the installed Node.js directory.
#'
#' @seealso [install_r()], [install_python()] for other runtime installers.
#'
#' @examples
#' \dontrun{
#' # Install latest LTS version
#' install_nodejs()
#'
#' # Install specific version
#' install_nodejs(version = "20.0.0")
#'
#' # Force reinstall
#' install_nodejs(force = TRUE)
#' }
#'
#' @export
install_nodejs <- function(version = NULL, platform = NULL, arch = NULL,
                           force = FALSE, verbose = TRUE) {
  # Auto-detect latest LTS if version not specified
  if (is.null(version)) {
    if (verbose) cli::cli_alert_info("Detecting latest Node.js LTS version...")
    version <- nodejs_latest_lts()
    if (verbose) cli::cli_alert_success("Latest LTS: v{version}")
  }

  # Use current platform/arch if not specified
  platform <- platform %||% detect_current_platform()
  arch <- arch %||% detect_current_arch()

  # Check if already installed
  install_dir <- nodejs_install_path(version, platform, arch)

  if (fs::dir_exists(install_dir) && !force) {
    if (verbose) {
      cli::cli_alert_info("Node.js v{version} already installed at {.path {install_dir}}")
      cli::cli_alert_info("Use {.code force = TRUE} to reinstall")
    }
    return(invisible(install_dir))
  }

  if (verbose) {
    cli::cli_h1("Installing Node.js v{version}")
    cli::cli_alert_info("Platform: {platform}")
    cli::cli_alert_info("Architecture: {arch}")
  }

  # Create temp directory for download
  temp_dir <- tempfile("nodejs_download_")
  fs::dir_create(temp_dir)
  on.exit(unlink(temp_dir, recursive = TRUE), add = TRUE)

  # Get download URL
  url <- nodejs_download_url(version, platform, arch)
  filename <- basename(url)
  archive_path <- fs::path(temp_dir, filename)

  # Download checksums
  if (verbose) cli::cli_alert_info("Fetching checksums...")
  checksums <- nodejs_download_checksums(version)

  # Download archive
  if (verbose) {
    cli::cli_alert_info("Downloading from {.url {url}}")
  }

  tryCatch({
    utils::download.file(url, archive_path, mode = "wb", quiet = !verbose)
  }, error = function(e) {
    cli::cli_abort(c(
      "Failed to download Node.js",
      "x" = "URL: {url}",
      "x" = "Error: {e$message}",
      "i" = "Check your internet connection",
      "i" = "You can also download manually and extract to: {.path {install_dir}}"
    ))
  })

  # Verify checksum
  if (length(checksums) > 0 && filename %in% names(checksums)) {
    if (verbose) cli::cli_alert_info("Verifying checksum...")
    expected <- checksums[filename]

    if (!nodejs_verify_checksum(archive_path, expected)) {
      cli::cli_abort(c(
        "Checksum verification failed",
        "x" = "Downloaded file may be corrupted",
        "i" = "Try again with {.code install_nodejs(version = \"{version}\", force = TRUE)}"
      ))
    }
    if (verbose) cli::cli_alert_success("Checksum verified")
  }

  # Extract archive
  if (verbose) cli::cli_alert_info("Extracting archive...")

  # Ensure parent directory exists
  fs::dir_create(dirname(install_dir), recurse = TRUE)

  # Remove existing if force reinstall
  if (fs::dir_exists(install_dir)) {
    unlink(install_dir, recursive = TRUE)
  }

  if (platform == "win") {
    utils::unzip(archive_path, exdir = dirname(install_dir))
    # Find extracted directory name
    extracted_name <- gsub("\\.zip$", "", filename)
    extracted_path <- fs::path(dirname(install_dir), extracted_name)

    if (fs::dir_exists(extracted_path)) {
      fs::file_move(extracted_path, install_dir)
    }
  } else {
    utils::untar(archive_path, exdir = dirname(install_dir), tar = "internal")
    # Find extracted directory name
    extracted_name <- gsub("\\.tar\\.gz$", "", filename)
    extracted_path <- fs::path(dirname(install_dir), extracted_name)

    if (fs::dir_exists(extracted_path)) {
      fs::file_move(extracted_path, install_dir)
    }
  }

  # Verify installation
  node_exe <- nodejs_executable(version)
  if (is.null(node_exe) || !fs::file_exists(node_exe)) {
    cli::cli_abort(c(
      "Installation failed",
      "x" = "Node.js executable not found after extraction",
      "i" = "Expected at: {.path {install_dir}}"
    ))
  }

  if (verbose) {
    cli::cli_alert_success("Node.js v{version} installed successfully")
    cli::cli_alert_info("Location: {.path {install_dir}}")

    # Show how to use
    cli::cli_alert_info("shinyelectron will automatically use this installation")
  }

  invisible(install_dir)
}

#' Remove Node.js installation
#'
#' @param version Character version to remove. If NULL, removes all versions.
#' @param verbose Logical whether to show progress. Default TRUE.
#' @return Invisible NULL
#' @keywords internal
nodejs_remove <- function(version = NULL, verbose = TRUE) {
  if (is.null(version)) {
    # Remove all
    base_path <- nodejs_install_path()
    if (fs::dir_exists(base_path)) {
      fs::dir_delete(base_path)
      if (verbose) cli::cli_alert_success("Removed all Node.js installations")
    }
  } else {
    # Remove specific version (all platforms)
    base_path <- nodejs_install_path()
    version_path <- fs::path(base_path, paste0("v", version))

    if (fs::dir_exists(version_path)) {
      fs::dir_delete(version_path)
      if (verbose) cli::cli_alert_success("Removed Node.js v{version}")
    }
  }

  invisible(NULL)
}
