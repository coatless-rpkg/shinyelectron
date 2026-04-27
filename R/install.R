#' Download and extract a portable runtime into a cache directory
#'
#' Shared helper for `install_r()` and `install_python()`. Handles the
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
#' @param verbose Logical. Whether to print progress messages.
#' @return Invisibly returns the installation path.
#' @keywords internal
download_and_extract_portable_tool <- function(label, version, install_path,
                                               download_url, executable_finder,
                                               force = FALSE,
                                               is_installed = FALSE,
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

  install_path <- path.expand(install_path)
  fs::dir_create(install_path, recurse = TRUE)

  if (verbose) cli::cli_alert_info("Extracting {label} {version}...")

  tryCatch({
    ext <- tools::file_ext(temp_file)
    if (ext == "gz") {
      if (.Platform$OS.type == "windows") {
        # Force R's internal tar so a system GNU tar (e.g. from Git for
        # Windows) doesn't misparse "C:\\..." paths as remote hosts.
        utils::untar(temp_file, exdir = install_path, tar = "internal")
      } else {
        # Use system tar on macOS / Linux. macOS bsdtar and Linux GNU tar
        # both handle PAX records that include xattrs (e.g. the Apple
        # com.apple.cs.CodeSignature metadata in portable R archives),
        # which R's internal tar cannot.
        utils::untar(temp_file, exdir = install_path, tar = Sys.which("tar"))
      }
    } else if (ext == "zip") {
      utils::unzip(temp_file, exdir = install_path)
    } else {
      cli::cli_abort(c(
        "Unsupported archive extension: {.val {ext}}",
        "i" = "Supported formats: {.val {c('gz', 'zip')}}"
      ))
    }
  }, error = function(e) {
    unlink(install_path, recursive = TRUE)
    cli::cli_abort(c(
      "Failed to extract {label} {version}",
      "x" = "Error: {e$message}"
    ))
  })

  unlink(temp_file)

  exe <- executable_finder()
  if (is.null(exe)) {
    cli::cli_warn(c(
      "{label} {version} was extracted but the expected executable was not found",
      "i" = "Installation path: {.path {install_path}}"
    ))
  } else if (verbose) {
    cli::cli_alert_success("{label} {version} installed at {.path {install_path}}")
  }

  invisible(install_path)
}
