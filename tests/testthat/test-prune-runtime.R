# A small embedded runtime/R tree laid out like a real bundled build: one
# installed package in the sibling library, and a portable R distribution with
# its own doc/, tests/ and library of base and recommended packages.
local_runtime_fixture <- function(env = parent.frame()) {
  root <- withr::local_tempdir("prune-runtime-", .local_envir = env)
  files <- c(
    # A package installed into the bundled library.
    paste0("library/pkgA/", c(
      "DESCRIPTION", "NAMESPACE", "NEWS.md", "R/pkgA.rdb", "libs/pkgA.so",
      "help/pkgA.rdb", "include/pkgA.h", "examples/app.R", "demo/intro.R",
      "tests/testthat.R", "tests/testthat/test-a.R", "testme/test-b.R",
      "tinytest/test-c.R"
    )),
    # The portable R distribution (R_HOME).
    paste0("portable-r-9.9.9-macos-arm64/", c(
      "COPYING", "bin/Rscript", "include/R.h", "share/zoneinfo/UTC",
      "tests/reg-tests-1a.R", "tests/Examples/base-Ex.R",
      "doc/COPYING", "doc/COPYRIGHTS", "doc/AUTHORS", "doc/THANKS",
      "doc/RESOURCES", "doc/CRAN_mirrors.csv", "doc/BioC_mirrors.csv",
      "doc/KEYWORDS", "doc/KEYWORDS.db", "doc/html/index.html",
      "doc/html/R.css", "doc/manual/R-intro.pdf", "doc/NEWS", "doc/NEWS.rds",
      "doc/NEWS.pdf", "doc/FAQ",
      # Base and recommended packages in the portable R's own library.
      "library/base/DESCRIPTION", "library/stats/DESCRIPTION",
      "library/stats/demo/nlm.R", "library/survival/DESCRIPTION",
      "library/survival/NEWS.Rd", "library/survival/tests/survfit.R"
    ))
  )
  for (f in file.path(root, files)) {
    dir.create(dirname(f), recursive = TRUE, showWarnings = FALSE)
    writeLines(paste("contents of", basename(f)), f)
  }
  root
}

# Paths prune_bundled_r_runtime() must remove from the fixture, and a selection
# of neighbours it must keep.
fixture_removed <- function(root) {
  pkg <- file.path(root, "library", "pkgA")
  r_home <- file.path(root, "portable-r-9.9.9-macos-arm64")
  c(
    file.path(pkg, c("tests", "testme", "tinytest")),
    file.path(r_home, "tests"),
    file.path(r_home, "doc", c("html", "manual", "NEWS", "NEWS.rds", "NEWS.pdf", "FAQ")),
    file.path(r_home, "library", "survival", "tests")
  )
}

fixture_kept <- function(root) {
  pkg <- file.path(root, "library", "pkgA")
  r_home <- file.path(root, "portable-r-9.9.9-macos-arm64")
  c(
    file.path(pkg, c("DESCRIPTION", "NAMESPACE", "NEWS.md", "R", "libs", "help",
                     "include", "examples", "demo")),
    file.path(r_home, c("COPYING", "bin", "include", "share")),
    file.path(r_home, "doc", c("COPYING", "COPYRIGHTS", "AUTHORS", "THANKS",
                               "RESOURCES", "CRAN_mirrors.csv", "BioC_mirrors.csv",
                               "KEYWORDS", "KEYWORDS.db")),
    file.path(r_home, "library", c("base", "stats/DESCRIPTION", "stats/demo",
                                   "survival/DESCRIPTION", "survival/NEWS.Rd"))
  )
}

# The regular files at or below `paths`.
regular_files <- function(paths) {
  unlist(lapply(paths, function(p) {
    if (dir.exists(p)) list.files(p, recursive = TRUE, full.names = TRUE, all.files = TRUE) else p
  }))
}

test_that("prune_bundled_r_runtime removes only allowlisted test and documentation files", {
  root <- local_runtime_fixture()
  removed <- fixture_removed(root)
  kept <- fixture_kept(root)
  expected <- regular_files(removed)
  expected_bytes <- sum(file.size(expected))

  res <- prune_bundled_r_runtime(root, verbose = FALSE)

  expect_equal(removed[file.exists(removed)], character(0))
  expect_equal(kept[!file.exists(kept)], character(0))
  expect_equal(res$files, length(expected))
  expect_equal(res$bytes, expected_bytes)
})

test_that("prune_bundled_r_runtime reports what it removed", {
  root <- local_runtime_fixture()
  n <- length(regular_files(fixture_removed(root)))
  expect_message(
    prune_bundled_r_runtime(root, verbose = TRUE),
    paste("Removed", n, "test and documentation files")
  )
  # Nothing left to remove the second time round, so nothing is reported.
  expect_silent(res <- prune_bundled_r_runtime(root, verbose = TRUE))
  expect_equal(res$files, 0L)
})

test_that("prune_bundled_r_runtime removes symbolic links without following them", {
  root <- local_runtime_fixture()
  expected <- regular_files(fixture_removed(root))
  expected_bytes <- sum(file.size(expected))

  outside <- withr::local_tempdir("prune-outside-")
  outside_file <- file.path(outside, "data.R")
  writeLines("outside the runtime", outside_file)
  Sys.chmod(outside_file, "600")
  outside_mode <- file.mode(outside_file)

  pkg_tests <- file.path(root, "library", "pkgA", "tests")
  dir.create(file.path(root, "library", "pkgB"))
  linked <- suppressWarnings(c(
    # Links inside a directory that is pruned...
    file.symlink(outside, file.path(pkg_tests, "outside-dir")),
    file.symlink(outside_file, file.path(pkg_tests, "outside-file")),
    # ...and a pruned name that is itself a link out of the tree.
    file.symlink(outside, file.path(root, "library", "pkgB", "tests"))
  ))
  skip_if_not(all(linked), "Symbolic links are not supported on this system")

  res <- prune_bundled_r_runtime(root, verbose = FALSE)

  # The links are gone; what they pointed to is untouched and not counted.
  expect_false(file.exists(pkg_tests))
  expect_false(fs::link_exists(file.path(root, "library", "pkgB", "tests")))
  expect_true(dir.exists(file.path(root, "library", "pkgB")))
  expect_equal(readLines(outside_file), "outside the runtime")
  expect_equal(file.mode(outside_file), outside_mode)
  expect_equal(res$files, length(expected))
  expect_equal(res$bytes, expected_bytes)
})

test_that("prune_bundled_r_runtime removes read-only test directories", {
  skip_on_os("windows")
  root <- local_runtime_fixture()
  locked <- file.path(root, "library", "pkgA", "tests", "testthat")
  Sys.chmod(file.path(locked, "test-a.R"), "444")
  Sys.chmod(locked, "555")

  prune_bundled_r_runtime(root, verbose = FALSE)

  expect_false(dir.exists(file.path(root, "library", "pkgA", "tests")))
})

test_that("prune_r_paths matches exact names of the right type", {
  pkg <- withr::local_tempdir("prune-pkg-")
  dir.create(file.path(pkg, "Tests"))                 # different case
  writeLines("x", file.path(pkg, "Tests", "a.R"))
  writeLines("x", file.path(pkg, "tinytest"))         # a file, not a directory
  dir.create(file.path(pkg, "NEWS"))                  # a directory, not a file
  writeLines("x", file.path(pkg, "NEWS", "b.R"))
  dir.create(file.path(pkg, "testme"))
  writeLines("x", file.path(pkg, "testme", "c.R"))

  res <- prune_r_paths(pkg, dir_names = c("tests", "tinytest", "testme"),
                       file_names = "NEWS")

  expect_equal(res$files, 1L)
  expect_false(dir.exists(file.path(pkg, "testme")))
  expect_true(file.exists(file.path(pkg, "Tests", "a.R")))
  expect_true(file.exists(file.path(pkg, "tinytest")))
  expect_true(file.exists(file.path(pkg, "NEWS", "b.R")))
})

test_that("pruning counts only files that are actually removed", {
  skip_if_not_installed("mockery")
  pkg <- withr::local_tempdir("prune-pkg-")
  dir.create(file.path(pkg, "tests"))
  writeLines("x", file.path(pkg, "tests", "t.R"))

  # A delete that silently fails, as when another process holds the files.
  mockery::stub(remove_pruned_path, "unlink", function(...) 1L)
  res <- remove_pruned_path(file.path(pkg, "tests"))

  expect_true(file.exists(file.path(pkg, "tests", "t.R")))
  expect_equal(res$files, 0L)
  expect_equal(res$bytes, 0)
})

test_that("prune_bundled_r_runtime is a no-op for a missing runtime directory", {
  res <- prune_bundled_r_runtime(tempfile("missing-runtime-"), verbose = FALSE)
  expect_equal(res$files, 0L)
  expect_equal(res$bytes, 0)
})

test_that("embed_r_runtime prunes by default and keeps everything with prune = FALSE", {
  skip_if_not_installed("mockery")
  cached <- local_runtime_fixture()
  mockery::stub(embed_r_runtime, "install_r_portable", function(...) cached)
  mockery::stub(embed_r_runtime, "copy_dir_contents", function(src, dst) {
    fs::dir_copy(src, dst)
    invisible(dst)
  })

  embed <- function(...) {
    out <- withr::local_tempdir(.local_envir = parent.frame())
    embed_r_runtime(
      output_dir = out, packages = character(0),
      repos = "https://cloud.r-project.org", version = "9.9.9",
      platform = "mac", arch = "arm64", verbose = FALSE, ...
    )
  }

  pruned <- embed()
  expect_equal(fixture_removed(pruned)[file.exists(fixture_removed(pruned))], character(0))
  expect_equal(fixture_kept(pruned)[!file.exists(fixture_kept(pruned))], character(0))

  unpruned <- embed(prune = FALSE)
  expect_true(all(file.exists(fixture_removed(unpruned))))
})

test_that("embed_r_runtime checks prune before downloading or copying a runtime", {
  skip_if_not_installed("mockery")
  calls <- character(0)
  mockery::stub(embed_r_runtime, "install_r_portable", function(...) {
    calls <<- c(calls, "install_r_portable")
    tempfile()
  })
  mockery::stub(embed_r_runtime, "copy_dir_contents", function(...) {
    calls <<- c(calls, "copy_dir_contents")
    invisible(NULL)
  })

  expect_error(
    embed_r_runtime(
      output_dir = withr::local_tempdir(), packages = character(0),
      repos = "https://cloud.r-project.org", version = "9.9.9",
      platform = "mac", arch = "arm64", verbose = FALSE, prune = "yes"
    ),
    "prune"
  )
  expect_equal(calls, character(0))
})

test_that("dependencies.r.prune defaults to TRUE and is read from the config file", {
  expect_true(SHINYELECTRON_DEFAULTS$dependencies$r$prune)
  expect_true(resolve_r_prune(default_config()))
  expect_true(resolve_r_prune(NULL))

  appdir <- withr::local_tempdir()
  cfg_file <- file.path(appdir, "_shinyelectron.yml")

  writeLines(c("dependencies:", "  r:", "    prune: false"), cfg_file)
  expect_false(resolve_r_prune(read_config(appdir)))

  writeLines(c("dependencies:", "  r:", "    prune: no"), cfg_file)
  expect_false(resolve_r_prune(read_config(appdir)))

  # null means "use the default".
  writeLines(c("dependencies:", "  r:", "    prune: null"), cfg_file)
  expect_true(resolve_r_prune(read_config(appdir)))
})

test_that("an invalid dependencies.r.prune aborts instead of guessing", {
  appdir <- withr::local_tempdir()
  cfg_file <- file.path(appdir, "_shinyelectron.yml")

  for (value in c('"false"', "1", "[true, false]", ".na")) {
    writeLines(c("dependencies:", "  r:", paste("    prune:", value)), cfg_file)
    expect_error(read_config(appdir), "dependencies.r.prune", info = value)
  }

  expect_error(
    validate_config(list(dependencies = list(r = list(prune = "yes")))),
    "dependencies.r.prune"
  )
  expect_error(resolve_r_prune(list(dependencies = list(r = list(prune = NA)))),
               "dependencies.r.prune")
})
