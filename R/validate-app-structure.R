#' Validate Shiny application structure
#'
#' @param appdir Character path to Shiny app directory
#' @keywords internal
validate_shiny_app_structure <- function(appdir) {
  app_r <- fs::path(appdir, "app.R")
  server_r <- fs::path(appdir, "server.R")
  ui_r <- fs::path(appdir, "ui.R")

  has_app_r <- fs::file_exists(app_r)
  has_server_ui <- fs::file_exists(server_r) && fs::file_exists(ui_r)

  if (!has_app_r && !has_server_ui) {
    cli::cli_abort(c(
      "Invalid Shiny application structure in: {.path {appdir}}",
      "i" = "Expected either app.R or both server.R and ui.R"
    ))
  }
}

#' Validate Python app structure
#'
#' @param appdir Character string. Path to the app directory.
#' @keywords internal
validate_python_app_structure <- function(appdir) {
  app_py <- fs::path(appdir, "app.py")
  if (!fs::file_exists(app_py)) {
    cli::cli_abort(c(
      "No {.file app.py} found in {.path {appdir}}",
      "i" = "Python Shiny apps must contain an {.file app.py} file"
    ))
  }
  invisible(TRUE)
}

#' Validate shinylive output
#'
#' @param output_dir Character path to shinylive output
#' @keywords internal
validate_shinylive_output <- function(output_dir) {
  index_html <- fs::path(output_dir, "index.html")
  if (!fs::file_exists(index_html)) {
    cli::cli_abort("Shinylive conversion failed: no index.html found in {.path {output_dir}}")
  }

  shinylive_dir <- fs::path(output_dir, "shinylive")
  if (!fs::dir_exists(shinylive_dir)) {
    cli::cli_abort("Shinylive conversion failed: no shinylive directory found in {.path {output_dir}}")
  }
}
