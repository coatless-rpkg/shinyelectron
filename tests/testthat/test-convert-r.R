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
