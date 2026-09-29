test_that("export validates R app structure for r-shiny type", {
  tmpdir <- tempfile()
  dir.create(tmpdir)
  on.exit(unlink(tmpdir, recursive = TRUE))

  # No app.R or server.R -- should fail at app structure validation
  expect_error(
    export(appdir = tmpdir, destdir = tempfile(), app_type = "r-shiny",
           build = FALSE, verbose = FALSE),
    "app.R|server.R"
  )
})

test_that("export copies app source for r-shiny without conversion", {
  skip_if_not_installed("renv")
  tmpdir <- tempfile()
  dir.create(tmpdir)
  writeLines("library(shiny)\nshinyApp(ui = fluidPage(), server = function(input, output) {})",
             file.path(tmpdir, "app.R"))
  outdir <- tempfile()
  on.exit(unlink(c(tmpdir, outdir), recursive = TRUE))

  # Mock build_electron_app to avoid needing Node.js
  mockery::stub(export, "build_electron_app", function(...) tempdir())

  result <- export(appdir = tmpdir, destdir = outdir, app_type = "r-shiny",
                   runtime_strategy = "system", build = TRUE, verbose = FALSE)

  # Verify the app was copied (not shinylive-converted)
  expect_true(fs::dir_exists(fs::path(outdir, "shiny-app")))
  expect_true(fs::file_exists(fs::path(outdir, "shiny-app", "app.R")))
  # No shinylive-app directory should exist
  expect_false(fs::dir_exists(fs::path(outdir, "shinylive-app")))
})

test_that("export defaults runtime_strategy to shinylive when NULL", {
  tmpdir <- tempfile()
  dir.create(tmpdir)
  writeLines("library(shiny)\nshinyApp(ui = fluidPage(), server = function(input, output) {})",
             file.path(tmpdir, "app.R"))
  outdir <- tempfile()
  on.exit(unlink(c(tmpdir, outdir), recursive = TRUE))

  build_rec <- mockery::mock(tempdir())
  mockery::stub(export, "build_electron_app", build_rec)
  # Stub the shinylive conversion too: it depends on pkgcache, which
  # complains under R CMD check (R_USER_CACHE_DIR is unset there) and is
  # not the behaviour under test here.
  mockery::stub(export, "convert_app_to_shinylive", function(...) tempdir())

  export(appdir = tmpdir, destdir = outdir, app_type = "r-shiny",
         runtime_strategy = NULL, build = TRUE, verbose = FALSE)

  expect_equal(mockery::mock_args(build_rec)[[1]]$runtime_strategy, "shinylive")
})

test_that("export passes system strategy to build_electron_app", {
  skip_if_not_installed("renv")
  tmpdir <- tempfile()
  dir.create(tmpdir)
  writeLines("library(shiny)\nshinyApp(ui = fluidPage(), server = function(input, output) {})",
             file.path(tmpdir, "app.R"))
  outdir <- tempfile()
  on.exit(unlink(c(tmpdir, outdir), recursive = TRUE))

  build_rec <- mockery::mock(tempdir())
  mockery::stub(export, "build_electron_app", build_rec)

  export(appdir = tmpdir, destdir = outdir, app_type = "r-shiny",
         runtime_strategy = "system", build = TRUE, verbose = FALSE)

  expect_equal(mockery::mock_args(build_rec)[[1]]$runtime_strategy, "system")
})
