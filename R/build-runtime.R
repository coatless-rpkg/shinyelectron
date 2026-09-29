#' Embed a portable R runtime into a bundled Electron build
#'
#' Behavior-preserving extraction of the R bundled-embedding block from
#' [build_electron_app()]. ALWAYS installs + copies the interpreter (and resolves
#' symlinks) so the shared `runtime/R` path exists for suite-wide bundled
#' detection; only the package install is gated on a non-empty `packages` set.
#' `packages` is the DIRECT set (as stored in `dependencies.json`); the recursive
#' dependency closure and the `pre_installed` setdiff are resolved here, against
#' the freshly-created `runtime/R/library`.
#'
#' @param output_dir Character. The Electron app output directory.
#' @param packages Character vector. DIRECT R package names (may be empty/NULL).
#' @param repos Character vector. CRAN-like repository URLs.
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

  # Install packages using the BUNDLED portable R itself (not the cache,
  # and not system R). This ensures binary packages are linked against
  # matching dylibs AND are installed into the exact library the app
  # will load from at runtime.
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
    repos <- unlist(repos)

    # Fetch the available-packages database once (avoids repeated
    # CRAN network calls during the same export session).
    avail_pkgs <- utils::available.packages(repos = repos)

    # Resolve full dependency tree
    all_deps <- tools::package_dependencies(
      pkgs, db = avail_pkgs,
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
  # packages, so a local build overrides a same-named package from CRAN.
  if (length(local_packages) > 0) {
    local_lib <- fs::path(runtime_dest, "library")
    fs::dir_create(local_lib, recurse = TRUE)

    local_rscript <- r_executable(
      version = effective_version,
      platform = platform,
      arch = arch
    )
    if (is.null(local_rscript) || !fs::file_exists(local_rscript)) {
      cli::cli_abort(c(
        "Could not locate the cached portable Rscript",
        "i" = "Try: {.code shinyelectron::install_r_portable(force = TRUE)}"
      ))
    }

    install_local_r_packages(local_rscript, local_packages, local_lib,
                             verbose = verbose)

    present_local <- list.dirs(local_lib, recursive = FALSE, full.names = FALSE)
    missing_local <- setdiff(local_names, present_local)
    if (length(missing_local) > 0) {
      cli::cli_abort(
        "Failed to install local R package(s): {paste(missing_local, collapse = ', ')}"
      )
    }
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
# Returns NULL when it cannot be read.
local_read_archive_description <- function(path) {
  entries <- tryCatch(
    utils::untar(path, list = TRUE),
    error = function(e) NULL,
    warning = function(w) NULL
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
    utils::untar(path, files = top, exdir = tmp),
    error = function(e) NULL,
    warning = function(w) NULL
  )
  desc <- file.path(tmp, top)
  if (!file.exists(desc)) {
    return(NULL)
  }
  tryCatch(read.dcf(desc), error = function(e) NULL)
}

#' Install local R package sources into the bundled library
#'
#' Installs source directories or archives with the bundled R (matching the
#' runtime version), after the repository install step, so a local build
#' overrides a same-named package from the repositories. The bundled library is
#' placed on `.libPaths()` and exported as `R_LIBS` / `R_LIBS_USER` /
#' `R_LIBS_SITE` so the `R CMD INSTALL` child spawned by `install.packages()`
#' resolves the package's imports. The call fails loudly when a local package
#' does not end up installed.
#'
#' The bundled R's lazy-load subprocess can crash at process exit (a Windows
#' DLL-unload fault in the dependency stack, e.g. rlang) after it has already
#' written the lazy-load database, which makes `R CMD INSTALL` report a spurious
#' "lazy loading failed" and a non-zero exit. We therefore install with
#' `--no-staged-install --no-clean-on-error` (so every file lands directly in
#' the final library and the complete package is kept), and verify success by
#' checking that the installed package's metadata and lazy-load database exist
#' instead of trusting the exit status.
#'
#' @param bundled_rscript Character. Path to the bundled `Rscript`.
#' @param local_packages Character vector. Local package paths (directories or archives).
#' @param lib_path Character. Destination library (the bundled library).
#' @param verbose Logical. Whether to display progress.
#' @return Invisibly, the normalised package paths.
#' @keywords internal
install_local_r_packages <- function(bundled_rscript, local_packages, lib_path,
                                     verbose = TRUE) {
  if (length(local_packages) == 0) {
    return(invisible(character(0)))
  }
  paths <- normalizePath(unlist(local_packages), winslash = "/", mustWork = TRUE)
  lib <- gsub("\\\\", "/", lib_path)
  names <- local_r_package_names(paths)
  # Emit paths/names as proper R string literals so an apostrophe or backslash
  # in a path cannot produce an unparsable -e expression.
  r_lit <- function(x) encodeString(x, quote = "'")
  lib_lit <- r_lit(lib)
  pkg_lit <- paste(vapply(paths, r_lit, character(1)), collapse = ", ")
  names_lit <- paste(vapply(names, r_lit, character(1)), collapse = ", ")
  r_code <- sprintf(
    paste0(
      ".libPaths(c(%s, .libPaths())); ",
      "Sys.setenv(R_LIBS = %s, R_LIBS_USER = %s, R_LIBS_SITE = %s); ",
      "install.packages(c(%s), lib = %s, repos = NULL, type = 'source', ",
      "dependencies = FALSE, INSTALL_opts = c('--no-staged-install', '--no-clean-on-error')); ",
      "missing <- setdiff(c(%s), rownames(installed.packages(lib.loc = %s))); ",
      "if (length(missing)) stop('local package install failed: ', paste(missing, collapse = ', '))"
    ),
    lib_lit, lib_lit, lib_lit, lib_lit, pkg_lit, lib_lit, names_lit, lib_lit
  )
  if (verbose) cli::cli_alert_info("Installing local R package(s) from source...")
  result <- processx::run(
    bundled_rscript, c("--vanilla", "-e", r_code),
    env = c(R_LIBS = lib, R_LIBS_USER = lib, R_LIBS_SITE = lib),
    error_on_status = FALSE, echo = verbose, timeout = 600
  )
  present <- vapply(names, function(nm) {
    has_loader <- fs::file_exists(fs::path(lib, nm, "R", nm))
    has_rdb <- fs::file_exists(fs::path(lib, nm, "R", paste0(nm, ".rdb")))
    fs::file_exists(fs::path(lib, nm, "DESCRIPTION")) &&
      fs::file_exists(fs::path(lib, nm, "Meta", "package.rds")) &&
      fs::file_exists(fs::path(lib, nm, "NAMESPACE")) &&
      # Packages that opt out of lazy loading (LazyLoad: no) or ship no R code
      # legitimately have no .rdb; require it only when a loader file exists.
      (!has_loader || has_rdb)
  }, logical(1))
  missing <- names[!present]
  if (length(missing) > 0) {
    err_full <- trimws(result$stderr %||% "")
    out_tail <- trimws(result$stdout %||% "")
    if (nchar(out_tail) > 3000) out_tail <- substr(out_tail, nchar(out_tail) - 2999, nchar(out_tail))
    logf <- tempfile("shinyelectron-local-install-", fileext = ".log")
    writeLines(c("== stdout ==", result$stdout, "", "== stderr ==", result$stderr), logf)
    diag_txt <- local_install_diagnostic(bundled_rscript, paths, lib, names)
    cli::cli_abort(c(
      "Failed to install local R package(s) into the bundled library",
      "x" = "Missing after install: {paste(missing, collapse = ', ')}",
      "x" = "Paths: {.path {paths}}",
      "i" = "log: {.path {logf}}",
      "x" = "stderr: {err_full}",
      "i" = "stdout tail: {out_tail}",
      "i" = "lazy-load diagnostic: {diag_txt}"
    ))
  }
  if (verbose) cli::cli_alert_info(
    "Installed local R package(s) from source (a benign R CMD INSTALL exit code is expected and ignored)"
  )
  invisible(paths)
}
local_install_diagnostic <- function(bundled_rscript, paths, lib, names) {
  pkgname <- names[[1]]
  lit <- function(x) encodeString(x, quote = "'")
  diag_code <- sprintf(
    paste0(
      ".libPaths(c(%s, .libPaths())); ",
      "Sys.setenv(R_LIBS = %s, R_LIBS_USER = %s, R_LIBS_SITE = %s); ",
      "td <- tempfile('seldiag'); dir.create(td); ",
      "utils::untar(%s, exdir = td); ",
      "setwd(file.path(td, %s)); ",
      "cat('LIBS:', paste(.libPaths(), collapse = ' | ')); ",
      "res1 <- tryCatch({ suppressPackageStartupMessages(.getRequiredPackages(quietly = TRUE)); 'OK' }, error = function(e) paste('ERR', conditionMessage(e))); ",
      "cat(' GETREQ:', res1); ",
      "cat(' LIBPKGS:', paste(intersect(list.dirs(%s, recursive = FALSE, full.names = FALSE), c('Seurat','SeuratObject','ggplot2','dplyr','shiny','rlang','DT','qs2','shinyjqui')), collapse = ',')); ",
      "cat(' NSLOADED:', paste(intersect(loadedNamespaces(), c('Seurat','SeuratObject','ggplot2','dplyr','shiny','rlang')), collapse = ',')); ",
      "cat(' DONE')"
    ),
    lit(lib), lit(lib), lit(lib), lit(lib), lit(paths[[1]]), lit(pkgname), lit(lib)
  )
  diag <- processx::run(
    bundled_rscript, c("--vanilla", "-e", diag_code),
    env = c(R_LIBS = lib, R_LIBS_USER = lib, R_LIBS_SITE = lib),
    error_on_status = FALSE, timeout = 600
  )
  paste0("[status ", diag$status, "] [stdout] ", trimws(diag$stdout %||% ""),
         " [stderr] ", trimws(diag$stderr %||% ""))
}
