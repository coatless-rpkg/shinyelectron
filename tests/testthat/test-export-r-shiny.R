test_that("export validates R app structure for r-shiny type", {
  tmpdir <- tempfile()
  dir.create(tmpdir)
  on.exit(unlink(tmpdir, recursive = TRUE))

  # No app.R or server.R — should fail at app structure validation
  expect_error(
    export(appdir = tmpdir, destdir = tempfile(), app_type = "r-shiny",
           build = FALSE, verbose = FALSE),
    "app.R|server.R"
  )
})

test_that("export copies app source for r-shiny without conversion", {
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

test_that("export infers auto-download strategy for r-shiny when NULL", {
  # auto-download runs through r_download_url() which aborts on Linux
  # (portable-r has no Linux builds yet).
  skip_on_os("linux")
  tmpdir <- tempfile()
  dir.create(tmpdir)
  writeLines("library(shiny)\nshinyApp(ui = fluidPage(), server = function(input, output) {})",
             file.path(tmpdir, "app.R"))
  outdir <- tempfile()
  on.exit(unlink(c(tmpdir, outdir), recursive = TRUE))

  captured_strategy <- NULL
  mockery::stub(export, "build_electron_app", function(...) {
    args <- list(...)
    captured_strategy <<- args$runtime_strategy
    tempdir()
  })

  export(appdir = tmpdir, destdir = outdir, app_type = "r-shiny",
         runtime_strategy = NULL, build = TRUE, verbose = FALSE)

  expect_equal(captured_strategy, "auto-download")
})

test_that("export passes system strategy to build_electron_app", {
  tmpdir <- tempfile()
  dir.create(tmpdir)
  writeLines("library(shiny)\nshinyApp(ui = fluidPage(), server = function(input, output) {})",
             file.path(tmpdir, "app.R"))
  outdir <- tempfile()
  on.exit(unlink(c(tmpdir, outdir), recursive = TRUE))

  captured_strategy <- NULL
  mockery::stub(export, "build_electron_app", function(...) {
    args <- list(...)
    captured_strategy <<- args$runtime_strategy
    tempdir()
  })

  export(appdir = tmpdir, destdir = outdir, app_type = "r-shiny",
         runtime_strategy = "system", build = TRUE, verbose = FALSE)

  expect_equal(captured_strategy, "system")
})
