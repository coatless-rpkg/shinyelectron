#' Detect Python package dependencies from requirements files
#'
#' Reads `requirements.txt` or `pyproject.toml` to determine
#' Python package dependencies. Does NOT parse import statements -- the
#' module-name-to-package-name mapping (e.g., `import cv2` maps to
#' `opencv-python`) makes import parsing unreliable.
#'
#' Prefers `requirements.txt` over `pyproject.toml` when both exist.
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
    # Skip direct VCS references (e.g. git+https://github.com/x/y.git).
    if (grepl("^(git|hg|svn|bzr)\\+", line)) next
    # PEP 508 direct reference "name @ url": keep only the name part.
    if (grepl("@", line)) line <- trimws(sub("@.*", "", line))
    # Bare URL with no package name: nothing usable to install by name.
    if (grepl("://", line)) next

    pkg <- sub("[>=<!~;\\[,].*", "", line)
    pkg <- trimws(pkg)
    if (nzchar(pkg)) packages <- c(packages, pkg)
  }

  sort(unique(packages))
}

#' Parse pyproject.toml dependencies section
#'
#' Simple parser for the `[project] dependencies` array in pyproject.toml.
#' Does not handle complex TOML -- just extracts quoted dependency strings.
#'
#' @param path Character string. Path to pyproject.toml.
#' @return Character vector of package names.
#' @keywords internal
parse_pyproject_toml <- function(path) {
  lines <- readLines(path, warn = FALSE)
  packages <- character(0)

  # Extract every double-quoted token on a line (handles multiple per line).
  extract_quoted <- function(s) {
    m <- regmatches(s, gregexpr('"[^"]*"', s))[[1]]
    gsub('"', '', m)
  }
  # Reduce a PEP 508 spec ("pandas>=2.0", "shiny[theme]", "x @ url") to a name.
  spec_to_name <- function(spec) {
    trimws(sub("[>=<!~;@\\[,].*", "", spec))
  }
  add_specs <- function(specs) {
    for (spec in specs) {
      pkg <- spec_to_name(spec)
      if (nzchar(pkg)) packages <<- c(packages, pkg)
    }
  }

  in_deps <- FALSE
  for (line in lines) {
    trimmed <- trimws(line)

    if (!in_deps && grepl("^dependencies\\s*=\\s*\\[", trimmed)) {
      in_deps <- TRUE
      # Capture any packages declared on the opening line itself, e.g.
      # dependencies = ["shiny", "pandas"].
      after <- sub("^dependencies\\s*=\\s*\\[", "", trimmed)
      add_specs(extract_quoted(after))
      # A single-line array closes on the same line.
      if (grepl("\\]", after)) in_deps <- FALSE
      next
    }

    if (in_deps) {
      add_specs(extract_quoted(trimmed))
      # The closing bracket may share a line with the last entry.
      if (grepl("\\]", trimmed)) in_deps <- FALSE
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
