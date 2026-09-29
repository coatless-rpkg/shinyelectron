#' Embed a portable R runtime into a bundled Electron build
#'
#' Behavior-preserving extraction of the R bundled-embedding block from
#' [build_electron_app()]. ALWAYS installs + copies the interpreter (and resolves
#' symlinks) so the shared `runtime/R` path exists for suite-wide bundled
#' detection; only the package install is gated on a non-empty package set
#' (`packages` plus any local packages and their declared dependencies).
#' `packages` is the DIRECT set (as stored in `dependencies.json`); the recursive
#' dependency closure and the `pre_installed` setdiff are resolved here, against
#' the freshly-created `runtime/R/library`. Local packages are installed last,
#' with [install_local_r_packages()].
#'
#' @param output_dir Character. The Electron app output directory.
#' @param packages Character vector. DIRECT R package names (may be empty/NULL).
#' @param repos Character vector. CRAN-like repository URLs. `NULL` uses the
#'   default CRAN mirror.
#' @param version Character. Resolved R version (non-NULL from callers).
#' @param platform Character scalar. Target platform ("win"/"mac"/"linux").
#' @param arch Character scalar. Target architecture ("x64"/"arm64").
#' @param verbose Logical. Whether to display progress.
#' @param local_packages Character vector. Paths to local R package source
#'   folders or `.tar.gz` source tarballs to install into the bundled library
#'   after the repository packages. [export()] passes absolute paths; relative
#'   paths resolve against the working directory.
#' @return Invisibly, the path to the embedded `runtime/R` directory.
#' @keywords internal
embed_r_runtime <- function(output_dir, packages, repos, version,
                            platform, arch, verbose = TRUE,
                            local_packages = character(0)) {
  if (verbose) cli::cli_alert_info("Embedding R runtime for bundled strategy...")

  # Check the local package sources before anything is downloaded. export()
  # has already resolved them against the app directory; relative paths from
  # a direct call resolve against the working directory.
  local_packages <- resolve_local_packages(local_packages, base_dir = getwd())
  local_names <- local_r_package_names(local_packages)
  # Local packages may not be part of the detected/repo set; resolve their
  # declared dependencies explicitly so they are installed first.
  local_declared <- local_r_package_deps(local_packages)
  direct_pkgs <- unique(c(unlist(packages), local_names, local_declared))

  # Resolve the effective version ONCE and pass it to both install_r_portable and
  # r_executable, replacing the two independent NULL-fallbacks that could
  # otherwise make two GitHub API calls that disagree.
  effective_version <- version %||% r_portable_latest_version(platform)

  r_path <- install_r_portable(
    version = effective_version,
    platform = platform,
    arch = arch,
    verbose = verbose
  )

  # Copy runtime into the Electron app
  runtime_dest <- fs::path(output_dir, "runtime", "R")
  copy_dir_contents(r_path, runtime_dest)

  # Resolve symlinks that point outside the package directory.
  # Portable R may contain fontconfig symlinks pointing to system R,
  # which electron-builder refuses to package (security protection).
  runtime_files <- list.files(runtime_dest, recursive = TRUE,
                              full.names = TRUE, all.files = TRUE)
  for (f in runtime_files) {
    if (nzchar(Sys.readlink(f))) {
      abs_target <- normalizePath(f, mustWork = FALSE)
      if (file.exists(abs_target)) {
        file.remove(f)
        file.copy(abs_target, f, copy.date = TRUE)
      } else {
        # Dead symlink -- remove it
        file.remove(f)
      }
    }
  }

  # Install packages with the portable R that ships in the app (run from its
  # cached copy, see below), not system R. This ensures binary packages are
  # linked against matching dylibs AND are installed into the exact library
  # the app will load from at runtime.
  if (length(direct_pkgs) > 0) {

    # Install into a SIBLING library directory (runtime_dest/library/),
    # NOT into portable-r-*/library/. On macOS, installing into the
    # bundled R's own library triggers hardened-runtime library
    # validation at dyn.load() time, causing segfaults on unsigned
    # CRAN binaries. The sibling-library layout avoids that; the
    # Electron runtime (native-r.js) prepends this path to .libPaths().
    lib_path <- fs::path(runtime_dest, "library")
    fs::dir_create(lib_path, recurse = TRUE)

    # Use the CACHED Rscript, not the bundled copy. The cached binary
    # has its original code signature intact; running the copied one
    # on macOS with --vanilla can interact oddly with hardened-runtime
    # library validation.
    bundled_rscript <- r_executable(
      version = effective_version,
      platform = platform,
      arch = arch
    )

    if (is.null(bundled_rscript) || !fs::file_exists(bundled_rscript)) {
      cli::cli_abort(c(
        "Could not locate the cached portable Rscript",
        "i" = "Try: {.code shinyelectron::install_r_portable(force = TRUE)}"
      ))
    }

    if (verbose) cli::cli_alert_info("Installing packages with bundled R...")

    pkgs <- direct_pkgs
    repos <- unlist(repos) %||% unlist(SHINYELECTRON_DEFAULTS$dependencies$r$repos)

    # Fetch the available-packages database once (avoids repeated
    # CRAN network calls during the same export session).
    avail_pkgs <- utils::available.packages(repos = repos)

    # Resolve full dependency tree. Local packages are left out: their own
    # DESCRIPTION dependencies are already in pkgs, and a repository package
    # of the same name must not pull in its dependencies.
    all_deps <- tools::package_dependencies(
      setdiff(pkgs, local_names), db = avail_pkgs,
      which = c("Depends", "Imports", "LinkingTo"),
      recursive = TRUE
    )
    all_pkgs <- unique(c(pkgs, unlist(all_deps)))

    # Skip packages already present in the bundled library. Portable-R
    # ships with base + recommended + a few extras; reinstalling them is
    # wasteful and, on Windows, tripped "cannot remove prior installation"
    # errors when antivirus held file handles on freshly-extracted DLLs.
    pre_installed <- list.dirs(lib_path, recursive = FALSE, full.names = FALSE)
    pre_installed <- pre_installed[nzchar(pre_installed)]
    all_pkgs <- setdiff(all_pkgs, c(pre_installed, local_names))

    if (length(all_pkgs) == 0) {
      if (verbose) cli::cli_alert_info("All dependencies already present in bundled R library")
    } else {
      if (verbose) {
        cli::cli_alert_info("Installing {length(all_pkgs)} package{?s} into bundled library")
      }

      pkg_str <- paste0("'", all_pkgs, "'", collapse = ", ")
      repo_str <- paste0("'", repos, "'", collapse = ", ")
      # type = "binary" is unsupported on Linux (.Platform$pkgType ==
      # "source"); only request it on the platforms that accept it.
      # Keyed on the build HOST pkgType (detect_current_platform()), not the
      # target `platform` argument; they coincide for any successful build.
      type_clause <- if (identical(detect_current_platform(), "linux")) {
        ""
      } else {
        "type = 'binary', "
      }
      # Use the bundled library as both destination AND the only lib on
      # .libPaths, which avoids install.packages getting confused by
      # packages the caller's R_LIBS_USER may have inherited.
      r_code <- sprintf(
        paste0(
          ".libPaths('%s'); ",
          "install.packages(c(%s), lib = '%s', repos = c(%s), ",
          "%sdependencies = FALSE, quiet = TRUE)"
        ),
        gsub("\\\\", "/", lib_path),
        pkg_str,
        gsub("\\\\", "/", lib_path),
        repo_str,
        type_clause
      )

      # Pre-session code didn't scrub env or pass --vanilla and worked
      # fine -- the bundled library being a sibling (not the R's own
      # library) means R_LIBS_USER contamination doesn't override our
      # explicit lib_path argument to install.packages.
      result <- processx::run(
        bundled_rscript, c("-e", r_code),
        error_on_status = FALSE,
        echo = verbose,
        timeout = 600
      )

      # Verify every app-direct package is present in the bundled library
      # after install. A post-install check is far easier to diagnose
      # than "no package called 'htmltools'" from a running Shiny server.
      present <- c(pre_installed,
                   list.dirs(lib_path, recursive = FALSE, full.names = FALSE))
      missing_pkgs <- setdiff(pkgs, c(present, local_names))
      if (length(missing_pkgs) > 0) {
        cli::cli_abort(c(
          "Failed to install bundled R packages: {paste(missing_pkgs, collapse = ', ')}",
          "i" = "install.packages exit code: {result$status}",
          "x" = "stderr: {trimws(result$stderr %||% '')}"
        ))
      }

    }
  }

  # Install any user-supplied local R package sources AFTER the repository
  # packages, with the same Rscript. Their names were left out of the
  # repository install, so the local build is the one that ships. Local
  # packages always make the block above run, so lib_path and
  # bundled_rscript are set.
  if (length(local_packages) > 0) {
    install_local_r_packages(bundled_rscript, local_packages, lib_path,
                             verbose = verbose)
  }

  if (verbose) cli::cli_alert_success("Embedded R runtime")
  invisible(runtime_dest)
}

#' Embed a portable Python runtime into a bundled Electron build
#'
#' Behavior-preserving extraction of the Python bundled-embedding block from
#' [build_electron_app()]. ALWAYS installs + copies the interpreter so the shared
#' `runtime/Python` path exists for suite-wide bundled detection; only the pip
#' install is gated on a non-empty `packages` set. Warn-only (not abort) on pip
#' failure; the result is not verified, matching the original block. Reproduces
#' the three `output_dir`-derived paths and the unix-only fallback glob so the
#' `native-py.js` `sys.path` expectations hold.
#'
#' @param output_dir Character. The Electron app output directory.
#' @param packages Character vector. Python package specs (may be empty/NULL).
#' @param index_urls Character vector. PyPI-like index URLs.
#' @param version Character. Resolved Python version (non-NULL from callers).
#' @param platform Character scalar. Target platform.
#' @param arch Character scalar. Target architecture.
#' @param verbose Logical. Whether to display progress.
#' @return Invisibly, the path to the embedded `runtime/Python` directory.
#' @keywords internal
embed_python_runtime <- function(output_dir, packages, index_urls, version,
                                 platform, arch, verbose = TRUE) {
  if (verbose) cli::cli_alert_info("Embedding Python runtime for bundled strategy...")

  # Resolve the effective version ONCE and pass it to both install_python_standalone and
  # python_executable.
  effective_version <- version %||% SHINYELECTRON_DEFAULTS$runtime_versions$python$version

  py_path <- install_python_standalone(
    version = effective_version,
    platform = platform,
    arch = arch,
    verbose = verbose
  )

  runtime_dest <- fs::path(output_dir, "runtime", "Python")
  copy_dir_contents(py_path, runtime_dest)

  # Install packages using the BUNDLED Python (not system Python) so
  # C extensions match the bundled Python version's ABI
  bundled_python <- python_executable(effective_version, platform, arch)
  if (is.null(bundled_python)) {
    # Fall back to searching the copied runtime
    bundled_python <- Sys.glob(fs::path(runtime_dest, "*", "python", "bin", "python3"))[1]
  }

  if (!is.null(bundled_python) && length(packages) > 0) {
    index_url <- unlist(index_urls)[1] %||% "https://pypi.org/simple"
    pip_args <- c("-m", "pip", "install", "--only-binary", ":all:",
                 "-i", index_url,
                 "--target", fs::path(runtime_dest, "lib", "python", "site-packages"),
                 unlist(packages))
    if (verbose) {
      cli::cli_alert_info("Installing Python packages using bundled Python...")
    }
    pip_result <- processx::run(
      bundled_python, pip_args,
      echo = verbose, spinner = verbose,
      error_on_status = FALSE, timeout = 600
    )
    if (pip_result$status != 0) {
      cli::cli_warn(c(
        "Failed to install some Python packages",
        "x" = "Error: {pip_result$stderr}"
      ))
    }
  }

  if (verbose) cli::cli_alert_success("Embedded Python runtime")
  invisible(runtime_dest)
}

#' Resolve and check the configured local R package sources
#'
#' Turns the `dependencies.r.local_packages` entries into absolute paths and
#' checks them before anything is copied or downloaded. [export()] and the
#' multi-app export call this with the directory that holds
#' `_shinyelectron.yml` (the app directory, or the suite root), and
#' [embed_r_runtime()] calls it again for direct callers. Each entry must be a
#' package source folder (with a `DESCRIPTION`) or a `.tar.gz` / `.tgz` source
#' tarball.
#'
#' @param local_packages Character vector or list. The configured entries.
#' @param base_dir Character. Directory that relative entries resolve against.
#' @param bundled_r Logical. Whether an R app in this build uses the bundled
#'   strategy. Local packages are only installed into a bundled R library, so
#'   a non-empty list aborts when this is `FALSE`.
#' @return Character vector of absolute paths (empty when nothing is set).
#' @keywords internal
resolve_local_packages <- function(local_packages, base_dir, bundled_r = TRUE) {
  entries <- local_packages %||% list()
  if (!is.list(entries)) entries <- as.list(entries)
  if (length(entries) == 0) {
    return(character(0))
  }

  if (!isTRUE(bundled_r)) {
    cli::cli_abort(c(
      "{.field dependencies.r.local_packages} only works for R apps that use the {.val bundled} runtime strategy.",
      "i" = "Set {.field build.runtime_strategy} to {.val bundled}, or remove {.field dependencies.r.local_packages}."
    ), class = "shinyelectron_local_packages_strategy")
  }

  is_path <- vapply(entries, function(p) {
    is.character(p) && length(p) == 1L && !is.na(p) && nzchar(trimws(p))
  }, logical(1))
  if (!all(is_path)) {
    bad <- as.character(which(!is_path))
    cli::cli_abort(c(
      "Each {.field dependencies.r.local_packages} entry must be a path to an R package source.",
      "x" = "Not a path: entr{?y/ies} {bad}."
    ), class = "shinyelectron_local_packages_invalid")
  }

  base_dir <- fs::path_abs(path.expand(base_dir))
  paths <- vapply(entries, function(p) {
    as.character(fs::path_abs(path.expand(p), start = base_dir))
  }, character(1), USE.NAMES = FALSE)

  missing <- paths[!file.exists(paths)]
  if (length(missing) > 0) {
    cli::cli_abort(c(
      "Local R package source{?s} not found: {.path {missing}}",
      "i" = "Relative {.field dependencies.r.local_packages} paths resolve against {.path {base_dir}}."
    ), class = "shinyelectron_local_packages_missing")
  }

  # Reads every DESCRIPTION, which rejects anything that is not a package
  # source folder or source tarball.
  pkgs <- local_r_package_names(paths)
  dupes <- unique(pkgs[duplicated(pkgs)])
  if (length(dupes) > 0) {
    cli::cli_abort(
      "{.field dependencies.r.local_packages} lists package {.pkg {dupes}} more than once.",
      class = "shinyelectron_local_packages_invalid"
    )
  }

  paths
}

#' Read the metadata of local R package sources
#'
#' @param paths Character vector. Paths to package source folders or `.tar.gz`
#'   / `.tgz` source tarballs.
#' @return A list with one element per path, named by package. Each element
#'   holds `path`, `package`, `version`, `deps` (the package names from
#'   `Depends`, `Imports` and `LinkingTo`, without `R`) and `is_dir`.
#' @keywords internal
local_r_package_info <- function(paths) {
  paths <- as.character(unlist(paths))
  info <- lapply(paths, function(p) {
    dcf <- local_read_description(p)
    fields <- intersect(c("Depends", "Imports", "LinkingTo"), colnames(dcf))
    deps <- unlist(lapply(fields, function(f) local_parse_deps(dcf[1, f])))
    list(
      path = p,
      package = unname(dcf[1, "Package"]),
      version = unname(dcf[1, "Version"]),
      deps = unique(as.character(deps)),
      is_dir = dir.exists(p)
    )
  })
  names(info) <- vapply(info, `[[`, character(1), "package")
  info
}

#' Resolve the package names of local R package paths
#'
#' Reads the `Package` field from each source folder's `DESCRIPTION`, or from
#' the `DESCRIPTION` in a source tarball's top-level folder.
#'
#' @param paths Character vector. Paths to local package directories or archives.
#' @return Character vector of package names (empty when `paths` is empty).
#' @keywords internal
local_r_package_names <- function(paths) {
  vapply(local_r_package_info(paths), `[[`, character(1), "package",
         USE.NAMES = FALSE)
}

#' Resolve the declared dependencies of local R package paths
#'
#' Reads `Depends`, `Imports` and `LinkingTo` from each local package's
#' `DESCRIPTION` (directories and archives alike) so the repository install step
#' can install them before the local package is installed from source. Version
#' constraints and `R` are stripped, and base/recommended packages are dropped.
#'
#' @param paths Character vector. Paths to local package directories or archives.
#' @return Character vector of dependency package names.
#' @keywords internal
local_r_package_deps <- function(paths) {
  deps <- as.character(unlist(lapply(local_r_package_info(paths), `[[`, "deps")))
  setdiff(unique(deps), BASE_R_PACKAGES)
}

# Package names from one Depends/Imports/LinkingTo field, without version
# constraints or R itself.
local_parse_deps <- function(field) {
  if (is.na(field) || !nzchar(trimws(field))) {
    return(character(0))
  }
  parts <- strsplit(field, ",", fixed = TRUE)[[1]]
  parts <- trimws(sub("(?s)\\(.*$", "", parts, perl = TRUE))
  parts[nzchar(parts) & parts != "R"]
}

# Read the DESCRIPTION of a local package source: a folder, or a .tar.gz / .tgz
# source tarball. Tarball top-level folder names vary (`<pkg>/` from R CMD
# build, `<pkg>-<ref>/` from GitHub), so the fields come from the DESCRIPTION
# in the single top-level folder rather than from the file name. Anything else,
# including zip files and binary or installed builds, aborts.
local_read_description <- function(path) {
  path <- unlist(path)[[1]]
  if (dir.exists(path)) {
    desc <- file.path(path, "DESCRIPTION")
    if (!file.exists(desc)) {
      cli::cli_abort(c(
        "{.path {path}} is not an R package source: it has no {.file DESCRIPTION} file.",
        "i" = "Use the folder that holds the package's {.file DESCRIPTION}."
      ), class = "shinyelectron_local_packages_invalid")
    }
    dcf <- tryCatch(read.dcf(desc), error = function(e) NULL)
  } else if (!file.exists(path)) {
    cli::cli_abort(
      "Local R package source not found: {.path {path}}",
      class = "shinyelectron_local_packages_missing"
    )
  } else if (grepl("\\.zip$", path, ignore.case = TRUE)) {
    cli::cli_abort(c(
      "{.path {path}} is a zip file, which cannot be installed as an R package source.",
      "i" = "Use the package source folder or a {.file .tar.gz} source tarball from {.code R CMD build}."
    ), class = "shinyelectron_local_packages_invalid")
  } else if (!grepl("\\.(tar\\.gz|tgz)$", path, ignore.case = TRUE)) {
    cli::cli_abort(c(
      "{.path {path}} is not an R package source.",
      "i" = "Use a package source folder or a {.file .tar.gz} or {.file .tgz} source tarball."
    ), class = "shinyelectron_local_packages_invalid")
  } else {
    dcf <- local_read_archive_description(path)
  }

  if (is.null(dcf) || nrow(dcf) != 1L ||
      !all(c("Package", "Version") %in% colnames(dcf)) ||
      anyNA(dcf[1, c("Package", "Version")])) {
    cli::cli_abort(
      "Could not read the {.field Package} and {.field Version} fields of {.path {path}}.",
      class = "shinyelectron_local_packages_invalid"
    )
  }
  pkg <- unname(dcf[1, "Package"])
  if ("Built" %in% colnames(dcf)) {
    cli::cli_abort(c(
      "{.path {path}} is an installed or binary build of {.pkg {pkg}}, not its source.",
      "i" = "Local packages are compiled for the bundled R, so use the package source folder or a source tarball."
    ), class = "shinyelectron_local_packages_invalid")
  }
  if (!grepl("^[[:alpha:]][[:alnum:].]*[[:alnum:]]$", pkg)) {
    cli::cli_abort(
      "{.path {path}} declares an invalid package name: {.val {pkg}}",
      class = "shinyelectron_local_packages_invalid"
    )
  }
  dcf
}

# Read `<top>/DESCRIPTION` from a source tarball, extracting only that file.
# Returns NULL when it cannot be read. R's own tar warns about headers it
# skips, such as the pax global header that git archive writes, so warnings
# are silenced rather than treated as a failure.
local_read_archive_description <- function(path) {
  entries <- tryCatch(
    suppressWarnings(utils::untar(path, list = TRUE)),
    error = function(e) NULL
  )
  top <- unique(grep("^(\\./)?[^/]+/DESCRIPTION$", entries, value = TRUE))
  if (length(top) != 1L) {
    cli::cli_abort(c(
      "{.path {path}} does not look like an R source tarball.",
      "i" = "Expected a single top-level folder holding a {.file DESCRIPTION}, as {.code R CMD build} creates."
    ), class = "shinyelectron_local_packages_invalid")
  }

  tmp <- tempfile("shinyelectron-desc-")
  dir.create(tmp)
  on.exit(unlink(tmp, recursive = TRUE), add = TRUE)
  tryCatch(
    suppressWarnings(utils::untar(path, files = top, exdir = tmp)),
    error = function(e) NULL
  )
  desc <- file.path(tmp, top)
  if (!file.exists(desc)) {
    return(NULL)
  }
  tryCatch(read.dcf(desc), error = function(e) NULL)
}

#' Order local R packages so each installs after the local packages it needs
#'
#' A stable topological sort over `Depends`, `Imports` and `LinkingTo`,
#' restricted to the local packages themselves. Packages keep their listed
#' order where their dependencies allow it.
#'
#' @param info List from [local_r_package_info()].
#' @return Character vector of package names in install order.
#' @keywords internal
local_r_install_order <- function(info) {
  pkgs <- unique(names(info))
  needs <- lapply(info[pkgs], function(p) setdiff(intersect(p$deps, pkgs), p$package))
  order <- character(0)
  while (length(order) < length(pkgs)) {
    remaining <- setdiff(pkgs, order)
    ready <- remaining[vapply(remaining, function(p) all(needs[[p]] %in% order),
                              logical(1))]
    if (length(ready) == 0) {
      cli::cli_abort(c(
        "Cannot order the local R packages {.pkg {remaining}}: their dependencies form a cycle.",
        "i" = "Check the {.field Depends}, {.field Imports} and {.field LinkingTo} fields of these packages."
      ), class = "shinyelectron_local_packages_cycle")
    }
    order <- c(order, ready[[1]])
  }
  order
}

#' Install local R package sources into the bundled library
#'
#' Installs each local package with the cached portable `Rscript` that also
#' installs the repository packages, one package at a time and after the
#' local packages it depends on ([local_r_install_order()]). A source folder is
#' first built into a tarball in a temporary directory with the same portable
#' R's `R CMD build`, so nothing is compiled or written inside the folder and
#' stale object files in it never reach the bundle. The build waits until the
#' repository packages and the earlier local packages are in the library,
#' because `R CMD build` installs the package to process help pages with
#' build-stage Sexpr macros, and that install needs the package's
#' dependencies.
#'
#' A package counts as installed only when a fresh process of the same
#' `Rscript` loads it from the bundled library. That check catches compile
#' errors, `.onLoad()` failures and timed-out installs, and because it looks
#' for a line printed after loading rather than at the exit status, it also
#' tolerates the Windows crash described below. On failure the build stops
#' with the load error and the last lines of the install output.
#'
#' The build, the install and the check run with the caller's environment plus
#' `R_LIBS`, `R_LIBS_USER` and `R_LIBS_SITE` set to the bundled library.
#' `R_LIBS_SITE` is the one that matters: the portable R's `Rprofile.site`
#' resets `.libPaths()` to its own library plus the site library, including in
#' the child processes of `R CMD build` and `R CMD INSTALL`.
#'
#' On Windows hosts the install adds `--no-staged-install --no-clean-on-error`.
#' There the bundled R's lazy-load step can crash while exiting, after it has
#' written the package, and `R CMD INSTALL` then reports a failure. These
#' options keep the files in place so the load check can decide. Elsewhere the
#' default staged install keeps a failed package out of the library.
#'
#' @param rscript Character. Path to the cached portable `Rscript`.
#' @param local_packages Character vector. Paths to package source folders or
#'   source tarballs.
#' @param lib_path Character. Destination library (the bundled library).
#' @param verbose Logical. Whether to display progress.
#' @param timeout Numeric. Seconds allowed for building or installing one
#'   package. The default of 30 minutes leaves room for large packages with
#'   compiled code.
#' @return Invisibly, the installed package names in install order.
#' @keywords internal
install_local_r_packages <- function(rscript, local_packages, lib_path,
                                     verbose = TRUE, timeout = 1800) {
  info <- local_r_package_info(local_packages)
  if (length(info) == 0) {
    return(invisible(character(0)))
  }
  info <- info[local_r_install_order(info)]
  lib <- normalizePath(lib_path, winslash = "/", mustWork = TRUE)
  env <- local_r_env(lib)

  build_dir <- tempfile("shinyelectron-local-")
  dir.create(build_dir)
  on.exit(unlink(build_dir, recursive = TRUE), add = TRUE)

  if (verbose) {
    cli::cli_alert_info(
      "Installing {length(info)} local R package{?s} with bundled R: {.pkg {names(info)}}"
    )
  }
  for (pkg in info) {
    source <- if (pkg$is_dir) {
      build_local_r_package(pkg, rscript, build_dir, env,
                            timeout = timeout, verbose = verbose)
    } else {
      normalizePath(pkg$path, winslash = "/", mustWork = TRUE)
    }
    install_local_r_package(rscript, pkg$package, source, lib, env = env,
                            timeout = timeout, verbose = verbose)
  }
  invisible(names(info))
}

# Environment for the R processes that build, install and load-check local
# packages: the caller's environment (PATH, HOME, TMPDIR, Makevars settings)
# with the bundled library as the user and site library.
local_r_env <- function(lib) {
  c("current", R_LIBS = lib, R_LIBS_USER = lib, R_LIBS_SITE = lib)
}

# Build a source tarball of a local package folder into `build_dir` with the R
# front end next to `rscript`, in the install environment. R CMD build works
# on a copy of the folder: it cleans src/ and applies .Rbuildignore without
# changing the folder itself. For help pages with build-stage Sexpr macros it
# also installs the package into a temporary library, which finds the
# package's dependencies in the bundled library through `env`.
build_local_r_package <- function(pkg, rscript, build_dir, env,
                                  timeout = 1800, verbose = TRUE) {
  r_bin <- file.path(
    dirname(rscript),
    if (.Platform$OS.type == "windows") "R.exe" else "R"
  )
  if (!file.exists(r_bin)) {
    cli::cli_abort(
      "Could not find the R front end next to {.path {rscript}}.",
      class = "shinyelectron_local_packages_build"
    )
  }
  if (verbose) cli::cli_alert_info("Building a source tarball of {.pkg {pkg$package}}...")
  result <- processx::run(
    r_bin,
    c("CMD", "build", "--no-build-vignettes", "--no-manual",
      normalizePath(pkg$path, winslash = "/", mustWork = TRUE)),
    wd = build_dir, env = env, error_on_status = FALSE, echo = verbose,
    stderr_to_stdout = TRUE, timeout = timeout, cleanup_tree = TRUE
  )
  tarball <- file.path(build_dir, paste0(pkg$package, "_", pkg$version, ".tar.gz"))
  if (!isTRUE(result$status == 0) || !file.exists(tarball)) {
    cli::cli_abort(c(
      "Could not build a source tarball of local R package {.pkg {pkg$package}} from {.path {pkg$path}}.",
      if (isTRUE(result$timeout)) {
        c("x" = "{.code R CMD build} did not finish within {local_r_duration(timeout)}.")
      },
      local_r_output_bullets(result$stdout, "Last lines of the {.code R CMD build} output:"),
      local_r_verbose_hint(verbose)
    ), class = "shinyelectron_local_packages_build")
  }
  normalizePath(tarball, winslash = "/")
}

# Install one local package from a source tarball with the cached portable
# Rscript, then check that it loads from `lib` in a fresh process.
install_local_r_package <- function(rscript, pkg, source, lib,
                                    env = local_r_env(lib), timeout = 1800,
                                    verbose = TRUE) {
  r_lit <- function(x) encodeString(x, quote = "'")

  # Start from an empty slot so the load check can only pass for the package
  # installed here.
  unlink(file.path(lib, pkg), recursive = TRUE)

  # On Windows the bundled R's lazy-load step can crash while exiting, after
  # it has written the package, so R CMD INSTALL reports a failure. Keep the
  # files where they land and let the load check decide. Elsewhere the staged
  # install keeps a failed package out of the library.
  install_opts <- if (identical(detect_current_platform(), "win")) {
    ", INSTALL_opts = c('--no-staged-install', '--no-clean-on-error')"
  } else {
    ""
  }
  r_code <- sprintf(
    paste0(
      ".libPaths(c(%s, .libPaths())); ",
      "install.packages(%s, lib = %s, repos = NULL, type = 'source', ",
      "dependencies = FALSE%s)"
    ),
    r_lit(lib), r_lit(source), r_lit(lib), install_opts
  )

  if (verbose) cli::cli_alert_info("Installing {.pkg {pkg}} from source...")
  # Same Rscript and startup flags as the repository install.
  result <- processx::run(
    rscript, c("-e", r_code),
    env = env, error_on_status = FALSE, echo = verbose,
    stderr_to_stdout = TRUE, timeout = timeout, cleanup_tree = TRUE
  )

  # A killed or failed install can leave its lock directory behind.
  unlink(list.files(lib, pattern = "^00LOCK", full.names = TRUE), recursive = TRUE)

  install_output <- local_r_output_bullets(
    result$stdout, "Last lines of the {.code R CMD INSTALL} output:"
  )
  if (isTRUE(result$timeout)) {
    unlink(file.path(lib, pkg), recursive = TRUE)
    cli::cli_abort(c(
      "Installing local R package {.pkg {pkg}} did not finish within {local_r_duration(timeout)}.",
      install_output,
      local_r_verbose_hint(verbose)
    ), class = "shinyelectron_local_packages_install")
  }

  check <- check_local_r_package_loads(rscript, pkg, lib, env)
  if (!check$ok) {
    installed <- dir.exists(file.path(lib, pkg))
    unlink(file.path(lib, pkg), recursive = TRUE)
    cli::cli_abort(c(
      if (installed) {
        "Local R package {.pkg {pkg}} does not load from the bundled library."
      } else {
        "Local R package {.pkg {pkg}} did not install into the bundled library."
      },
      if (!installed) install_output,
      local_r_output_bullets(check$stderr, "Loading it in a fresh R session failed:"),
      if (check$timeout) {
        c("x" = "Loading did not finish within {local_r_duration(300)}.")
      },
      local_r_verbose_hint(verbose)
    ), class = "shinyelectron_local_packages_install")
  }

  if (verbose) cli::cli_alert_success("Installed {.pkg {pkg}}")
  invisible(TRUE)
}

# Load `pkg` from `lib` in a fresh process of `rscript`. Success is a line
# printed after loading, not the exit status, so a crash while the process
# exits does not count as a failure.
check_local_r_package_loads <- function(rscript, pkg, lib, env, timeout = 300) {
  r_lit <- function(x) encodeString(x, quote = "'")
  r_code <- sprintf(
    "invisible(loadNamespace(%s, lib.loc = %s)); cat('\\n<<SE_LOAD_OK>>\\n')",
    r_lit(pkg), r_lit(lib)
  )
  result <- processx::run(
    rscript, c("-e", r_code),
    env = env, error_on_status = FALSE, timeout = timeout, cleanup_tree = TRUE
  )
  stdout <- result$stdout %||% ""
  list(
    ok = grepl("(^|\n)<<SE_LOAD_OK>>\r?(\n|$)", stdout),
    stdout = stdout,
    stderr = result$stderr %||% "",
    timeout = isTRUE(result$timeout)
  )
}

# The last `n` non-empty lines of process output as cli bullets under
# `heading`, with braces escaped so cli prints them verbatim. NULL when there
# is no output.
local_r_output_bullets <- function(text, heading, n = 25) {
  lines <- strsplit(paste(text %||% "", collapse = "\n"), "\r?\n")[[1]]
  lines <- utils::tail(lines[nzchar(trimws(lines))], n)
  if (length(lines) == 0) {
    return(NULL)
  }
  lines <- gsub("}", "}}", gsub("{", "{{", lines, fixed = TRUE), fixed = TRUE)
  c(c("x" = heading), stats::setNames(lines, rep(" ", length(lines))))
}

# Points to the full output when it was not shown as it ran.
local_r_verbose_hint <- function(verbose) {
  if (isTRUE(verbose)) {
    return(NULL)
  }
  c("i" = "Run with {.code verbose = TRUE} to see the full output.")
}

# "30 minutes" or "45 seconds".
local_r_duration <- function(seconds) {
  if (seconds >= 60 && seconds %% 60 == 0) {
    cli::format_inline("{seconds %/% 60} minute{?s}")
  } else {
    cli::format_inline("{seconds} second{?s}")
  }
}
