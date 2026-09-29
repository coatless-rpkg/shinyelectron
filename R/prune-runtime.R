# What prune_bundled_r_runtime() removes from an embedded R runtime. This is
# an allowlist of exact names: anything not listed is kept. That includes each
# package's `examples/`, `demo/`, NEWS and CHANGELOG files, which some packages
# and apps read at runtime (shinyjs::runExample(), plotly::plotly_example(), a
# "What's new" panel showing NEWS.md via system.file()), and `include/`, which
# Rcpp::sourceCpp() needs.
.r_prune_allowlist <- list(
  # Test suites, removed from every installed package: those in the bundled
  # library and the base and recommended packages in the portable R's library.
  package_dirs = c("tests", "testme", "tinytest"),
  # R's own regression tests at the top of the portable R distribution.
  r_home_dirs = "tests",
  # Manuals, HTML documentation, news and FAQs in the portable R's doc/. The
  # rest of doc/ stays: COPYRIGHTS carries third-party notices that binary
  # distributions of R must include, utils::getCRANmirrors() reads
  # CRAN_mirrors.csv, and base::contributors() prints AUTHORS.
  doc_dirs = c("html", "manual"),
  doc_files = c(
    "NEWS", "NEWS.0", "NEWS.1", "NEWS.2", "NEWS.3", "NEWS.pdf",
    "NEWS.rds", "NEWS.2.rds", "NEWS.3.rds", "FAQ", "rw-FAQ",
    "CHANGES", "CHANGES.rds", "README.packages", "README.Rterm"
  )
)

#' Remove allowlisted entries directly under one directory
#'
#' Matches entry names exactly (case-sensitively). A name in `dir_names` is
#' removed only when it is a directory, and a name in `file_names` only when it
#' is a regular file. A symbolic link with a listed name is removed as a link.
#' Anything else is left untouched, and nothing happens when `dir` is missing or
#' is itself a symbolic link.
#'
#' @param dir Character. Directory to prune.
#' @param dir_names,file_names Character vectors of names to remove.
#' @return List with the number of `files` and `bytes` removed.
#' @keywords internal
prune_r_paths <- function(dir, dir_names = character(0),
                          file_names = character(0)) {
  removed <- list(files = 0L, bytes = 0)
  if (!is_real_dir(dir)) {
    return(removed)
  }

  entries <- fs::dir_info(dir, all = TRUE, fail = FALSE)
  entry_names <- fs::path_file(entries$path)
  entry_types <- as.character(entries$type)
  targets <- entries$path[
    (entry_names %in% dir_names & entry_types %in% c("directory", "symlink")) |
      (entry_names %in% file_names & entry_types %in% c("file", "symlink"))
  ]

  for (path in targets) {
    res <- remove_pruned_path(path)
    removed$files <- removed$files + res$files
    removed$bytes <- removed$bytes + res$bytes
  }

  removed
}

# Remove one file, directory or symbolic link without following links, and
# report the regular files that are actually gone afterwards. A link is removed
# itself; its target is never touched or counted. Links inside a directory are
# removed before the recursive delete, because unlink(force = TRUE) changes the
# permissions of whatever a link points to. Pruning is best effort: if a
# removal fails part-way, the rest stays in place and the counts say so.
remove_pruned_path <- function(path) {
  before <- regular_file_sizes(path)

  tryCatch({
    type <- as.character(fs::file_info(path, fail = FALSE)$type)
    if (identical(type, "symlink")) {
      fs::link_delete(path)
    } else if (identical(type, "directory")) {
      inner <- fs::dir_info(path, recurse = TRUE, all = TRUE, fail = FALSE)
      fs::link_delete(inner$path[inner$type %in% "symlink"])
      unlink(path, recursive = TRUE, force = TRUE)
    } else if (identical(type, "file")) {
      unlink(path, force = TRUE)
    }
  }, error = function(e) NULL)

  after <- regular_file_sizes(path)
  gone <- before[!names(before) %in% names(after)]
  list(files = length(gone), bytes = sum(gone))
}

# Sizes of the regular files at or below `path`, named by path. Symbolic links
# are listed without being followed, so their targets never appear here.
regular_file_sizes <- function(path) {
  info <- fs::file_info(path, fail = FALSE)
  if (identical(as.character(info$type), "directory")) {
    info <- fs::dir_info(path, recurse = TRUE, all = TRUE, fail = FALSE)
  }
  info <- info[info$type %in% "file", ]
  sizes <- as.numeric(info$size)
  names(sizes) <- as.character(info$path)
  sizes
}

# TRUE for each path that is a directory and not a symbolic link to one.
is_real_dir <- function(path) {
  as.character(fs::file_info(path, fail = FALSE)$type) %in% "directory"
}

#' Remove test suites and bulky documentation from an embedded R runtime
#'
#' Shrinks a bundled R runtime by deleting files that a running app does not
#' read. The removed names form a fixed allowlist; everything else is kept.
#'
#' The allowlist covers:
#'
#' * From every installed package, both in the bundled library
#'   (`runtime/R/library`) and among the base and recommended packages in the
#'   portable R's own library: the test suites in `tests/`, `testme/` and
#'   `tinytest/`.
#' * From each portable R distribution (`runtime/R/portable-r-*`): R's
#'   regression tests in `tests/`, and inside `doc/` the `html/` and `manual/`
#'   directories plus R's news, FAQ, `CHANGES` and `README` files.
#'
#' Package `examples/`, `demo/`, NEWS and CHANGELOG files and `include/`
#' headers are kept, because some packages and apps read them at runtime (for
#' example `shinyjs::runExample()`, a "What's new" panel that shows `NEWS.md`
#' via `system.file()`, or `Rcpp::sourceCpp()`). In the portable R's `doc/`,
#' `COPYING`, `COPYRIGHTS` (third-party notices that binary distributions of R
#' must include), `AUTHORS`, `THANKS`, `RESOURCES`, the mirror lists read by
#' `utils::getCRANmirrors()` and the `KEYWORDS` files are kept.
#'
#' Symbolic links are never followed: a link is removed itself, and its target
#' is neither touched nor counted. The totals count only the regular files that
#' are actually gone afterwards.
#'
#' @param runtime_dir Character. The embedded `runtime/R` directory.
#' @param verbose Logical. Whether to report what was removed.
#' @return Invisibly, a list with the number of `files` and `bytes` removed.
#' @keywords internal
prune_bundled_r_runtime <- function(runtime_dir, verbose = TRUE) {
  total <- list(files = 0L, bytes = 0)
  if (!is_real_dir(runtime_dir)) {
    return(invisible(total))
  }
  add <- function(res) {
    total$files <<- total$files + res$files
    total$bytes <<- total$bytes + res$bytes
  }

  allow <- .r_prune_allowlist
  r_homes <- fs::dir_ls(runtime_dir, type = "directory")
  r_homes <- r_homes[startsWith(fs::path_file(r_homes), "portable-r-")]

  for (r_home in r_homes) {
    add(prune_r_paths(r_home, dir_names = allow$r_home_dirs))
    add(prune_r_paths(fs::path(r_home, "doc"), allow$doc_dirs, allow$doc_files))
  }

  libraries <- c(fs::path(runtime_dir, "library"), fs::path(r_homes, "library"))
  for (lib in libraries[is_real_dir(libraries)]) {
    for (pkg_dir in fs::dir_ls(lib, type = "directory")) {
      add(prune_r_paths(pkg_dir, dir_names = allow$package_dirs))
    }
  }

  if (verbose && total$files > 0) {
    cli::cli_alert_info(
      "Removed {total$files} test and documentation file{?s} ({round(total$bytes / 1024^2, 1)} MB) from the bundled R runtime"
    )
  }

  invisible(total)
}

#' Resolve the `dependencies.r.prune` setting
#'
#' Returns whether a bundled R runtime is pruned: the configured value, or
#' `TRUE` when it is unset. A quoted `"true"` or `"false"` is read as the
#' matching logical with a warning, and any other value aborts (see
#' [config_flag()]), so a typo never silently decides which files ship.
#'
#' @param config List. Configuration, as from [read_config()]. May be `NULL`.
#' @return `TRUE` or `FALSE`.
#' @keywords internal
resolve_r_prune <- function(config) {
  config_flag(
    config$dependencies$r$prune,
    "dependencies.r.prune",
    default = SHINYELECTRON_DEFAULTS$dependencies$r$prune
  )
}
