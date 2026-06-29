#' Convert Shiny Application to Shinylive
#'
#' Converts a regular Shiny application directory into a shinylive application
#' that can run entirely in the browser without requiring an R server.
#'
#' @param appdir Character string. Path to the directory containing the Shiny application.
#' @param output_dir Character string. Path where the converted shinylive app will be saved.
#' @param subdir Character or NULL. When set, the app is exported into a \code{<subdir>}
#'   subdirectory of \code{output_dir} as an additive shared-site export: existing contents
#'   of \code{output_dir} (including a shared \code{shinylive/} asset tree) are preserved.
#'   When NULL (default), a single-app export is performed and an existing \code{output_dir}
#'   is removed when \code{overwrite = TRUE}.
#' @param overwrite Logical. Whether to overwrite existing output directory. Default is FALSE.
#' @param verbose Logical. Whether to display detailed progress information. Default is TRUE.
#'
#' @return Character string. Path to the converted shinylive application directory.
#'
#' @section Details:
#' This function converts a Shiny application to shinylive format, which allows
#' the application to run entirely in the browser using WebR. The conversion process:
#' \itemize{
#'   \item Validates the input Shiny application structure
#'   \item Converts R code to be compatible with WebR
#'   \item Creates necessary shinylive configuration files
#'   \item Packages the application for browser execution
#' }
#'
#' @examples
#' \dontrun{
#' # Convert a Shiny app to shinylive
#' convert_shiny_to_shinylive(
#'   appdir = "path/to/shiny/app",
#'   output_dir = "path/to/shinylive/output"
#' )
#' }
#'
#' @export
convert_shiny_to_shinylive <- function(appdir, output_dir, subdir = NULL, overwrite = FALSE, verbose = TRUE) {
  validate_directory_exists(appdir, "Application directory")
  validate_shiny_app_structure(appdir)

  if (verbose) {
    cli::cli_h1("Converting Shiny app to shinylive")
    cli::cli_alert_info("Source: {.path {appdir}}")
    cli::cli_alert_info("Output: {.path {output_dir}}")
  }

  # Single-app: enforce/clear the output dir. Shared-site (subdir) exports are
  # additive -- multiple apps write into one output_dir under distinct subdirs
  # and share one shinylive/ asset tree, so we must NOT wipe existing contents.
  if (is.null(subdir) && fs::dir_exists(output_dir)) {
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

  fs::dir_create(output_dir, recurse = TRUE)

  if (!requireNamespace("shinylive", quietly = TRUE)) {
    cli::cli_abort(c(
      "The {.pkg shinylive} package is required for conversion",
      "i" = "Install with: {.code install.packages('shinylive')}"
    ))
  }

  if (verbose) {
    pb <- cli::cli_progress_bar("Converting to shinylive", total = 4)
  }

  tryCatch({
    if (verbose) cli::cli_progress_update(id = pb, set = 1)
    temp_app_dir <- tempfile("shinyelectron-app-")
    on.exit(unlink(temp_app_dir, recursive = TRUE), add = TRUE)
    copy_dir_contents(appdir, temp_app_dir)

    if (verbose) cli::cli_progress_update(id = pb, set = 2)
    shinylive::export(appdir = temp_app_dir, destdir = output_dir,
                      subdir = subdir %||% "", quiet = TRUE)

    if (verbose) cli::cli_progress_update(id = pb, set = 3)

    if (verbose) cli::cli_progress_update(id = pb, set = 4)
    validate_shinylive_output(output_dir, subdir = subdir)

    if (verbose) {
      cli::cli_progress_done(id = pb)
      cli::cli_alert_success("Successfully converted to shinylive: {.path {output_dir}}")
    }

    return(fs::path_abs(output_dir))

  }, error = function(e) {
    cli::cli_abort(c(
      "Failed to convert Shiny app to shinylive",
      "x" = "Error: {e$message}"
    ))
  })
}
