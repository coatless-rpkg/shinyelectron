#' Dependency Detection and Installation
#'
#' Functions for detecting, merging, and installing R and Python package
#' dependencies for native Shiny app types.
#'
#' @name dependencies
#' @keywords internal
NULL

# Base and recommended packages that ship with R -- never need to be installed
BASE_R_PACKAGES <- c(
  "base", "compiler", "datasets", "grDevices", "graphics", "grid",
  "methods", "parallel", "splines", "stats", "stats4", "tcltk",
  "tools", "utils",
  "boot", "class", "cluster", "codetools", "foreign", "KernSmooth",
  "lattice", "MASS", "Matrix", "mgcv", "nlme", "nnet", "rpart",
  "spatial", "survival"
)

#' Detect R package dependencies from source files
#'
#' Uses \code{renv::dependencies()} to scan R source files for package
#' references. This catches \code{library()}, \code{require()},
#' \code{pkg::func()}, \code{loadNamespace()}, and other patterns.
#'
#' @param appdir Character string. Path to the app directory.
#' @return Character vector of unique package names (sorted), excluding
#'   base and recommended R packages.
#' @keywords internal
detect_r_dependencies <- function(appdir) {
  if (!requireNamespace("renv", quietly = TRUE)) {
    cli::cli_abort(c(
      "The {.pkg renv} package is required to detect R dependencies",
      "i" = "Install with: {.code install.packages('renv')}"
    ))
  }

  deps_df <- tryCatch(
    renv::dependencies(appdir, quiet = TRUE),
    error = function(e) {
      cli::cli_warn(c(
        "Failed to detect R dependencies",
        "x" = "Error: {e$message}",
        "i" = "Falling back to empty dependency list"
      ))
      data.frame(Package = character(0))
    }
  )

  packages <- unique(deps_df$Package)
  packages <- setdiff(packages, BASE_R_PACKAGES)
  sort(packages)
}

#' Detect Python package dependencies from requirements files
#'
#' Reads \code{requirements.txt} or \code{pyproject.toml} to determine
#' Python package dependencies. Does NOT parse import statements -- the
#' module-name-to-package-name mapping (e.g., \code{import cv2} maps to
#' \code{opencv-python}) makes import parsing unreliable.
#'
#' Prefers \code{requirements.txt} over \code{pyproject.toml} when both exist.
#' Warns if neither file is found.
#'
#' @param appdir Character string. Path to the app directory.
#' @return Character vector of unique package names (sorted).
#' @keywords internal
detect_py_dependencies <- function(appdir) {
  req_file <- file.path(appdir, "requirements.txt")
  pyproject_file <- file.path(appdir, "pyproject.toml")

  if (file.exists(req_file)) {
    return(parse_requirements_txt(req_file))
  }

  if (file.exists(pyproject_file)) {
    return(parse_pyproject_toml(pyproject_file))
  }

  cli::cli_warn(c(
    "No {.file requirements.txt} or {.file pyproject.toml} found in {.path {appdir}}",
    "i" = "Create a {.file requirements.txt} to declare Python dependencies",
    "i" = "Without it, no packages will be installed for the app"
  ))
  character(0)
}

#' Parse requirements.txt file
#'
#' @param path Character string. Path to requirements.txt.
#' @return Character vector of package names.
#' @keywords internal
parse_requirements_txt <- function(path) {
  lines <- readLines(path, warn = FALSE)
  packages <- character(0)

  for (line in lines) {
    line <- trimws(line)
    if (!nzchar(line)) next
    if (grepl("^#", line)) next
    if (grepl("^-", line)) next

    pkg <- sub("[>=<!~;\\[,].*", "", line)
    pkg <- trimws(pkg)
    if (nzchar(pkg)) packages <- c(packages, pkg)
  }

  sort(unique(packages))
}

#' Parse pyproject.toml dependencies section
#'
#' Simple parser for the \code{[project] dependencies} array in pyproject.toml.
#' Does not handle complex TOML -- just extracts quoted dependency strings.
#'
#' @param path Character string. Path to pyproject.toml.
#' @return Character vector of package names.
#' @keywords internal
parse_pyproject_toml <- function(path) {
  lines <- readLines(path, warn = FALSE)
  packages <- character(0)

  in_deps <- FALSE
  for (line in lines) {
    trimmed <- trimws(line)

    if (grepl("^dependencies\\s*=\\s*\\[", trimmed)) {
      in_deps <- TRUE
      next
    }

    if (in_deps) {
      if (grepl("^\\]", trimmed)) {
        in_deps <- FALSE
        next
      }

      match <- regmatches(trimmed, regexpr('"([^"]+)"', trimmed))
      if (length(match) > 0 && nzchar(match)) {
        pkg_spec <- gsub('"', '', match)
        pkg <- sub("[>=<!~;\\[,].*", "", pkg_spec)
        pkg <- trimws(pkg)
        if (nzchar(pkg)) packages <- c(packages, pkg)
      }
    }
  }

  sort(unique(packages))
}

#' Merge detected R dependencies with config declarations
#'
#' Combines auto-detected packages with user-declared packages from config.
#' When auto_detect is FALSE, only declared packages are used.
#'
#' @param detected Character vector of detected package names.
#' @param config_deps List from config$dependencies.
#' @return List with `packages` (character vector) and `repos` (list).
#' @keywords internal
merge_r_dependencies <- function(detected, config_deps) {
  repos <- config_deps$r$repos %||% SHINYELECTRON_DEFAULTS$dependencies$r$repos

  if (isTRUE(config_deps$auto_detect %||% TRUE)) {
    declared <- unlist(config_deps$r$packages %||% list())
    extra <- unlist(config_deps$extra_packages %||% list())
    packages <- sort(unique(c(detected, declared, extra)))
  } else {
    declared <- unlist(config_deps$r$packages %||% list())
    extra <- unlist(config_deps$extra_packages %||% list())
    packages <- sort(unique(c(declared, extra)))
  }

  list(packages = packages, repos = repos)
}

#' Merge detected Python dependencies with config declarations
#'
#' @param detected Character vector of detected package names.
#' @param config_deps List from config$dependencies.
#' @return List with `packages` (character vector) and `index_urls` (list).
#' @keywords internal
merge_py_dependencies <- function(detected, config_deps) {
  index_urls <- config_deps$python$index_urls %||%
    SHINYELECTRON_DEFAULTS$dependencies$python$index_urls

  if (isTRUE(config_deps$auto_detect %||% TRUE)) {
    declared <- unlist(config_deps$python$packages %||% list())
    extra <- unlist(config_deps$extra_packages %||% list())
    packages <- sort(unique(c(detected, declared, extra)))
  } else {
    declared <- unlist(config_deps$python$packages %||% list())
    extra <- unlist(config_deps$extra_packages %||% list())
    packages <- sort(unique(c(declared, extra)))
  }

  list(packages = packages, index_urls = index_urls)
}

#' Generate a dependency manifest file
#'
#' Creates a JSON manifest describing the packages an app needs.
#' This manifest is written into the Electron app and used by the
#' auto-download and container strategies to install packages at runtime.
#'
#' @param packages Character vector of package names.
#' @param language Character string: "r" or "python".
#' @param repos List of R repository URLs (for language = "r").
#' @param index_urls List of Python index URLs (for language = "python").
#' @return Character string of JSON content.
#' @keywords internal
generate_dependency_manifest <- function(packages, language,
                                         repos = NULL, index_urls = NULL) {
  manifest <- list(
    language = language,
    packages = as.list(packages),
    binary_only = TRUE
  )

  if (language == "r") {
    manifest$repos <- repos %||% SHINYELECTRON_DEFAULTS$dependencies$r$repos
  } else if (language == "python") {
    manifest$index_urls <- index_urls %||%
      SHINYELECTRON_DEFAULTS$dependencies$python$index_urls
  }

  # Look up Linux system dependencies at build time (optional, requires pak)
  if (language == "r" && length(packages) > 0) {
    if (requireNamespace("pak", quietly = TRUE)) {
      tryCatch({
        sysreqs <- pak::pkg_sysreqs(packages)
        if (!is.null(sysreqs) && !is.null(sysreqs$packages)) {
          manifest$system_deps <- list(
            debian = unique(unlist(sysreqs$packages[grepl("debian|ubuntu", names(sysreqs$packages), ignore.case = TRUE)])),
            fedora = unique(unlist(sysreqs$packages[grepl("fedora|rhel|centos", names(sysreqs$packages), ignore.case = TRUE)]))
          )
        }
      }, error = function(e) {
        # pak sysreqs lookup failed -- skip silently
      })
    }
  }

  jsonlite::toJSON(manifest, pretty = TRUE, auto_unbox = TRUE)
}

#' Install R packages as binary only
#'
#' Installs R packages into a specified library path using only binary
#' packages. Aborts if a binary is not available rather than falling
#' back to source compilation.
#'
#' @param packages Character vector of package names.
#' @param lib_path Character string. Target library directory.
#' @param repos Character vector of repository URLs.
#' @param available_pkgs Optional matrix from \code{utils::available.packages()}.
#'   When supplied the CRAN lookup is skipped, avoiding a redundant network
#'   call during the same export session.
#' @param verbose Logical. Whether to show progress.
#' @keywords internal
install_r_binary_packages <- function(packages, lib_path,
                                      repos = c("https://cloud.r-project.org"),
                                      available_pkgs = NULL,
                                      verbose = TRUE) {
  if (length(packages) == 0) {
    if (verbose) cli::cli_alert_info("No R packages to install")
    return(invisible(NULL))
  }

  fs::dir_create(lib_path, recurse = TRUE)

  if (verbose) {
    cli::cli_alert_info("Installing {length(packages)} R package{?s} (binary only)")
    cli::cli_alert_info("Target library: {.path {lib_path}}")
    cli::cli_alert_info("Packages: {paste(packages, collapse = ', ')}")
  }

  tryCatch({
    # Compute the full dependency tree so ALL transitive dependencies
    # are installed (not just the top-level packages). This is critical
    # for bundled strategy where the portable R has no pre-installed packages.
    if (verbose) cli::cli_alert_info("Resolving dependency tree...")
    if (is.null(available_pkgs)) {
      available_pkgs <- utils::available.packages(repos = repos)
    }
    all_deps <- tools::package_dependencies(packages, db = available_pkgs,
                                             which = c("Depends", "Imports", "LinkingTo"),
                                             recursive = TRUE)
    all_pkgs <- unique(c(packages, unlist(all_deps)))
    # Remove base packages that ship with R
    base_pkgs <- rownames(utils::installed.packages(priority = "base"))
    all_pkgs <- setdiff(all_pkgs, base_pkgs)

    if (verbose) cli::cli_alert_info("Installing {length(all_pkgs)} packages (including dependencies)")

    utils::install.packages(
      pkgs = all_pkgs,
      lib = lib_path,
      repos = repos,
      type = "binary",
      quiet = !verbose,
      dependencies = FALSE  # already resolved above
    )

    if (verbose) {
      cli::cli_alert_success("Installed R packages successfully")
    }
  }, error = function(e) {
    cli::cli_abort(c(
      "Failed to install R binary packages",
      "x" = "Error: {e$message}",
      "i" = "Ensure binary packages are available for your platform",
      "i" = "Check that your repository URLs are correct"
    ))
  })

  invisible(NULL)
}

#' Install Python packages as binary only
#'
#' Installs Python packages using pip with --only-binary :all: flag.
#'
#' @param packages Character vector of package names.
#' @param index_url Character string. PyPI index URL.
#' @param target_dir Character string or NULL. Target directory for installation.
#' @param verbose Logical. Whether to show progress.
#' @keywords internal
install_py_binary_packages <- function(packages,
                                       index_url = "https://pypi.org/simple",
                                       target_dir = NULL,
                                       verbose = TRUE) {
  if (length(packages) == 0) {
    if (verbose) cli::cli_alert_info("No Python packages to install")
    return(invisible(NULL))
  }

  python_cmd <- find_python_command()
  if (is.null(python_cmd)) {
    cli::cli_abort("Python is required but was not found")
  }

  if (verbose) {
    cli::cli_alert_info("Installing {length(packages)} Python package{?s} (binary only)")
    cli::cli_alert_info("Packages: {paste(packages, collapse = ', ')}")
  }

  args <- c("-m", "pip", "install", "--only-binary", ":all:", "-i", index_url)
  if (!is.null(target_dir)) {
    fs::dir_create(target_dir, recurse = TRUE)
    args <- c(args, "--target", target_dir)
  }
  args <- c(args, packages)

  result <- processx::run(
    python_cmd, args,
    echo = verbose, spinner = verbose,
    error_on_status = FALSE, timeout = 600
  )

  if (result$status != 0) {
    cli::cli_abort(c(
      "Failed to install Python binary packages",
      "x" = "Exit code: {result$status}",
      "x" = "Error: {result$stderr}",
      "i" = "Ensure binary wheels are available for your platform"
    ))
  }

  if (verbose) cli::cli_alert_success("Installed Python packages successfully")
  invisible(NULL)
}

#' Resolve application dependencies
#'
#' Top-level function that detects, merges, and returns the final list of
#' package dependencies for an app. Called from export() for native app types.
#'
#' @param appdir Character string. Path to the app directory.
#' @param app_type Character string. The app type.
#' @param config List. The effective configuration.
#' @return List with `packages`, `language`, and `repos`/`index_urls`,
#'   or NULL for shinylive types (which don't need dependency management).
#' @keywords internal
resolve_app_dependencies <- function(appdir, app_type, config) {
  if (app_type %in% SHINYLIVE_TYPES) {
    return(NULL)
  }

  config_deps <- config$dependencies %||% SHINYELECTRON_DEFAULTS$dependencies

  if (grepl("^r-", app_type)) {
    detected <- detect_r_dependencies(appdir)
    merged <- merge_r_dependencies(detected, config_deps)
    list(
      language = "r",
      packages = merged$packages,
      repos = merged$repos
    )
  } else {
    detected <- detect_py_dependencies(appdir)
    merged <- merge_py_dependencies(detected, config_deps)
    list(
      language = "python",
      packages = merged$packages,
      index_urls = merged$index_urls
    )
  }
}
