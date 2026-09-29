make_runtime_fixture <- function() {
  root <- tempfile("prune-runtime-")
  dir.create(root)

  lib <- file.path(root, "library", "pkgA")
  for (d in c("R", "libs", "help", "include", "tests", "examples")) {
    dir.create(file.path(lib, d), recursive = TRUE)
  }
  for (f in c("DESCRIPTION", "NEWS.md", "R/a.R", "libs/a.dll", "help/a.rdb",
              "include/a.h", "tests/t.R", "examples/e.R")) {
    file.create(file.path(lib, f))
  }

  pr <- file.path(root, "portable-r-9.9.9-win-x64")
  dir.create(file.path(pr, "bin"), recursive = TRUE)
  for (d in c("doc", "tests", "include", "Tcl")) dir.create(file.path(pr, d))
  dir.create(file.path(pr, "share", "zoneinfo"), recursive = TRUE)
  dir.create(file.path(pr, "library", "base"), recursive = TRUE)
  for (f in c("bin/Rscript.exe", "doc/d", "tests/t", "include/h", "Tcl/x",
              "share/zoneinfo/z", "library/base/DESCRIPTION")) {
    file.create(file.path(pr, f))
  }

  root
}

test_that("prune_r_paths removes only allowlisted names", {
  dir <- tempfile("prune-paths-")
  pkg <- file.path(dir, "pkg")
  dir.create(file.path(pkg, "keep"), recursive = TRUE)
  dir.create(file.path(pkg, "include"))
  dir.create(file.path(pkg, "tests"))
  file.create(file.path(pkg, "keep", "k"))
  file.create(file.path(pkg, "include", "a.h"))
  file.create(file.path(pkg, "tests", "t.R"))
  file.create(file.path(pkg, "NEWS.md"))
  on.exit(unlink(dir, recursive = TRUE), add = TRUE)

  res <- prune_r_paths(pkg, c("include", "tests"), c("NEWS.md"))

  expect_equal(res$files, 3L)
  expect_false(dir.exists(file.path(pkg, "include")))
  expect_false(dir.exists(file.path(pkg, "tests")))
  expect_false(file.exists(file.path(pkg, "NEWS.md")))
  expect_true(dir.exists(file.path(pkg, "keep")))
})

test_that("prune_bundled_r_runtime prunes allowlists and keeps runtime files", {
  root <- make_runtime_fixture()
  on.exit(unlink(root, recursive = TRUE), add = TRUE)

  res <- prune_bundled_r_runtime(root, verbose = FALSE)

  pkg <- file.path(root, "library", "pkgA")
  expect_true(dir.exists(file.path(pkg, "include")))   # headers are kept
  expect_false(dir.exists(file.path(pkg, "tests")))
  expect_false(dir.exists(file.path(pkg, "examples")))
  expect_false(file.exists(file.path(pkg, "NEWS.md")))
  expect_true(dir.exists(file.path(pkg, "R")))
  expect_true(dir.exists(file.path(pkg, "libs")))
  expect_true(dir.exists(file.path(pkg, "help")))
  expect_true(file.exists(file.path(pkg, "DESCRIPTION")))

  pr <- file.path(root, "portable-r-9.9.9-win-x64")
  expect_false(dir.exists(file.path(pr, "doc")))
  expect_false(dir.exists(file.path(pr, "tests")))
  expect_true(dir.exists(file.path(pr, "include")))   # headers are kept
  expect_true(dir.exists(file.path(pr, "Tcl")))
  expect_true(dir.exists(file.path(pr, "share", "zoneinfo")))
  expect_true(dir.exists(file.path(pr, "library", "base")))
  expect_true(file.exists(file.path(pr, "bin", "Rscript.exe")))

  expect_true(res$files > 0)
})

test_that("prune_bundled_r_runtime honours opt-out flags", {
  root <- make_runtime_fixture()
  on.exit(unlink(root, recursive = TRUE), add = TRUE)

  prune_bundled_r_runtime(root, prune_library = FALSE, prune_portable = FALSE,
                          verbose = FALSE)

  expect_true(dir.exists(file.path(root, "library", "pkgA", "include")))
  expect_true(dir.exists(file.path(root, "portable-r-9.9.9-win-x64", "doc")))
})

test_that("prune_bundled_r_runtime is a no-op for a missing runtime directory", {
  res <- prune_bundled_r_runtime(tempfile("missing-runtime-"), verbose = FALSE)
  expect_equal(res$files, 0L)
  expect_equal(res$bytes, 0)
})