#' Dependencies Situation Report
#'
#' Checks R package dependencies required for shinyelectron functionality.
#'
#' @param verbose Logical. Whether to print detailed output. Default is TRUE.
#'
#' @return Invisibly returns a list with dependency information.
#'
#' @examples
#' \dontrun{
#' # Check package dependencies
#' sitrep_electron_dependencies()
#' }
#'
#' @export
sitrep_electron_dependencies <- function(verbose = TRUE) {
  if (verbose) {
    cli::cli_h1("Dependencies Report")
  }

  # Required packages
  required_packages <- c("cli", "fs", "jsonlite", "processx", "whisker", "utils", "tools")

  # Optional but recommended packages
  optional_packages <- c("shinylive", "DT", "ggplot2")

  results <- list(
    required = list(),
    optional = list(),
    missing_required = character(0),
    missing_optional = character(0),
    issues = character(0),
    recommendations = character(0)
  )

  # Check required packages
  if (verbose) {
    cli::cli_h2("Required Packages")
  }

  for (pkg in required_packages) {
    if (requireNamespace(pkg, quietly = TRUE)) {
      pkg_version <- tryCatch({
        as.character(utils::packageVersion(pkg))
      }, error = function(e) "unknown")

      results$required[[pkg]] <- list(installed = TRUE, version = pkg_version)

      if (verbose) {
        cli::cli_alert_success("{pkg}: v{pkg_version}")
      }
    } else {
      results$required[[pkg]] <- list(installed = FALSE, version = NULL)
      results$missing_required <- c(results$missing_required, pkg)

      if (verbose) {
        cli::cli_alert_danger("{pkg}: Not installed")
      }
    }
  }

  # Check optional packages
  if (verbose) {
    cli::cli_h2("Optional Packages")
  }

  for (pkg in optional_packages) {
    if (requireNamespace(pkg, quietly = TRUE)) {
      pkg_version <- tryCatch({
        as.character(utils::packageVersion(pkg))
      }, error = function(e) "unknown")

      results$optional[[pkg]] <- list(installed = TRUE, version = pkg_version)

      if (verbose) {
        cli::cli_alert_success("{pkg}: v{pkg_version}")
      }
    } else {
      results$optional[[pkg]] <- list(installed = FALSE, version = NULL)
      results$missing_optional <- c(results$missing_optional, pkg)

      if (verbose) {
        cli::cli_alert_info("{pkg}: Not installed (optional)")
      }
    }
  }

  # Generate recommendations
  if (length(results$missing_required) > 0) {
    results$issues <- c(results$issues, "Missing required packages")
    install_cmd <- paste0('install.packages(c("', paste(results$missing_required, collapse = '", "'), '"))')
    results$recommendations <- c(results$recommendations, paste("Install missing packages with:", install_cmd))
  }

  if (length(results$missing_optional) > 0) {
    install_cmd <- paste0('install.packages(c("', paste(results$missing_optional, collapse = '", "'), '"))')
    results$recommendations <- c(results$recommendations,
                                 paste("For full functionality, install optional packages with:", install_cmd))
  }

  # Summary
  if (verbose) {
    if (length(results$missing_required) == 0) {
      cli::cli_alert_success("All required dependencies satisfied")
    } else {
      cli::cli_alert_warning("Missing {length(results$missing_required)} required package{?s}")
    }

    if (length(results$recommendations) > 0) {
      cli::cli_h2("Recommendations")
      for (rec in results$recommendations) {
        cli::cli_alert_info("{rec}")
      }
    }
  }

  invisible(results)
}

