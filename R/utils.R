#' Refuse to overwrite a protected directory
#'
#' Aborts with an informative error when `dir` resolves to a well-known
#' system path (`~`, `/`, `R.home()`) or a path whose absolute form is
#' three characters or fewer (covers drive roots such as `C:\` on Windows).
#'
#' @param dir Character string. Path to check.
#' @return Invisible `TRUE` when the path is safe.
#' @keywords internal
assert_safe_to_overwrite <- function(dir) {
  abs_dir <- normalizePath(dir, mustWork = FALSE)
  protected <- c(
    normalizePath("~", mustWork = FALSE),
    normalizePath("/", mustWork = FALSE),
    normalizePath(R.home(), mustWork = FALSE)
  )
  if (abs_dir %in% protected || nchar(abs_dir) <= 3) {
    cli::cli_abort("Refusing to overwrite protected directory: {.path {dir}}")
  }
  invisible(TRUE)
}

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
         cli::cli_abort(c(
           "Unsupported platform: {.val {sysname}}",
           "i" = "shinyelectron supports Windows, macOS, and Linux",
           "i" = "Report this at {.url https://github.com/coatless-rpkg/shinyelectron/issues}"
         ))
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
  # Each maximal run of non-alphanumerics becomes a single dash, so no
  # consecutive dashes can remain afterwards.
  slug <- gsub("[^a-z0-9]+", "-", slug)
  slug <- gsub("^-|-$", "", slug)
  if (!nzchar(slug)) {
    cli::cli_abort(c(
      "Cannot create an empty slug from input: {.val {name}}",
      "i" = "Set {.field app.slug} in {.file _shinyelectron.yml} to a lowercase ASCII slug such as {.val my-app}."
    ))
  }
  slug
}

#' Slugify a name, or return NULL when nothing usable is left
#'
#' @param name The name to slugify. Anything but a single non-empty string
#'   gives `NULL`.
#' @return The [slugify()] result, or `NULL` when the name has no ASCII
#'   letters or digits.
#' @keywords internal
slug_or_null <- function(name) {
  if (!is_nonempty_string(name)) return(NULL)
  tryCatch(slugify(name), error = function(e) NULL)
}

#' Resolve the app slug
#'
#' The slug is the app's identity. It names the package in `package.json`,
#' the user data folder, the per-app caches under `~/.shinyelectron`, and the
#' installer files, and unless `installer.app_id` is set it also gives the
#' app ID, which Windows installers and macOS use to recognize an installed
#' copy. `app.slug` wins when set. Otherwise the slug comes from the app
#' name, or, when the name has no ASCII letters or digits, from the name of
#' the app directory, with a message.
#'
#' Earlier releases derived the slug from the directory name whenever no
#' `app_name` argument was given. So when the name came from `app.name`
#' (`name_from_config`) and gives a different slug than the directory, this
#' warns: the rebuilt app would no longer update installed copies.
#'
#' @param config List. The effective configuration.
#' @param app_name Character string. The resolved display name.
#' @param appdir Character string. The app directory.
#' @param name_from_config Logical. Whether `app_name` came from `app.name`.
#' @return The slug, or `NULL` when neither the name nor the directory gives
#'   one. It is not validated here; [check_app_slug()] does that before a
#'   build.
#' @keywords internal
resolve_app_slug <- function(config, app_name, appdir, name_from_config = FALSE) {
  if (!is.null(config$app$slug)) {
    return(config$app$slug)
  }
  dir_slug <- slug_or_null(basename(appdir))
  slug <- slug_or_null(app_name)
  if (is.null(slug)) {
    if (!is.null(dir_slug)) {
      cli::cli_inform(c(
        "i" = "The app name {.val {app_name}} has no ASCII letters or digits, so the app slug comes from the directory name: {.val {dir_slug}}.",
        " " = "Set {.field app.slug} in {.file _shinyelectron.yml} to choose another."
      ))
    }
    return(dir_slug)
  }
  if (isTRUE(name_from_config) && !is.null(dir_slug) && !identical(slug, dir_slug)) {
    cli::cli_warn(c(
      "The app slug is now {.val {slug}}, from {.field app.name}; earlier releases of shinyelectron used {.val {dir_slug}}, from the directory name.",
      "i" = "The slug is the app's identity: it names the user data folder and, unless {.field installer.app_id} is set, gives the app ID that Windows installers and macOS use to recognize an installed copy.",
      "i" = "To keep updating copies built with the old slug, add {.code slug: \"{dir_slug}\"} under {.field app:} in {.file _shinyelectron.yml}; to keep the new one, add {.code slug: \"{slug}\"}."
    ), class = "shinyelectron_slug_changed")
  }
  slug
}

#' Check the app slug before a build starts
#'
#' The build uses the slug only when it assembles the Electron app, after the
#' conversion and any runtime download. Checking it right after
#' [resolve_app_slug()] reports an invalid `app.slug`, or a name and
#' directory that give no slug, before that work.
#'
#' @param slug The resolved slug, or `NULL` when none could be derived.
#' @return Invisible `TRUE`; aborts otherwise.
#' @keywords internal
check_app_slug <- function(slug) {
  rule <- c(
    "i" = "Set {.field app.slug} in {.file _shinyelectron.yml} to lowercase letters, digits, and hyphens that start and end with a letter or digit, such as {.val my-app}."
  )
  if (is.null(slug)) {
    cli::cli_abort(
      c("Cannot derive an app slug from the app name or the directory name.", rule),
      class = "shinyelectron_invalid_slug"
    )
  }
  valid <- is_nonempty_string(slug) &&
    isTRUE(tryCatch(validate_slug(slug), error = function(e) FALSE))
  if (!valid) {
    cli::cli_abort(
      c(if (is_nonempty_string(slug)) "Invalid {.field app.slug}: {.val {slug}}" else "Invalid {.field app.slug}", rule),
      class = "shinyelectron_invalid_slug"
    )
  }
  invisible(TRUE)
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
#' Wraps [processx::run()] with consistent error handling. Returns a list
#' with status, stdout, and stderr. Never throws: a command that cannot be
#' started, fails, or times out is reported as a non-zero status, so a
#' diagnostic probe cannot abort the calling session.
#'
#' processx is used rather than [base::system2()] because a modified `env` is
#' honored on every platform (system2's `env` is a no-op on Windows for programs
#' like node and python), and arguments are passed as an argv array without
#' shell quoting.
#'
#' @param command Character command to run.
#' @param args Character vector of arguments.
#' @param timeout Numeric timeout in seconds. Default 30.
#' @param env Environment for the child process. `NULL` (the default) inherits
#'   the current environment; otherwise the supplied value is used, where the
#'   special `"current"` entry extends rather than replaces it. In every case
#'   `NODE_COMPILE_CACHE` is added so Node's compile cache is written to a
#'   temporary directory that is removed when the call returns.
#' @return List with status, stdout, stderr.
#' @keywords internal
run_command_safe <- function(command, args = character(), timeout = 30,
                             env = NULL) {
  tryCatch({
    # npm enables Node's V8 compile cache by default, which otherwise writes a
    # "node-compile-cache" directory into the session temp dir. Point it at a
    # directory removed when this call returns, threaded into whatever
    # environment the child receives, so a diagnostic probe leaves no detritus
    # behind (builds keep the default cache for speed).
    compile_cache <- withr::local_tempdir("node-compile-cache-")
    env <- c(if (is.null(env)) "current" else env,
             NODE_COMPILE_CACHE = compile_cache)

    processx::run(command, args, env = env,
                  error_on_status = FALSE, timeout = timeout)
  }, error = function(e) list(status = 1L, stdout = "", stderr = conditionMessage(e)))
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

#' Environment for spawning Python child processes
#'
#' R prepends its own and related library directories to `LD_LIBRARY_PATH`
#' (its lib directory plus system paths such as `/usr/lib/x86_64-linux-gnu`).
#' When a Python child inherits that, the dynamic loader can resolve a *system*
#' `libpython` ahead of the interpreter's own; the interpreter then computes a
#' different `sys.prefix` and its `site` module drops `site-packages` from
#' `sys.path`, so pip-installed packages (for example the Python `shinylive`
#' CLI) become unimportable and the process fails with `No module named ...`
#' even though the package is installed. Python resolves its own libraries via
#' rpath, so `LD_LIBRARY_PATH` is removed for Python children. A no-op on
#' platforms / installs where it is not set (Windows, macOS, most user setups).
#'
#' @return A named character vector suitable for the `env` argument of
#'   [processx::run()].
#' @keywords internal
python_subprocess_env <- function() {
  env <- Sys.getenv()
  env[!names(env) %in% "LD_LIBRARY_PATH"]
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
