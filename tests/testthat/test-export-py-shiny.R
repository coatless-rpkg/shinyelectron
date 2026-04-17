test_that("export validates Python app structure for py-shiny type", {
  tmpdir <- tempfile()
  dir.create(tmpdir)
  on.exit(unlink(tmpdir, recursive = TRUE))

  expect_error(
    export(appdir = tmpdir, destdir = tempfile(), app_type = "py-shiny",
           build = FALSE, verbose = FALSE),
    "app.py"
  )
})

test_that("export copies app source for py-shiny without conversion", {
  tmpdir <- tempfile()
  dir.create(tmpdir)
  writeLines("from shiny import App, ui\napp = App(ui.page_fluid(), None)",
             file.path(tmpdir, "app.py"))
  writeLines("shiny", file.path(tmpdir, "requirements.txt"))
  outdir <- tempfile()
  on.exit(unlink(c(tmpdir, outdir), recursive = TRUE))

  mockery::stub(export, "build_electron_app", function(...) tempdir())
  mockery::stub(export, "validate_python_available", function() invisible(TRUE))

  result <- export(appdir = tmpdir, destdir = outdir, app_type = "py-shiny",
                   runtime_strategy = "system", build = TRUE, verbose = FALSE)

  expect_true(fs::dir_exists(fs::path(outdir, "shiny-app")))
  expect_true(fs::file_exists(fs::path(outdir, "shiny-app", "app.py")))
  expect_false(fs::dir_exists(fs::path(outdir, "shinylive-app")))
})

test_that("export infers auto-download strategy for py-shiny when NULL", {
  tmpdir <- tempfile()
  dir.create(tmpdir)
  writeLines("from shiny import App", file.path(tmpdir, "app.py"))
  outdir <- tempfile()
  on.exit(unlink(c(tmpdir, outdir), recursive = TRUE))

  captured_strategy <- NULL
  mockery::stub(export, "build_electron_app", function(...) {
    args <- list(...)
    captured_strategy <<- args$runtime_strategy
    tempdir()
  })

  # Warns about missing requirements.txt — expected since we only test strategy inference
  expect_warning(
    export(appdir = tmpdir, destdir = outdir, app_type = "py-shiny",
           runtime_strategy = NULL, build = TRUE, verbose = FALSE),
    "requirements.txt"
  )

  expect_equal(captured_strategy, "auto-download")
})

test_that("export passes system strategy for py-shiny", {
  tmpdir <- tempfile()
  dir.create(tmpdir)
  writeLines("from shiny import App", file.path(tmpdir, "app.py"))
  outdir <- tempfile()
  on.exit(unlink(c(tmpdir, outdir), recursive = TRUE))

  captured_strategy <- NULL
  mockery::stub(export, "build_electron_app", function(...) {
    args <- list(...)
    captured_strategy <<- args$runtime_strategy
    tempdir()
  })
  mockery::stub(export, "validate_python_available", function() invisible(TRUE))

  # Warns about missing requirements.txt — expected since we only test strategy passthrough
  expect_warning(
    export(appdir = tmpdir, destdir = outdir, app_type = "py-shiny",
           runtime_strategy = "system", build = TRUE, verbose = FALSE),
    "requirements.txt"
  )

  expect_equal(captured_strategy, "system")
})
