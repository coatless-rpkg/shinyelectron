test_that("validate_runtime_strategy accepts valid strategies", {
  expect_silent(validate_runtime_strategy("bundled"))
  expect_silent(validate_runtime_strategy("system"))
  expect_silent(validate_runtime_strategy("auto-download"))
  expect_silent(validate_runtime_strategy("container"))
})

test_that("validate_runtime_strategy rejects invalid strategies", {
  expect_error(validate_runtime_strategy("invalid"), "Invalid runtime strategy")
  expect_error(validate_runtime_strategy("docker"), "Invalid runtime strategy")
})

test_that("validate_runtime_strategy_for_app_type rejects shinylive types with runtime strategy", {
  expect_error(
    validate_runtime_strategy_for_app_type("bundled", "r-shinylive"),
    "not applicable"
  )
  expect_error(
    validate_runtime_strategy_for_app_type("system", "py-shinylive"),
    "not applicable"
  )
})

test_that("validate_runtime_strategy_for_app_type accepts native types with any strategy", {
  expect_silent(validate_runtime_strategy_for_app_type("bundled", "r-shiny"))
  expect_silent(validate_runtime_strategy_for_app_type("system", "r-shiny"))
  expect_silent(validate_runtime_strategy_for_app_type("auto-download", "py-shiny"))
  expect_silent(validate_runtime_strategy_for_app_type("container", "py-shiny"))
})

test_that("validate_python_app_structure checks for app.py", {
  tmpdir <- tempfile()
  dir.create(tmpdir)
  on.exit(unlink(tmpdir, recursive = TRUE))

  expect_error(validate_python_app_structure(tmpdir), "app.py")

  writeLines("from shiny import App", file.path(tmpdir, "app.py"))
  expect_silent(validate_python_app_structure(tmpdir))
})

test_that("infer_runtime_strategy returns correct defaults", {
  expect_equal(infer_runtime_strategy(NULL, "r-shinylive"), "shinylive")
  expect_equal(infer_runtime_strategy(NULL, "py-shinylive"), "shinylive")
  expect_equal(infer_runtime_strategy(NULL, "r-shiny"), "auto-download")
  expect_equal(infer_runtime_strategy(NULL, "py-shiny"), "auto-download")
  expect_equal(infer_runtime_strategy("system", "r-shiny"), "system")
  expect_equal(infer_runtime_strategy("bundled", "r-shiny"), "bundled")
})

test_that("validate_r_available succeeds when Rscript is found", {
  expect_silent(validate_r_available())
})

test_that("validate_r_available returns the Rscript path invisibly", {
  result <- validate_r_available()
  expect_true(nzchar(result))
})
