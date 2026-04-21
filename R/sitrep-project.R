#' Project Situation Report
#'
#' Checks if the current directory contains a valid Electron project and
#' diagnoses common project-related issues.
#'
#' @param project_dir Character. Path to the project directory. Default is current directory.
#' @param verbose Logical. Whether to print detailed output. Default is TRUE.
#'
#' @return Invisibly returns a list with project diagnostic information.
#'
#' @examples
#' \dontrun{
#' # Check current directory
#' sitrep_electron_project()
#'
#' # Check specific directory
#' sitrep_electron_project("path/to/electron/project")
#' }
#'
#' @export
sitrep_electron_project <- function(project_dir = ".", verbose = TRUE) {
  if (verbose) {
    cli::cli_h1("Project Report")
    cli::cli_alert_info("Checking directory: {.path {fs::path_abs(project_dir)}}")
  }

  results <- list(
    project_dir = fs::path_abs(project_dir),
    is_electron_project = FALSE,
    package_json = list(exists = FALSE, valid = FALSE),
    main_js = list(exists = FALSE),
    app_files = list(exists = FALSE, type = NULL),
    node_modules = list(exists = FALSE),
    build_scripts = list(valid = FALSE, missing = character(0)),
    issues = character(0),
    recommendations = character(0)
  )

  # Check if directory exists
  if (!fs::dir_exists(project_dir)) {
    results$issues <- c(results$issues, "Project directory does not exist")
    if (verbose) {
      cli::cli_alert_danger("Directory does not exist: {.path {project_dir}}")
    }
    return(invisible(results))
  }

  # Check for package.json
  package_json_path <- fs::path(project_dir, "package.json")
  results$package_json$exists <- fs::file_exists(package_json_path)

  if (results$package_json$exists) {
    tryCatch({
      package_json <- jsonlite::fromJSON(package_json_path, simplifyVector = FALSE)
      results$package_json$valid <- TRUE
      results$package_json$content <- package_json

      if (verbose) {
        cli::cli_alert_success("package.json: Found")
        if (!is.null(package_json$name)) {
          cli::cli_alert_info("Project name: {package_json$name}")
        }
      }

      # Check build scripts
      required_scripts <- c("electron", "build-mac-arm64", "build-win-x64", "build-linux-x64")
      available_scripts <- names(package_json$scripts %||% list())
      missing_scripts <- setdiff(required_scripts, available_scripts)

      results$build_scripts$missing <- missing_scripts
      results$build_scripts$valid <- length(missing_scripts) == 0

      if (length(missing_scripts) == 0) {
        if (verbose) {
          cli::cli_alert_success("Build scripts: Complete")
        }
      } else {
        results$issues <- c(results$issues, "Missing build scripts")
        results$recommendations <- c(results$recommendations,
                                     "Run fix_build_scripts() to add missing build scripts")
        if (verbose) {
          cli::cli_alert_warning("Build scripts: Missing {length(missing_scripts)} script{?s}")
        }
      }

    }, error = function(e) {
      results$issues <- c(results$issues, "Invalid package.json")
      if (verbose) {
        cli::cli_alert_danger("package.json: Invalid JSON")
      }
    })
  } else {
    results$issues <- c(results$issues, "No package.json found")
    if (verbose) {
      cli::cli_alert_danger("package.json: Not found")
    }
  }

  # Check for main.js
  main_js_path <- fs::path(project_dir, "main.js")
  results$main_js$exists <- fs::file_exists(main_js_path)

  if (results$main_js$exists) {
    if (verbose) {
      cli::cli_alert_success("main.js: Found")
    }
  } else {
    results$issues <- c(results$issues, "No main.js found")
    if (verbose) {
      cli::cli_alert_warning("main.js: Not found")
    }
  }

  # Check for app files
  app_paths <- c(
    fs::path(project_dir, "src", "app"),
    fs::path(project_dir, "app")
  )

  app_dir <- NULL
  for (path in app_paths) {
    if (fs::dir_exists(path)) {
      app_dir <- path
      break
    }
  }

  if (!is.null(app_dir)) {
    results$app_files$exists <- TRUE

    # Determine app type
    if (fs::file_exists(fs::path(app_dir, "index.html"))) {
      results$app_files$type <- "shinylive"
      if (verbose) {
        cli::cli_alert_success("App files: Shinylive app found")
      }
    } else if (fs::file_exists(fs::path(app_dir, "app.R"))) {
      results$app_files$type <- "shiny"
      if (verbose) {
        cli::cli_alert_success("App files: Shiny app.R found")
      }
    } else if (fs::file_exists(fs::path(app_dir, "server.R")) && fs::file_exists(fs::path(app_dir, "ui.R"))) {
      results$app_files$type <- "shiny"
      if (verbose) {
        cli::cli_alert_success("App files: Shiny server.R/ui.R found")
      }
    } else {
      results$app_files$type <- "unknown"
      if (verbose) {
        cli::cli_alert_warning("App files: Found but type unknown")
      }
    }
  } else {
    results$issues <- c(results$issues, "No app files found")
    if (verbose) {
      cli::cli_alert_danger("App files: Not found in src/app or app/")
    }
  }

  # Check for node_modules
  node_modules_path <- fs::path(project_dir, "node_modules")
  results$node_modules$exists <- fs::dir_exists(node_modules_path)

  if (results$node_modules$exists) {
    if (verbose) {
      cli::cli_alert_success("node_modules: Found")
    }
  } else {
    results$recommendations <- c(results$recommendations, "Run 'npm install' to install dependencies")
    if (verbose) {
      cli::cli_alert_info("node_modules: Not found (run 'npm install')")
    }
  }

  # Determine if this is an Electron project
  results$is_electron_project <- results$package_json$exists && results$main_js$exists

  # Summary
  if (verbose) {
    if (results$is_electron_project) {
      cli::cli_alert_success("This appears to be an Electron project")
    } else {
      cli::cli_alert_info("This does not appear to be an Electron project")
    }

    if (length(results$issues) > 0) {
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

