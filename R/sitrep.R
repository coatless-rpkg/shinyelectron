#' Diagnostic Functions for shinyelectron
#'
#' @name sitrep
#' @description
#' These functions provide diagnostic information about your system setup
#' and help troubleshoot common issues with shinyelectron.
#' @keywords internal
NULL

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
