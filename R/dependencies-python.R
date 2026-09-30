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

    # The name ends at the extras, version, or marker. A version may sit in
    # parentheses, as in "shiny (>=1.0)".
    pkg <- sub("[>=<!~;\\[,(].*", "", line)
    pkg <- trimws(pkg)
    if (nzchar(pkg)) packages <- c(packages, pkg)
  }

  sort(unique(packages))
}

#' Parse pyproject.toml dependencies section
#'
#' Simple parser for the `[project] dependencies` array in pyproject.toml,
#' where PEP 621 lists runtime dependencies. `dependencies` arrays in other
#' tables, such as Hatch's `[tool.hatch.envs.*]` environments, are ignored.
#' Entries may use double or single quotes, and `#` comments are skipped.
#' Does not handle complex TOML such as multi-line strings or a dotted
#' `project.dependencies` key.
#'
#' @param path Character string. Path to pyproject.toml.
#' @return Character vector of package names.
#' @keywords internal
parse_pyproject_toml <- function(path) {
  lines <- readLines(path, warn = FALSE)
  packages <- character(0)

  # The strings, comments, and "]" on a line, in order. A double-quoted
  # string may hold backslash escapes; a single-quoted (literal) one cannot.
  # Matching whole strings keeps a "]" or "#" inside one, as in
  # "uvicorn[standard]", from ending the array or starting a comment.
  array_tokens <- function(s) {
    pattern <- "\"(?:[^\"\\\\]|\\\\.)*\"|'[^']*'|#.*|\\]"
    regmatches(s, gregexpr(pattern, s, perl = TRUE))[[1]]
  }
  # Reduce a PEP 508 spec ("pandas>=2.0", "shiny[theme]", "x @ url", or
  # "shiny (>=1.0)" as Poetry 2 writes it) to a name.
  spec_to_name <- function(spec) {
    trimws(sub("[>=<!~;@\\[,(].*", "", spec))
  }
  # The package names in a set of specs, without empty ones.
  spec_names <- function(specs) {
    pkgs <- vapply(specs, spec_to_name, character(1), USE.NAMES = FALSE)
    pkgs[nzchar(pkgs)]
  }

  in_project <- FALSE
  in_deps <- FALSE
  for (line in lines) {
    trimmed <- trimws(line)

    if (!in_deps) {
      # A table header such as [project] or [tool.hatch.envs.test].
      if (startsWith(trimmed, "[")) {
        in_project <- grepl("^\\[\\s*project\\s*\\]\\s*(#.*)?$", trimmed)
        next
      }
      if (!in_project || !grepl("^dependencies\\s*=\\s*\\[", trimmed)) next
      in_deps <- TRUE
      # The rest of the opening line may already hold packages, e.g.
      # dependencies = ["shiny", "pandas"].
      trimmed <- sub("^dependencies\\s*=\\s*\\[", "", trimmed)
    }

    tokens <- array_tokens(trimmed)
    # The array ends at the first "]" outside a string or comment. It may
    # share a line with the last entry, or with the opening line in a
    # single-line array.
    closing <- match("]", tokens)
    if (!is.na(closing)) {
      tokens <- tokens[seq_len(closing - 1L)]
      in_deps <- FALSE
    }
    # The entries are the strings without their quotes; comments are dropped.
    strings <- tokens[!startsWith(tokens, "#")]
    specs <- substr(strings, 2L, nchar(strings) - 1L)
    packages <- c(packages, spec_names(specs))
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
