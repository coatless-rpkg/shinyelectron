# Direct coverage for the default-strategy R shinylive converter. Gated on the
# shinylive package (and skipped under R CMD check) via r_shinylive_available().

test_that("convert_shiny_to_shinylive produces a shinylive app directory", {
  skip_if_not(r_shinylive_available(), "shinylive not available")

  appdir <- tempfile("app-")
  dir.create(appdir)
  on.exit(unlink(appdir, recursive = TRUE), add = TRUE)
  writeLines(
    "library(shiny)\nshinyApp(ui = fluidPage(), server = function(input, output) {})",
    file.path(appdir, "app.R")
  )

  outdir <- tempfile("out-")
  on.exit(unlink(outdir, recursive = TRUE), add = TRUE)

  result <- convert_shiny_to_shinylive(appdir, outdir, overwrite = TRUE,
                                       verbose = FALSE)

  expect_true(dir.exists(result))
  # A shinylive export writes an index.html entrypoint and assets.
  expect_true(file.exists(file.path(result, "index.html")))
})

test_that("convert_shiny_to_shinylive validates the app structure", {
  appdir <- tempfile("app-")
  dir.create(appdir)
  on.exit(unlink(appdir, recursive = TRUE), add = TRUE)
  # No app.R / server.R+ui.R present.
  expect_error(
    convert_shiny_to_shinylive(appdir, tempfile("out-"), verbose = FALSE)
  )
})

test_that("convert_shiny_to_shinylive cleans up temp dir on export failure", {
  # Strategy: stub copy_dir_contents to record the temp_app_dir path (and
  # create it so it physically exists), stub shinylive::export to throw, then
  # assert the recorded temp dir was removed by the on.exit handler.
  appdir <- tempfile("app-")
  dir.create(appdir)
  on.exit(unlink(appdir, recursive = TRUE), add = TRUE)
  writeLines(
    "library(shiny)\nshinyApp(ui = fluidPage(), server = function(input, output) {})",
    file.path(appdir, "app.R")
  )

  outdir <- tempfile("out-")
  on.exit(unlink(outdir, recursive = TRUE), add = TRUE)

  recorded_temp_dir <- NULL

  # Intercept the copy so we learn the temp path and create it on disk.
  mockery::stub(convert_shiny_to_shinylive, "copy_dir_contents", function(from, to) {
    recorded_temp_dir <<- to
    dir.create(to, recursive = TRUE, showWarnings = FALSE)
  })

  # Make shinylive available so the requireNamespace guard passes.
  mockery::stub(convert_shiny_to_shinylive, "requireNamespace",
                function(pkg, ...) TRUE)

  # Force the export step to throw.
  mockery::stub(convert_shiny_to_shinylive, "shinylive::export",
                function(...) stop("simulated export failure"))

  expect_error(
    convert_shiny_to_shinylive(appdir, outdir, verbose = FALSE),
    "simulated export failure"
  )

  # Temp dir must have been cleaned up (not just on success).
  expect_false(is.null(recorded_temp_dir),
               label = "copy_dir_contents stub was called")
  expect_false(dir.exists(recorded_temp_dir),
               label = "temp_app_dir was removed on error path")
})

test_that("convert_shiny_to_shinylive threads subdir to export, is additive, validates subdir", {
  appdir <- tempfile("app-")
  dir.create(appdir)
  on.exit(unlink(appdir, recursive = TRUE), add = TRUE)
  writeLines(
    "library(shiny)\nshinyApp(ui = fluidPage(), server = function(input, output) {})",
    file.path(appdir, "app.R")
  )

  outdir <- tempfile("site-")
  on.exit(unlink(outdir, recursive = TRUE), add = TRUE)
  # Pre-populate the shared site: a sentinel must SURVIVE a subdir export.
  dir.create(outdir, recursive = TRUE)
  writeLines("keep", file.path(outdir, "sentinel.txt"))

  export_args <- NULL
  mockery::stub(convert_shiny_to_shinylive, "requireNamespace",
                function(pkg, ...) TRUE)
  mockery::stub(convert_shiny_to_shinylive, "shinylive::export",
                function(appdir, destdir, subdir = "", quiet = TRUE, ...) {
                  export_args <<- list(destdir = destdir, subdir = subdir)
                  dir.create(file.path(destdir, "shinylive"), showWarnings = FALSE)
                  dir.create(file.path(destdir, subdir), recursive = TRUE,
                             showWarnings = FALSE)
                  writeLines("<html></html>",
                             file.path(destdir, subdir, "index.html"))
                  invisible(destdir)
                })

  result <- convert_shiny_to_shinylive(appdir, outdir, subdir = "alpha",
                                       verbose = FALSE)

  expect_equal(export_args$subdir, "alpha")                 # subdir threaded
  expect_true(file.exists(file.path(outdir, "sentinel.txt"))) # additive, no unlink
  expect_equal(fs::path_abs(result), fs::path_abs(outdir))    # subdir-aware validate passed
})

test_that("convert_shiny_to_shinylive single-app (subdir=NULL) wipes and validates at root", {
  appdir <- tempfile("app-")
  dir.create(appdir)
  on.exit(unlink(appdir, recursive = TRUE), add = TRUE)
  writeLines(
    "library(shiny)\nshinyApp(ui = fluidPage(), server = function(input, output) {})",
    file.path(appdir, "app.R")
  )

  outdir <- tempfile("out-")
  on.exit(unlink(outdir, recursive = TRUE), add = TRUE)
  dir.create(outdir, recursive = TRUE)
  writeLines("old", file.path(outdir, "stale.txt"))

  export_args <- NULL
  mockery::stub(convert_shiny_to_shinylive, "requireNamespace",
                function(pkg, ...) TRUE)
  mockery::stub(convert_shiny_to_shinylive, "shinylive::export",
                function(appdir, destdir, subdir = "", quiet = TRUE, ...) {
                  export_args <<- list(subdir = subdir)
                  writeLines("<html></html>", file.path(destdir, "index.html"))
                  dir.create(file.path(destdir, "shinylive"), showWarnings = FALSE)
                  invisible(destdir)
                })

  convert_shiny_to_shinylive(appdir, outdir, overwrite = TRUE, verbose = FALSE)

  expect_equal(export_args$subdir, "")                       # NULL -> "" default kept
  expect_false(file.exists(file.path(outdir, "stale.txt")))  # overwrite still wipes
})
