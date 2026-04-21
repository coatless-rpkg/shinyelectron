#' Build Tools Situation Report
#'
#' Checks platform-specific build tools required for creating Electron distributables.
#'
#' @param verbose Logical. Whether to print detailed output. Default is TRUE.
#'
#' @return Invisibly returns a list with build tools information.
#'
#' @examples
#' \dontrun{
#' # Check build tools
#' sitrep_electron_build_tools()
#' }
#'
#' @export
sitrep_electron_build_tools <- function(verbose = TRUE) {
  if (verbose) {
    cli::cli_h1("Build Tools Report")
  }

  platform <- detect_current_platform()

  results <- list(
    platform = platform,
    tools = list(),
    issues = character(0),
    recommendations = character(0)
  )

  if (verbose) {
    cli::cli_alert_info("Checking build tools for platform: {platform}")
  }

  if (platform == "win") {
    # Check for Visual Studio Build Tools or similar
    vs_paths <- c(
      "C:/Program Files (x86)/Microsoft Visual Studio/2019/BuildTools",
      "C:/Program Files (x86)/Microsoft Visual Studio/2022/BuildTools",
      "C:/Program Files/Microsoft Visual Studio/2019/Community",
      "C:/Program Files/Microsoft Visual Studio/2022/Community"
    )

    vs_found <- any(sapply(vs_paths, dir.exists))
    results$tools$visual_studio <- vs_found

    if (vs_found) {
      if (verbose) {
        cli::cli_alert_success("Visual Studio Build Tools: Found")
      }
    } else {
      results$issues <- c(results$issues, "Visual Studio Build Tools not found")
      results$recommendations <- c(results$recommendations,
                                   "Install Visual Studio Build Tools from https://visualstudio.microsoft.com/downloads/")
      if (verbose) {
        cli::cli_alert_warning("Visual Studio Build Tools: Not found")
      }
    }

    # Check for Python (needed for node-gyp)
    python_result <- run_command_safe("python", "--version")

    results$tools$python <- python_result$status == 0

    if (python_result$status == 0) {
      if (verbose) {
        cli::cli_alert_success("Python: Found")
      }
    } else {
      results$recommendations <- c(results$recommendations,
                                   "Consider installing Python for full build tool support")
      if (verbose) {
        cli::cli_alert_info("Python: Not found (may be needed for some builds)")
      }
    }

  } else if (platform == "mac") {
    # Check for Xcode Command Line Tools
    xcode_result <- run_command_safe("xcode-select", "-p")

    results$tools$xcode <- xcode_result$status == 0

    if (xcode_result$status == 0) {
      if (verbose) {
        cli::cli_alert_success("Xcode Command Line Tools: Found")
      }
    } else {
      results$issues <- c(results$issues, "Xcode Command Line Tools not found")
      results$recommendations <- c(results$recommendations,
                                   "Install Xcode Command Line Tools with: xcode-select --install")
      if (verbose) {
        cli::cli_alert_warning("Xcode Command Line Tools: Not found")
      }
    }

  } else if (platform == "linux") {
    # Check for build-essential
    gcc_result <- run_command_safe("gcc", "--version")

    make_result <- run_command_safe("make", "--version")

    results$tools$gcc <- gcc_result$status == 0
    results$tools$make <- make_result$status == 0

    if (gcc_result$status == 0 && make_result$status == 0) {
      if (verbose) {
        cli::cli_alert_success("Build tools (gcc, make): Found")
      }
    } else {
      results$issues <- c(results$issues, "Build tools not found")
      results$recommendations <- c(results$recommendations,
                                   "Install build tools with: sudo apt-get install build-essential (Ubuntu/Debian)")
      if (verbose) {
        cli::cli_alert_warning("Build tools: Incomplete")
      }
    }
  }

  # Summary
  if (verbose) {
    if (length(results$issues) == 0) {
      cli::cli_alert_success("Build tools ready")
    } else {
      cli::cli_alert_warning("Found {length(results$issues)} build tool issue{?s}")

      if (length(results$recommendations) > 0) {
        cli::cli_h2("Recommendations")
        for (rec in results$recommendations) {
          cli::cli_alert_info("{rec}")
        }
      }
    }
  }

  invisible(results)
}

