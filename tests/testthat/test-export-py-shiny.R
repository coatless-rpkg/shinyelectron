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

test_that("export defaults runtime_strategy to shinylive for py-shiny when NULL", {
  skip_if_not(py_shinylive_available(), "Python shinylive CLI not available")
  tmpdir <- tempfile()
  dir.create(tmpdir)
  writeLines("from shiny import App", file.path(tmpdir, "app.py"))
  outdir <- tempfile()
  on.exit(unlink(c(tmpdir, outdir), recursive = TRUE))

  build_rec <- mockery::mock()
  mockery::stub(export, "build_electron_app", function(...) {
    build_rec(...)
    tempdir()
  })

  export(appdir = tmpdir, destdir = outdir, app_type = "py-shiny",
         runtime_strategy = NULL, build = TRUE, verbose = FALSE)

  expect_equal(mockery::mock_args(build_rec)[[1]]$runtime_strategy, "shinylive")
})

test_that("export passes system strategy for py-shiny", {
  tmpdir <- tempfile()
  dir.create(tmpdir)
  writeLines("from shiny import App", file.path(tmpdir, "app.py"))
  outdir <- tempfile()
  on.exit(unlink(c(tmpdir, outdir), recursive = TRUE))

  build_rec <- mockery::mock()
  mockery::stub(export, "build_electron_app", function(...) {
    build_rec(...)
    tempdir()
  })
  mockery::stub(export, "validate_python_available", function() invisible(TRUE))

  # Warns about missing requirements.txt -- expected since we only test strategy passthrough
  expect_warning(
    export(appdir = tmpdir, destdir = outdir, app_type = "py-shiny",
           runtime_strategy = "system", build = TRUE, verbose = FALSE),
    "requirements.txt"
  )

  expect_equal(mockery::mock_args(build_rec)[[1]]$runtime_strategy, "system")
})

test_that("write_runtime_manifest uses pin version and release when python config is unset", {
  skip_if_not_installed("mockery")

  tmpdir <- tempfile()
  dir.create(tmpdir)
  on.exit(unlink(tmpdir, recursive = TRUE))

  config <- list(dependencies = list())

  manifest_rec <- mockery::mock()

  # The default pin matches the offline short-circuit in resolve_python_pbs;
  # no network stub needed. Stub only generate_python_runtime_manifest to
  # capture what version and release_date are forwarded.

  # Capture what generate_python_runtime_manifest receives
  mockery::stub(write_runtime_manifest, "generate_python_runtime_manifest",
    function(version, platform = NULL, arch = NULL, release_date = NULL) {
      manifest_rec(version = version, release_date = release_date)
      '{"schema_version":"1.0"}'
    }
  )

  write_runtime_manifest(tmpdir, "py-shiny", "mac", "arm64", config, verbose = FALSE)

  manifest_args <- mockery::mock_args(manifest_rec)[[1]]
  expect_equal(manifest_args$version, SHINYELECTRON_DEFAULTS$runtime_versions$python$version)
  expect_equal(manifest_args$release_date, SHINYELECTRON_DEFAULTS$runtime_versions$python$release)
})
