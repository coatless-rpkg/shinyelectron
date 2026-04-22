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
