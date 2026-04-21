#' Complete Situation Report
#'
#' Runs all diagnostic checks and provides a comprehensive report of your
#' shinyelectron setup.
#'
#' @param project_dir Character. Path to the project directory to check. Default is current directory.
#' @param verbose Logical. Whether to print detailed output. Default is TRUE.
#'
#' @return Invisibly returns a list with all diagnostic information.
#'
#' @examples
#' \dontrun{
#' # Complete diagnostic check
#' sitrep_shinyelectron()
#'
#' # Check specific project
#' sitrep_shinyelectron("path/to/project")
#'
#' # Get results without printing
#' results <- sitrep_shinyelectron(verbose = FALSE)
#' }
#'
#' @export
sitrep_shinyelectron <- function(project_dir = ".", verbose = TRUE) {
  if (verbose) {
    cli::cli_h1("Complete shinyelectron Diagnostic Report")
    cli::cli_rule()
  }

  results <- list()

  # Run all diagnostic checks
  results$system <- sitrep_electron_system(verbose = verbose)

  if (verbose) cli::cli_rule()
  results$dependencies <- sitrep_electron_dependencies(verbose = verbose)

  if (verbose) cli::cli_rule()
  results$build_tools <- sitrep_electron_build_tools(verbose = verbose)

  if (verbose) cli::cli_rule()
  results$project <- sitrep_electron_project(project_dir = project_dir, verbose = verbose)

  # Overall summary
  if (verbose) {
    cli::cli_rule()
    cli::cli_h1("Overall Summary")

    total_issues <- length(results$system$issues) +
      length(results$dependencies$issues) +
      length(results$build_tools$issues) +
      length(results$project$issues)

    if (total_issues == 0) {
      cli::cli_alert_success("All systems ready! You should be able to build Electron apps successfully")
    } else {
      cli::cli_alert_warning("Found {total_issues} total issue{?s} that may prevent successful builds")

      # Collect all recommendations
      all_recommendations <- c(
        results$system$recommendations,
        results$dependencies$recommendations,
        results$build_tools$recommendations,
        results$project$recommendations
      )

      if (length(all_recommendations) > 0) {
        cli::cli_h2("Priority Actions")
        for (i in seq_along(all_recommendations)) {
          cli::cli_alert_info("{i}. {all_recommendations[i]}")
        }
      }
    }
  }

  invisible(results)
}
