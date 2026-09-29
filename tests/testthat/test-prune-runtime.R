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
test_that("embed_r_runtime prunes by default and keeps everything with prune = FALSE", {
  skip_if_not_installed("mockery")
  cached <- make_runtime_fixture()
  on.exit(unlink(cached, recursive = TRUE), add = TRUE)
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
  expect_false(dir.exists(file.path(pruned, "library", "pkgA", "tests")))

  unpruned <- embed(prune = FALSE)
  expect_true(dir.exists(file.path(unpruned, "library", "pkgA", "tests")))
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
