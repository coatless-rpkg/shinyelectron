# Names removed from every installed R package (allowlist). These are tests,
# examples and changelogs only. `include/` (C/C++ headers) is deliberately
# KEPT: a bundled app may compile code at runtime via Rcpp::sourceCpp() or
# rstan, which need the headers. Package code, compiled libs, data, HTML
# widgets and help databases are kept too.
.r_library_prune_dirs <- c("tests", "testme", "tinytest",
                           "examples", "demo")
.r_library_prune_files <- c("NEWS", "NEWS.md", "NEWS.Rd",
                            "CHANGELOG", "CHANGELOG.md")

# Names removed from the portable R distribution (allowlist). `share/` carries
# timezone/encoding data R needs at runtime, `Tcl/` may be needed by tcltk, and
# `include/` holds the R headers used by Rcpp::sourceCpp()/rstan, so all -- along
# with bin/, etc/, modules/, library/ and src/ -- are kept.
.r_runtime_prune_dirs <- c("doc", "tests")

#' Remove allowlisted paths under one directory
#'
#' Only names that appear in `dir_names` / `file_names` are removed; anything
#' else is left untouched.
#'
#' @param dir Character. Directory to prune.
#' @param dir_names,file_names Character vectors of names to remove.
#' @return List with `files` and `bytes` removed.
#' @keywords internal
prune_r_paths <- function(dir, dir_names = character(0),
                          file_names = character(0)) {
  files <- 0L
  bytes <- 0

  for (name in dir_names) {
    path <- fs::path(dir, name)
    if (fs::dir_exists(path)) {
      info <- fs::dir_info(path, recurse = TRUE, type = "file", fail = FALSE)
      files <- files + nrow(info)
      bytes <- bytes + as.numeric(sum(info$size, na.rm = TRUE))
      unlink(path, recursive = TRUE, force = TRUE)
    }
  }

  for (name in file_names) {
    path <- fs::path(dir, name)
    if (fs::file_exists(path)) {
      files <- files + 1L
      bytes <- bytes + as.numeric(fs::file_size(path))
      unlink(path, force = TRUE)
    }
  }

  list(files = files, bytes = bytes)
}

#' Prune build-only files from an embedded R runtime
#'
#' Reduces installer size and install time by deleting files that are only
#' needed while compiling dependent packages, running tests, or reading
#' offline documentation -- never at application runtime. The set of removed
#' names is a fixed allowlist, so pruning cannot remove package code, compiled
#' libraries, data, HTML widgets or help databases.
#'
#' For the bundled package library it removes, from each installed package:
#' `tests/`, `testme/`, `tinytest/`, `examples/`, `demo/` and root-level
#' `NEWS*` / `CHANGELOG*` files. For the portable R distribution it removes
#' top-level `doc/` and `tests/`. `include/` (C/C++ and R headers needed by
#' `Rcpp::sourceCpp()` / rstan at runtime) is always kept, along with `share/`,
#' `Tcl/`, `bin/`, `etc/`, `modules/`, `library/` and `src/`.
#'
#' @param runtime_dir Character. The embedded `runtime/R` directory.
#' @param prune_library Logical. Prune the bundled package library.
#' @param prune_portable Logical. Prune the portable R distribution.
#' @param verbose Logical. Whether to display progress.
#' @return Invisibly, a list with `files` and `bytes` removed.
#' @keywords internal
prune_bundled_r_runtime <- function(runtime_dir, prune_library = TRUE,
                                    prune_portable = TRUE, verbose = TRUE) {
  runtime_dir <- fs::path(runtime_dir)
  if (!fs::dir_exists(runtime_dir)) {
    return(invisible(list(files = 0L, bytes = 0)))
  }
  total_files <- 0L
  total_bytes <- 0

  if (isTRUE(prune_library)) {
    lib_dir <- fs::path(runtime_dir, "library")
    if (fs::dir_exists(lib_dir)) {
      for (pkg_dir in fs::dir_ls(lib_dir, type = "directory")) {
        res <- prune_r_paths(pkg_dir, .r_library_prune_dirs,
                             .r_library_prune_files)
        total_files <- total_files + res$files
        total_bytes <- total_bytes + res$bytes
      }
    }
  }

  if (isTRUE(prune_portable)) {
    portable_dirs <- fs::dir_ls(runtime_dir, type = "directory")
    portable_dirs <- portable_dirs[startsWith(fs::path_file(portable_dirs),
                                            "portable-r-")]
    for (r_dir in portable_dirs) {
      res <- prune_r_paths(r_dir, .r_runtime_prune_dirs, character(0))
      total_files <- total_files + res$files
      total_bytes <- total_bytes + res$bytes
    }
  }

  if (verbose && total_files > 0) {
    cli::cli_alert_info(
      "Pruned {total_files} build-only file{?s} ({round(total_bytes / 1024^2, 1)} MB) from the bundled R runtime"
    )
  }

  invisible(list(files = total_files, bytes = total_bytes))
}
