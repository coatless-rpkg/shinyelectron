test_that("validate_runtime_strategy accepts valid strategies", {
  expect_silent(validate_runtime_strategy("shinylive"))
  expect_silent(validate_runtime_strategy("bundled"))
  expect_silent(validate_runtime_strategy("system"))
  expect_silent(validate_runtime_strategy("auto-download"))
  expect_silent(validate_runtime_strategy("container"))
})

test_that("validate_runtime_strategy rejects invalid strategies", {
  expect_error(validate_runtime_strategy("invalid"), "Invalid runtime strategy")
  expect_error(validate_runtime_strategy("docker"), "Invalid runtime strategy")
})

test_that("validate_python_app_structure checks for app.py", {
  tmpdir <- tempfile()
  dir.create(tmpdir)
  on.exit(unlink(tmpdir, recursive = TRUE))

  expect_error(validate_python_app_structure(tmpdir), "app.py")

  writeLines("from shiny import App", file.path(tmpdir, "app.py"))
  expect_silent(validate_python_app_structure(tmpdir))
})

test_that("infer_runtime_strategy falls back to shinylive when unset", {
  expect_equal(infer_runtime_strategy(NULL), "shinylive")
  expect_equal(infer_runtime_strategy(NULL, "r-shiny"), "shinylive")
  expect_equal(infer_runtime_strategy(NULL, "py-shiny"), "shinylive")
})

test_that("infer_runtime_strategy passes through an explicit strategy", {
  expect_equal(infer_runtime_strategy("system"), "system")
  expect_equal(infer_runtime_strategy("bundled"), "bundled")
  expect_equal(infer_runtime_strategy("container"), "container")
})

test_that("validate_r_available succeeds when Rscript is found", {
  # R CMD check's R_check_bin/Rscript shim does not always round-trip cleanly
  # through processx, causing this test to fail in the sandbox even though
  # Rscript is obviously present. Skip on CRAN and in R CMD check.
  skip_on_cran()
  skip_if(nzchar(Sys.getenv("_R_CHECK_PACKAGE_NAME_", "")))
  expect_silent(validate_r_available())
})

test_that("validate_r_available returns the Rscript path invisibly", {
  skip_on_cran()
  skip_if(nzchar(Sys.getenv("_R_CHECK_PACKAGE_NAME_", "")))
  result <- validate_r_available()
  expect_true(nzchar(result))
})

# Isolated tests that exercise the resolution logic without depending on the
# live Rscript shim, so they run in the standard CRAN / R CMD check pipeline.
test_that("validate_r_available errors when Rscript is not on PATH", {
  mockery::stub(validate_r_available, "Sys.getenv", function(...) "")
  mockery::stub(validate_r_available, "Sys.which", function(...) "")
  expect_error(validate_r_available(), "Rscript is required")
})

test_that("validate_r_available returns the resolved Rscript path", {
  mockery::stub(validate_r_available, "Sys.getenv", function(...) "checkmode")
  mockery::stub(validate_r_available, "Sys.which", function(...) "/usr/local/bin/Rscript")
  expect_equal(validate_r_available(), "/usr/local/bin/Rscript")
})
