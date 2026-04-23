#' Inspect an app directory for Shiny entrypoints
#'
#' Returns a named list of logical flags for each entrypoint file.
#' Used by the detector and by structure validators to avoid duplicating
#' `fs::file_exists` calls.
#'
#' @param appdir Character path to the candidate app directory.
#' @return Named list with elements `app_py`, `app_r`, `server_r`, `ui_r`.
#' @keywords internal
app_entrypoints <- function(appdir) {
  list(
    app_py   = fs::file_exists(fs::path(appdir, "app.py")),
    app_r    = fs::file_exists(fs::path(appdir, "app.R")),
    server_r = fs::file_exists(fs::path(appdir, "server.R")),
    ui_r     = fs::file_exists(fs::path(appdir, "ui.R"))
  )
}

#' Autodetect the app type from a directory
#'
#' Scans `appdir` for Shiny entrypoints and returns the implied language.
#' R apps may use `app.R` or the pair `server.R` plus `ui.R`. Python apps
#' use `app.py`. A directory that carries both R and Python entrypoints
#' is rejected; the multi-app-suite path is the right place to combine them.
#'
#' @param appdir Character path to the candidate app directory. Must exist.
#' @return Character, either `"r-shiny"` or `"py-shiny"`.
#' @keywords internal
detect_app_type <- function(appdir) {
  if (!fs::dir_exists(appdir)) {
    cli::cli_abort("App directory does not exist: {.path {appdir}}")
  }

  found <- app_entrypoints(appdir)
  r_file <- if (found$app_r) "app.R" else if (found$server_r && found$ui_r) "server.R"
  has_r <- found$app_r || (found$server_r && found$ui_r)
  has_py <- found$app_py

  if (has_py && has_r) {
    cli::cli_abort(c(
      "Ambiguous app type in {.path {appdir}}: found both {.file app.py} and {.file {r_file}}",
      "i" = "One directory cannot be both an R and Python Shiny app.",
      "i" = "To package several apps in one shell, see {.code vignette(\"multi-app-suites\", package = \"shinyelectron\")}"
    ))
  }

  if (has_py) {
    return("py-shiny")
  }

  if (has_r) {
    return("r-shiny")
  }

  if (found$server_r || found$ui_r) {
    cli::cli_abort(c(
      "Incomplete R Shiny app in {.path {appdir}}",
      "i" = "Expected both {.file server.R} and {.file ui.R}, or a single {.file app.R}",
      "x" = "Found only {.file {if (found$server_r) 'server.R' else 'ui.R'}}"
    ))
  }

  cli::cli_abort(c(
    "Could not autodetect app type from {.path {appdir}}",
    "i" = "Expected one of: {.file app.py}, {.file app.R}, or {.file server.R} plus {.file ui.R}",
    "i" = "Pass {.arg app_type} explicitly if your layout is non-standard"
  ))
}
