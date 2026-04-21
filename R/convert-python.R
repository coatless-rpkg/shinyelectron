#' Convert Python Shiny Application to Shinylive
#'
#' Converts a Python Shiny application directory into a shinylive application
#' that can run entirely in the browser using Pyodide.
#'
#' @param appdir Character string. Path to the directory containing the Python Shiny application.
#' @param output_dir Character string. Path where the converted shinylive app will be saved.
#' @param overwrite Logical. Whether to overwrite existing output directory. Default is FALSE.
#' @param verbose Logical. Whether to display detailed progress information. Default is TRUE.
#'
#' @return Character string. Path to the converted shinylive application directory.
#'
#' @section Details:
#' This function converts a Python Shiny application to shinylive format using the
#' Python \code{shinylive} package. The application will run entirely in the browser
#' using Pyodide (Python compiled to WebAssembly).
#'
#' \strong{Requirements:}
#' \itemize{
#'   \item Python 3 must be available on the build machine
#'   \item The Python \code{shinylive} package must be installed (\code{pip install shinylive})
#'   \item The app directory must contain an \code{app.py} file
#' }
#'
#' @examples
#' \dontrun{
#' convert_py_to_shinylive(
#'   appdir = "path/to/python/shiny/app",
#'   output_dir = "path/to/shinylive/output"
#' )
#' }
#'
#' @export
convert_py_to_shinylive <- function(appdir, output_dir, overwrite = FALSE, verbose = TRUE) {
  validate_directory_exists(appdir, "Application directory")
  validate_python_app_structure(appdir)

  if (verbose) {
    cli::cli_h1("Converting Python Shiny app to shinylive")
    cli::cli_alert_info("Source: {.path {appdir}}")
    cli::cli_alert_info("Output: {.path {output_dir}}")
  }

  if (fs::dir_exists(output_dir)) {
    if (!overwrite) {
      cli::cli_abort(c(
        "Output directory already exists: {.path {output_dir}}",
        "i" = "Use {.code overwrite = TRUE} to overwrite existing directory"
      ))
    } else {
      if (verbose) cli::cli_alert_warning("Overwriting existing directory: {.path {output_dir}}")
      unlink(output_dir, recursive = TRUE)
    }
  }

  validate_python_available()
  validate_python_shinylive_installed()

  fs::dir_create(output_dir, recurse = TRUE)

  # Prefer the CLI command, fall back to python -m
  shinylive_cmd <- Sys.which("shinylive")
  if (nzchar(shinylive_cmd)) {
    cmd <- "shinylive"
    cmd_args <- c("export", appdir, output_dir)
  } else {
    python_cmd <- find_python_command()
    cmd <- python_cmd
    cmd_args <- c("-m", "shinylive", "export", appdir, output_dir)
  }

  if (verbose) {
    pb <- cli::cli_progress_bar("Converting to shinylive (Python)", total = 3)
  }

  tryCatch({
    if (verbose) cli::cli_progress_update(id = pb, set = 1)

    result <- processx::run(
      cmd,
      cmd_args,
      echo = verbose,
      spinner = verbose,
      error_on_status = FALSE,
      timeout = 600
    )

    if (result$status != 0) {
      cli::cli_abort(c(
        "Python shinylive export failed",
        "x" = "Command: {.code {cmd} {paste(cmd_args, collapse = ' ')}}",
        "x" = "Exit code: {result$status}",
        "x" = "Error: {result$stderr}"
      ))
    }

    if (verbose) cli::cli_progress_update(id = pb, set = 2)
    validate_shinylive_output(output_dir)

    if (verbose) cli::cli_progress_update(id = pb, set = 3)

    if (verbose) {
      cli::cli_progress_done(id = pb)
      cli::cli_alert_success("Successfully converted to shinylive: {.path {output_dir}}")
    }

    return(fs::path_abs(output_dir))

  }, error = function(e) {
    cli::cli_abort(c(
      "Failed to convert Python Shiny app to shinylive",
      "x" = "Error: {e$message}"
    ))
  })
}
