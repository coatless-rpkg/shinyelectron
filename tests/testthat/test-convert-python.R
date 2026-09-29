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

  run_rec <- mockery::mock(NULL)
  mockery::stub(convert_py_to_shinylive, "processx::run", function(command, args, ...) {
    run_rec(command = command, args = args)
    dir.create(outdir, recursive = TRUE, showWarnings = FALSE)
    writeLines("<html></html>", file.path(outdir, "index.html"))
    dir.create(file.path(outdir, "shinylive"), showWarnings = FALSE)
    list(status = 0, stdout = "", stderr = "")
  })
  # Mock Sys.which so it finds the shinylive CLI
  mockery::stub(convert_py_to_shinylive, "Sys.which",
                function(cmd) if (cmd == "shinylive") "/usr/bin/shinylive" else "")

  result <- convert_py_to_shinylive(tmpdir, outdir, verbose = FALSE)
  run_called_with <- mockery::mock_args(run_rec)[[1]]

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

test_that("convert_py_to_shinylive adds --subdir for multi-app and is additive", {
  tmpdir <- tempfile(); dir.create(tmpdir)
  writeLines("from shiny import App", file.path(tmpdir, "app.py"))
  outdir <- tempfile("site-"); dir.create(outdir)
  writeLines("keep", file.path(outdir, "sentinel.txt"))
  on.exit(unlink(c(tmpdir, outdir), recursive = TRUE))

  mockery::stub(convert_py_to_shinylive, "validate_python_available",
                function() invisible(TRUE))
  mockery::stub(convert_py_to_shinylive, "validate_python_shinylive_installed",
                function() invisible(TRUE))
  mockery::stub(convert_py_to_shinylive, "Sys.which",
                function(cmd) if (cmd == "shinylive") "/usr/bin/shinylive" else "")

  run_rec <- mockery::mock(NULL)
  mockery::stub(convert_py_to_shinylive, "processx::run", function(command, args, ...) {
    run_rec(args = args)
    dir.create(file.path(outdir, "shinylive"), showWarnings = FALSE)
    dir.create(file.path(outdir, "beta"), recursive = TRUE, showWarnings = FALSE)
    writeLines("<html></html>", file.path(outdir, "beta", "index.html"))
    list(status = 0, stdout = "", stderr = "")
  })

  convert_py_to_shinylive(tmpdir, outdir, subdir = "beta", verbose = FALSE)
  run_args <- mockery::mock_args(run_rec)[[1]]$args

  expect_true("--subdir" %in% run_args)
  idx <- which(run_args == "--subdir")
  expect_equal(run_args[idx + 1], "beta")
  expect_true(file.exists(file.path(outdir, "sentinel.txt"))) # additive, no unlink
})

test_that("convert_py_to_shinylive omits --subdir for single-app", {
  tmpdir <- tempfile(); dir.create(tmpdir)
  writeLines("from shiny import App", file.path(tmpdir, "app.py"))
  outdir <- tempfile()
  on.exit(unlink(c(tmpdir, outdir), recursive = TRUE))

  mockery::stub(convert_py_to_shinylive, "validate_python_available",
                function() invisible(TRUE))
  mockery::stub(convert_py_to_shinylive, "validate_python_shinylive_installed",
                function() invisible(TRUE))
  mockery::stub(convert_py_to_shinylive, "Sys.which",
                function(cmd) if (cmd == "shinylive") "/usr/bin/shinylive" else "")

  run_rec <- mockery::mock(NULL)
  mockery::stub(convert_py_to_shinylive, "processx::run", function(command, args, ...) {
    run_rec(args = args)
    dir.create(outdir, recursive = TRUE, showWarnings = FALSE)
    writeLines("<html></html>", file.path(outdir, "index.html"))
    dir.create(file.path(outdir, "shinylive"), showWarnings = FALSE)
    list(status = 0, stdout = "", stderr = "")
  })

  convert_py_to_shinylive(tmpdir, outdir, verbose = FALSE)
  run_args <- mockery::mock_args(run_rec)[[1]]$args

  expect_false("--subdir" %in% run_args)
})
