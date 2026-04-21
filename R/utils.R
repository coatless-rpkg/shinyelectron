#' Detect current platform
#'
#' @return Character string representing current platform ("win", "mac", or "linux")
#' @keywords internal
detect_current_platform <- function() {
  sysname <- Sys.info()[["sysname"]]
  switch(sysname,
         "Windows" = "win",
         "Darwin" = "mac",
         "Linux" = "linux",
         cli::cli_abort("Unsupported platform: {sysname}")
  )
}

#' Detect current architecture
#'
#' @return Character string representing current architecture ("x64" or "arm64")
#' @keywords internal
detect_current_arch <- function() {
  machine <- Sys.info()[["machine"]]
  if (grepl("arm|aarch", machine, ignore.case = TRUE)) {
    "arm64"
  } else {
    "x64"
  }
}
#' Convert a display name to a path-safe slug
#'
#' Converts an application display name to a lowercase, hyphen-separated
#' string safe for use in file paths, container names, and npm package names.
#'
#' @param name Character string. The display name to slugify.
#' @return Character string. The slugified name.
#' @keywords internal
slugify <- function(name) {
  if (!nzchar(name)) {
    cli::cli_abort("App name cannot be empty")
  }
  slug <- tolower(name)
  slug <- gsub("[^a-z0-9]+", "-", slug)
  slug <- gsub("^-|-$", "", slug)
  # Collapse multiple consecutive dashes
  slug <- gsub("-{2,}", "-", slug)
  if (!nzchar(slug)) {
    cli::cli_abort("Cannot create an empty slug from input: {.val {name}}")
  }
  slug
}

#' Validate a slug string
#'
#' Checks that a slug contains only lowercase alphanumeric characters and
#' hyphens, and is not empty.
#'
#' @param slug Character string. The slug to validate.
#' @return Invisible TRUE if valid, otherwise aborts with an error.
#' @keywords internal
validate_slug <- function(slug) {
  if (is.null(slug) || !nzchar(slug)) {
    cli::cli_abort("App slug cannot be empty")
  }
  if (!grepl("^[a-z0-9]([a-z0-9-]*[a-z0-9])?$", slug)) {
    cli::cli_abort(c(
      "Invalid slug: {.val {slug}}",
      "i" = "Slug must contain only lowercase letters, numbers, and hyphens",
      "i" = "Slug must start and end with a letter or number"
    ))
  }
  invisible(TRUE)
}
#' Run a command safely and return the result
#'
#' Wraps processx::run with consistent error handling. Returns a list
#' with status, stdout, and stderr. Never throws — failures are
#' indicated by a non-zero status.
#'
#' @param command Character command to run.
#' @param args Character vector of arguments.
#' @param timeout Numeric timeout in seconds. Default 30.
#' @return List with status, stdout, stderr.
#' @keywords internal
run_command_safe <- function(command, args = character(), timeout = 30) {
  tryCatch(
    processx::run(command, args, error_on_status = FALSE, timeout = timeout),
    error = function(e) list(status = 1L, stdout = "", stderr = e$message)
  )
}
#' Locate Rscript inside a bundled portable-R runtime directory
#'
#' The portable-r distribution extracts to a subdirectory named
#' `portable-r-<version>-<os>-<arch>/`. Rscript lives at
#' `<subdir>/bin/Rscript[.exe]`. Searches for that layout first, then falls
#' back to a flat layout in case a future portable build drops the subdir.
#'
#' @param runtime_dir Character path to `runtime/R` inside the Electron app.
#' @return Character path to Rscript, or NULL if not found.
#' @keywords internal
find_bundled_rscript <- function(runtime_dir) {
  rscript_name <- if (detect_current_platform() == "win") "Rscript.exe" else "Rscript"

  # Prefer subdirectory layout (portable-r-*/bin/Rscript)
  subdirs <- list.dirs(runtime_dir, recursive = FALSE, full.names = TRUE)
  for (sub in subdirs) {
    candidate <- fs::path(sub, "bin", rscript_name)
    if (fs::file_exists(candidate)) return(candidate)
  }

  # Fallback: flat layout
  flat <- fs::path(runtime_dir, "bin", rscript_name)
  if (fs::file_exists(flat)) return(flat)

  NULL
}

#' Copy the top-level contents of one directory into another
#'
#' `fs::dir_copy(src, dst)` has different semantics across platforms and fs
#' versions: on some it creates `dst` and copies the contents of `src` into it,
#' on others it creates `dst/basename(src)/...`. This helper forces the
#' "copy contents into target" semantics by creating a fresh, empty `dst` and
#' then copying each top-level entry from `src` into it with base R.
#'
#' @param src Character path to the source directory.
#' @param dst Character path to the destination directory. Created if absent;
#'   wiped if present.
#' @return Invisible `dst`.
#' @keywords internal
copy_dir_contents <- function(src, dst) {
  if (fs::dir_exists(dst)) unlink(dst, recursive = TRUE)
  fs::dir_create(dst, recurse = TRUE)

  entries <- list.files(src, all.files = TRUE, no.. = TRUE, full.names = TRUE)
  if (length(entries) == 0) return(invisible(dst))

  ok <- file.copy(entries, dst, recursive = TRUE, overwrite = TRUE, copy.date = TRUE)
  if (!all(ok)) {
    failed <- entries[!ok]
    cli::cli_abort(c(
      "Failed to copy directory contents",
      "i" = "From: {.path {src}}",
      "i" = "To:   {.path {dst}}",
      "x" = "Could not copy: {paste(basename(failed), collapse = ', ')}"
    ))
  }
  invisible(dst)
}

#' Find the Python command
#'
#' Searches for python3 first (Unix) or python first (Windows) on the
#' system PATH and verifies it actually runs (Windows Store aliases
#' exist but fail).
#'
#' @return Character string or NULL. The Python command name, or NULL if not found.
#' @keywords internal
find_python_command <- function() {
  candidates <- if (.Platform$OS.type == "windows") {
    c("python", "python3")
  } else {
    c("python3", "python")
  }

  for (cmd in candidates) {
    path <- Sys.which(cmd)
    if (nzchar(path)) {
      check <- run_command_safe(cmd, "--version", timeout = 5)
      if (check$status == 0) return(cmd)
    }
  }
  NULL
}

#' Validate a command is available and executable
#'
#' Shared pattern: resolve a command, abort if not found, run it with a
#' version flag, abort if execution fails. Returns the resolved command.
#'
#' @param command_resolver Function returning the command path or NULL.
#' @param not_found Character vector passed to cli::cli_abort when the
#'   command is not found. Use "i" = "..." entries for install hints.
#' @param label Character string used in the generic "found but failed"
#'   message. Defaults to "Command".
#' @param version_arg Character. Argument used to check the command
#'   runs. Defaults to "--version".
#' @return Invisibly returns the resolved command path.
#' @keywords internal
validate_command_available <- function(command_resolver, not_found,
                                       label = "Command",
                                       version_arg = "--version") {
  cmd <- command_resolver()
  if (is.null(cmd) || !nzchar(cmd)) {
    cli::cli_abort(not_found)
  }

  result <- run_command_safe(cmd, version_arg, timeout = 10)
  if (result$status != 0) {
    cli::cli_abort(c(
      "{label} was found but failed to run",
      "x" = "Path: {.path {cmd}}",
      "x" = "Error: {trimws(result$stderr %||% '')}"
    ))
  }

  invisible(cmd)
}
