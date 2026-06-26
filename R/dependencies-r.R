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
#' Uses `renv::dependencies()` to scan R source files for package
#' references. This catches `library()`, `require()`,
#' `pkg::func()`, `loadNamespace()`, and other patterns.
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

  declared <- unlist(config_deps$r$packages %||% list())
  extra <- unlist(config_deps$extra_packages %||% list())

  packages <- if (isTRUE(config_deps$auto_detect %||% TRUE)) {
    sort(unique(c(detected, declared, extra)))
  } else {
    sort(unique(c(declared, extra)))
  }

  list(packages = packages, repos = repos)
}
