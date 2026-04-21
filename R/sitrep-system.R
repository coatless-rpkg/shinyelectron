#' System Requirements Situation Report
#'
#' Checks system requirements for shinyelectron including Node.js, npm,
#' operating system, and architecture.
#'
#' @param verbose Logical. Whether to print detailed output. Default is TRUE.
#'
#' @return Invisibly returns a list with diagnostic information.
#'
#' @examples
#' \dontrun{
#' # Check system requirements
#' sitrep_electron_system()
#'
#' # Get diagnostic info without printing
#' info <- sitrep_electron_system(verbose = FALSE)
#' }
#'
#' @export
sitrep_electron_system <- function(verbose = TRUE) {
  if (verbose) {
    cli::cli_h1("System Requirements Report")
  }

  # Initialize results
  results <- list(
    platform = NULL,
    arch = NULL,
    node = list(installed = FALSE, version = NULL, source = NULL),
    npm = list(installed = FALSE, version = NULL),
    nodejs_local = list(installed = FALSE, versions = character(0), path = NULL),
    r_version = paste(R.version$major, R.version$minor, sep = "."),
    issues = character(0),
    recommendations = character(0)
  )

  # Check platform and architecture
  tryCatch({
    results$platform <- detect_current_platform()
    results$arch <- detect_current_arch()

    if (verbose) {
      cli::cli_alert_success("Platform: {results$platform}")
      cli::cli_alert_success("Architecture: {results$arch}")
    }
  }, error = function(e) {
    results$issues <- c(results$issues, "Could not detect platform/architecture")
    if (verbose) {
      cli::cli_alert_danger("Could not detect platform/architecture")
    }
  })

  # Check for local Node.js installation (shinyelectron-managed)
  local_versions <- nodejs_list_installed()
  if (length(local_versions) > 0) {
    results$nodejs_local$installed <- TRUE
    results$nodejs_local$versions <- local_versions
    results$nodejs_local$path <- nodejs_install_path(local_versions[1])

    if (verbose) {
      cli::cli_alert_success("Local Node.js (shinyelectron): v{local_versions[1]}")
      if (length(local_versions) > 1) {
        cli::cli_alert_info("  Other versions: {paste(local_versions[-1], collapse = ', ')}")
      }
    }
  } else {
    if (verbose) {
      cli::cli_alert_info("Local Node.js (shinyelectron): Not installed")
      cli::cli_alert_info("  Install with: {.code shinyelectron::install_nodejs()}")
    }
  }

  # Check Node.js (prefer local, fall back to system)
  node_cmd <- get_node_command(prefer_local = TRUE)
  node_result <- run_command_safe(node_cmd, "--version")

  if (node_result$status == 0) {
    results$node$installed <- TRUE
    results$node$version <- trimws(gsub("^v", "", node_result$stdout))
    results$node$source <- if (results$nodejs_local$installed) "local" else "system"

    # Check if version is acceptable (>= 14.0.0)
    node_version_num <- numeric_version(results$node$version)
    if (node_version_num >= "14.0.0") {
      source_label <- if (results$node$source == "local") "(local)" else "(system)"
      if (verbose) {
        cli::cli_alert_success("Active Node.js: v{results$node$version} {source_label}")
      }
    } else {
      results$issues <- c(results$issues, "Node.js version too old")
      results$recommendations <- c(results$recommendations, "Update Node.js to version 14.0.0 or higher")
      if (verbose) {
        cli::cli_alert_warning("Node.js: v{results$node$version} (version 14+ required)")
      }
    }
  } else {
    results$issues <- c(results$issues, "Node.js not found")
    results$recommendations <- c(results$recommendations,
      "Install with: shinyelectron::install_nodejs() or from https://nodejs.org/")
    if (verbose) {
      cli::cli_alert_danger("Node.js: Not found")
    }
  }

  # Check npm
  npm_result <- run_command_safe(get_npm_command(), "--version")

  if (npm_result$status == 0) {
    results$npm$installed <- TRUE
    results$npm$version <- trimws(npm_result$stdout)

    # Check if version is acceptable (>= 6.0.0)
    npm_version_num <- numeric_version(results$npm$version)
    if (npm_version_num >= "6.0.0") {
      if (verbose) {
        cli::cli_alert_success("npm: v{results$npm$version}")
      }
    } else {
      results$issues <- c(results$issues, "npm version too old")
      results$recommendations <- c(results$recommendations, "Update npm with: npm install -g npm@latest")
      if (verbose) {
        cli::cli_alert_warning("npm: v{results$npm$version} (version 6+ required)")
      }
    }
  } else {
    results$issues <- c(results$issues, "npm not found")
    results$recommendations <- c(results$recommendations, "npm should be installed with Node.js")
    if (verbose) {
      cli::cli_alert_danger("npm: Not found")
    }
  }

  # Check R version
  r_version_num <- numeric_version(results$r_version)
  if (r_version_num >= "4.0.0") {
    if (verbose) {
      cli::cli_alert_success("R: v{results$r_version}")
    }
  } else {
    results$issues <- c(results$issues, "R version too old")
    results$recommendations <- c(results$recommendations, "Update R to version 4.0.0 or higher")
    if (verbose) {
      cli::cli_alert_warning("R: v{results$r_version} (version 4.0+ recommended)")
    }
  }

  # Python availability
  if (verbose) cli::cli_h2("Python")

  python_cmd <- find_python_command()
  if (!is.null(python_cmd)) {
    py_result <- run_command_safe(python_cmd, c("--version"), timeout = 10)
    if (py_result$status == 0) {
      py_version <- trimws(paste0(py_result$stdout, py_result$stderr))
      if (verbose) cli::cli_alert_success("{py_version}")
      results$python_version <- py_version

      # Check Python packages needed for py-shinylive and py-shiny
      check_py_pkg <- function(label, validator_fn, install_cmd) {
        chk <- tryCatch(
          list(ok = TRUE, version = validator_fn()),
          error = function(e) list(ok = FALSE)
        )
        if (isTRUE(chk$ok)) {
          if (verbose) cli::cli_alert_success("Python {label}: {chk$version} (ready)")
        } else {
          if (verbose) {
            cli::cli_alert_info("Python {label}: not usable")
            cli::cli_alert_info("  Install with: {.code {install_cmd}}")
          }
        }
        chk$version  # NULL when !ok
      }

      results$python_shinylive_version <- check_py_pkg(
        "shinylive", validate_python_shinylive_installed, "pip install shinylive"
      )
      results$python_shiny_version <- check_py_pkg(
        "shiny", validate_python_shiny_installed, "pip install shiny"
      )
    } else {
      if (verbose) cli::cli_alert_warning("Python found but failed to run")
      results$issues <- c(results$issues, "Python found but not working")
    }
  } else {
    if (verbose) cli::cli_alert_info("Python: not found (needed for py-shinylive and py-shiny)")
    results$python_available <- FALSE
  }

  # Container engine availability
  if (verbose) cli::cli_h2("Container Engine")

  container_engine <- detect_container_engine()
  if (!is.null(container_engine)) {
    if (verbose) cli::cli_alert_success("Container engine: {container_engine}")
    results$container_engine <- container_engine
  } else {
    if (verbose) cli::cli_alert_info("Docker/Podman: not found (needed for container strategy)")
    results$container_engine <- NULL
  }

  # Cached runtimes
  if (verbose) cli::cli_h2("Cached Runtimes")

  has_cached <- FALSE
  r_cache_base <- fs::path(cache_dir(create = FALSE), "r")
  if (fs::dir_exists(r_cache_base)) {
    r_dirs <- fs::dir_ls(r_cache_base, recurse = TRUE, type = "directory")
    r_version_dirs <- r_dirs[grepl("\\d+\\.\\d+\\.\\d+$", r_dirs)]
    if (length(r_version_dirs) > 0) {
      r_versions <- basename(r_version_dirs)
      if (verbose) cli::cli_alert_success("Cached R runtimes: {paste(r_versions, collapse = ', ')}")
      results$cached_r_versions <- r_versions
      has_cached <- TRUE
    }
  }

  py_cache_base <- fs::path(cache_dir(create = FALSE), "python")
  if (fs::dir_exists(py_cache_base)) {
    py_dirs <- fs::dir_ls(py_cache_base, recurse = TRUE, type = "directory")
    py_version_dirs <- py_dirs[grepl("\\d+\\.\\d+\\.\\d+$", py_dirs)]
    if (length(py_version_dirs) > 0) {
      py_versions <- basename(py_version_dirs)
      if (verbose) cli::cli_alert_success("Cached Python runtimes: {paste(py_versions, collapse = ', ')}")
      results$cached_python_versions <- py_versions
      has_cached <- TRUE
    }
  }

  if (!has_cached && verbose) {
    cli::cli_alert_info("No cached runtimes found")
  }

  # Summary
  if (verbose) {
    if (length(results$issues) == 0) {
      cli::cli_alert_success("All system requirements satisfied")
    } else {
      cli::cli_alert_warning("Found {length(results$issues)} issue{?s}")

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

