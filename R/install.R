#' Download and extract a portable runtime into a cache directory
#'
#' Shared helper for `install_r_portable()` and `install_python_standalone()`. Handles the
#' common flow: cache-hit short-circuit, download to temp file, extract
#' by archive type, verify the expected executable appears, cleanup.
#'
#' `install_nodejs()` has additional requirements (SHA256 checksums,
#' directory renaming after extraction) and implements its own flow.
#'
#' @param label Character. Human-readable tool name for messages ("R", "Python").
#' @param version Character. Version string.
#' @param install_path Character. Target cache directory for the extracted
#'   archive. Already-populated path is returned unless `force` is TRUE.
#' @param download_url Character. URL to the archive.
#' @param executable_finder Function with no arguments that returns the
#'   path to the tool's executable after extraction, or NULL if not found.
#' @param force Logical. Reinstall even if `install_path` already exists.
#' @param is_installed Logical. Whether the runtime is already present.
#' @param expected_sha256 Character or NULL. Expected SHA-256 of the archive.
#'   When supplied, the download is verified before extraction.
#' @param verbose Logical. Whether to print progress messages.
#' @return Invisibly returns the installation path.
#' @keywords internal
download_and_extract_portable_tool <- function(label, version, install_path,
                                               download_url, executable_finder,
                                               force = FALSE,
                                               is_installed = FALSE,
                                               expected_sha256 = NULL,
                                               verbose = TRUE) {
  if (is_installed && !force) {
    if (verbose) {
      cli::cli_alert_success("{label} {version} already installed at {.path {install_path}}")
    }
    return(invisible(install_path))
  }

  if (verbose) {
    cli::cli_h1("Installing portable {label} {version}")
    cli::cli_alert_info("Downloading from {.url {download_url}}")
  }

  temp_file <- tempfile(fileext = paste0(".", tools::file_ext(download_url)))
  tryCatch({
    utils::download.file(download_url, temp_file, mode = "wb", quiet = !verbose)
  }, error = function(e) {
    cli::cli_abort(c(
      "Failed to download {label} {version}",
      "x" = "URL: {.url {download_url}}",
      "x" = "Error: {e$message}"
    ))
  })

  # Integrity check when an expected checksum is supplied.
  if (!is.null(expected_sha256)) {
    actual_sha256 <- compute_sha256(temp_file)
    if (!identical(tolower(actual_sha256), tolower(expected_sha256))) {
      unlink(temp_file)
      cli::cli_abort(c(
        "Checksum verification failed for {label} {version}",
        "x" = "Expected SHA-256: {expected_sha256}",
        "x" = "Actual SHA-256:   {actual_sha256}",
        "i" = "The download may be corrupted or tampered with."
      ))
    }
    if (verbose) cli::cli_alert_success("Verified SHA-256 checksum")
  }

  install_path <- path.expand(install_path)

  # Extract into a fresh staging directory so a failed extraction never
  # destroys an existing (working) install; only swap into place on success.
  staging <- paste0(install_path, ".staging-", Sys.getpid())
  if (fs::dir_exists(staging)) unlink(staging, recursive = TRUE)
  fs::dir_create(staging, recurse = TRUE)

  if (verbose) cli::cli_alert_info("Extracting {label} {version}...")

  tryCatch({
    ext <- tools::file_ext(temp_file)
    if (ext == "gz") {
      if (.Platform$OS.type == "windows") {
        # Force R's internal tar so a system GNU tar (e.g. from Git for
        # Windows) doesn't misparse "C:\\..." paths as remote hosts.
        utils::untar(temp_file, exdir = staging, tar = "internal")
      } else {
        # Use system tar on macOS / Linux. macOS bsdtar and Linux GNU tar
        # both handle PAX records that include xattrs (e.g. the Apple
        # com.apple.cs.CodeSignature metadata in portable R archives),
        # which R's internal tar cannot.
        utils::untar(temp_file, exdir = staging, tar = Sys.which("tar"))
      }
    } else if (ext == "zip") {
      utils::unzip(temp_file, exdir = staging)
    } else {
      cli::cli_abort(c(
        "Unsupported archive extension: {.val {ext}}",
        "i" = "Supported formats: {.val {c('gz', 'zip')}}"
      ))
    }
  }, error = function(e) {
    unlink(staging, recursive = TRUE)
    cli::cli_abort(c(
      "Failed to extract {label} {version}",
      "x" = "Error: {e$message}"
    ))
  })

  unlink(temp_file)

  # Swap staging into place. force/reinstall cleanly replaces any prior install.
  if (fs::dir_exists(install_path)) unlink(install_path, recursive = TRUE)
  fs::dir_create(fs::path_dir(install_path), recurse = TRUE)
  fs::file_move(staging, install_path)

  exe <- executable_finder()
  if (is.null(exe)) {
    cli::cli_abort(c(
      "{label} {version} was extracted but the expected executable was not found",
      "x" = "The archive may be corrupted or the download URL may be wrong.",
      "i" = "Installation path: {.path {install_path}}"
    ))
  } else if (verbose) {
    cli::cli_alert_success("{label} {version} installed at {.path {install_path}}")
  }

  invisible(install_path)
}

#' Fetch a published SHA-256 checksum for a portable runtime archive
#'
#' Reads a checksum file published alongside a runtime release and returns the
#' hash for one archive. Two layouts are supported, both in the standard
#' `sha256sum` format (`<hash>  <filename>`):
#'
#' * Per-asset sidecar (portable R): the checksum file contains a single line
#'   for the archive. Pass `asset_filename = NULL` and the first line's hash is
#'   returned.
#' * Combined `SHA256SUMS` (python-build-standalone): the file lists every
#'   asset. Pass `asset_filename` and the matching line's hash is returned.
#'
#' Returns `NULL` when the checksum cannot be fetched or no matching entry is
#' found, so callers can continue without verification rather than failing on a
#' transient network error (the same graceful-skip behavior as the Node.js
#' installer).
#'
#' @param checksum_url Character. URL of the `.sha256` sidecar or `SHA256SUMS`.
#' @param asset_filename Character or NULL. Archive file name to match within a
#'   combined `SHA256SUMS`; `NULL` for a single-asset sidecar.
#' @return Character SHA-256 hash, or `NULL`.
#' @keywords internal
fetch_published_sha256 <- function(checksum_url, asset_filename = NULL) {
  tryCatch({
    # suppressWarnings hides the connection-level "cannot open URL" warning a
    # 404 or offline host emits; the accompanying error is caught below so the
    # caller still gets a clean NULL (graceful skip).
    lines <- suppressWarnings(readLines(checksum_url, warn = FALSE))
    lines <- lines[nzchar(trimws(lines))]
    if (length(lines) == 0) return(NULL)

    parse_hash <- function(line) {
      parts <- strsplit(trimws(line), "\\s+")[[1]]
      if (length(parts) == 0 || !grepl("^[0-9a-fA-F]{64}$", parts[1])) return(NULL)
      list(
        hash = parts[1],
        # sha256sum marks binary entries with a leading "*"; strip it.
        file = if (length(parts) >= 2) basename(sub("^\\*", "", parts[length(parts)])) else NA_character_
      )
    }

    if (is.null(asset_filename)) {
      entry <- parse_hash(lines[1])
      return(if (is.null(entry)) NULL else entry$hash)
    }

    for (line in lines) {
      entry <- parse_hash(line)
      if (!is.null(entry) && identical(entry$file, asset_filename)) {
        return(entry$hash)
      }
    }
    NULL
  }, error = function(e) NULL)
}
