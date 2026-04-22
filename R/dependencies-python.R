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

#' Merge detected Python dependencies with config declarations
#'
#' @param detected Character vector of detected package names.
#' @param config_deps List from config$dependencies.
#' @return List with `packages` (character vector) and `index_urls` (list).
#' @keywords internal
merge_py_dependencies <- function(detected, config_deps) {
  index_urls <- config_deps$python$index_urls %||%
    SHINYELECTRON_DEFAULTS$dependencies$python$index_urls

  declared <- unlist(config_deps$python$packages %||% list())
  extra <- unlist(config_deps$extra_packages %||% list())

  packages <- if (isTRUE(config_deps$auto_detect %||% TRUE)) {
    sort(unique(c(detected, declared, extra)))
  } else {
    sort(unique(c(declared, extra)))
  }

  list(packages = packages, index_urls = index_urls)
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
