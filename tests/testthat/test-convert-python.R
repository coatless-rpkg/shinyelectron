test_that("convert_py_to_shinylive validates inputs", {
  expect_error(
    convert_py_to_shinylive("/nonexistent/path", tempdir()),
    "does not exist"
  )
})

test_that("convert_py_to_shinylive validates Python app structure", {
  tmpdir <- tempfile()
  dir.create(tmpdir)
  on.exit(unlink(tmpdir, recursive = TRUE))

  expect_error(
    convert_py_to_shinylive(tmpdir, tempfile()),
    "app.py"
  )
})

test_that("convert_py_to_shinylive checks Python availability", {
  tmpdir <- tempfile()
  dir.create(tmpdir)
  writeLines("from shiny import App", file.path(tmpdir, "app.py"))
  on.exit(unlink(tmpdir, recursive = TRUE))

  mockery::stub(convert_py_to_shinylive, "validate_python_available",
                function() cli::cli_abort("Python is required"))
  expect_error(
    convert_py_to_shinylive(tmpdir, tempfile()),
    "Python is required"
  )
})

test_that("convert_py_to_shinylive checks shinylive package", {
  tmpdir <- tempfile()
  dir.create(tmpdir)
  writeLines("from shiny import App", file.path(tmpdir, "app.py"))
  on.exit(unlink(tmpdir, recursive = TRUE))

  mockery::stub(convert_py_to_shinylive, "validate_python_available",
                function() invisible(TRUE))
  mockery::stub(convert_py_to_shinylive, "validate_python_shinylive_installed",
                function() cli::cli_abort("shinylive Python package required"))
  expect_error(
    convert_py_to_shinylive(tmpdir, tempfile()),
    "shinylive.*Python package"
  )
})

test_that("convert_py_to_shinylive calls Python shinylive CLI", {
  tmpdir <- tempfile()
  dir.create(tmpdir)
  writeLines("from shiny import App", file.path(tmpdir, "app.py"))
  outdir <- tempfile()
  on.exit(unlink(c(tmpdir, outdir), recursive = TRUE))

  mockery::stub(convert_py_to_shinylive, "validate_python_available",
                function() invisible(TRUE))
  mockery::stub(convert_py_to_shinylive, "validate_python_shinylive_installed",
                function() invisible(TRUE))

  run_called_with <- NULL
  mockery::stub(convert_py_to_shinylive, "processx::run", function(command, args, ...) {
    run_called_with <<- list(command = command, args = args)
    dir.create(outdir, recursive = TRUE, showWarnings = FALSE)
    writeLines("<html></html>", file.path(outdir, "index.html"))
    dir.create(file.path(outdir, "shinylive"), showWarnings = FALSE)
    list(status = 0, stdout = "", stderr = "")
  })
  # Mock Sys.which so it finds the shinylive CLI
  mockery::stub(convert_py_to_shinylive, "Sys.which",
                function(cmd) if (cmd == "shinylive") "/usr/bin/shinylive" else "")

  result <- convert_py_to_shinylive(tmpdir, outdir, verbose = FALSE)

  # Should use shinylive CLI directly: shinylive export <appdir> <outdir>
  expect_equal(run_called_with$command, "shinylive")
  expect_equal(run_called_with$args[1], "export")
})

test_that("convert_py_to_shinylive rejects overwrite when dir exists", {
  tmpdir <- tempfile()
  dir.create(tmpdir)
  writeLines("from shiny import App", file.path(tmpdir, "app.py"))
  outdir <- tempfile()
  dir.create(outdir)
  on.exit(unlink(c(tmpdir, outdir), recursive = TRUE))

  expect_error(
    convert_py_to_shinylive(tmpdir, outdir, overwrite = FALSE),
    "already exists"
  )
})
