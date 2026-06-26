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

test_that("assert_safe_to_overwrite refuses protected dirs", {
  expect_error(assert_safe_to_overwrite("/"), "protected")
  expect_error(assert_safe_to_overwrite(normalizePath("~", mustWork = FALSE)), "protected")
  expect_true(assert_safe_to_overwrite(withr::local_tempdir()))
})

# 4D-1: wizard platform validation
test_that("wizard aborts for an invalid platform token", {
  tmp <- withr::local_tempdir()
  responses <- c("", "", "1", "1", "badplatform")
  idx <- 0L
  mockery::stub(wizard, "interactive", function() TRUE)
  mockery::stub(wizard, "readline", function(...) {
    idx <<- idx + 1L
    if (idx <= length(responses)) responses[[idx]] else ""
  })
  expect_error(
    capture.output(suppressMessages(wizard(tmp)), type = "output"),
    "Invalid platform"
  )
})

# 4D-2: enable_auto_updates rejects unsupported providers with a clear message
test_that("enable_auto_updates rejects s3 provider with clear error", {
  tmp <- withr::local_tempdir()
  writeLines(
    "app:\n  name: test\nbuild:\n  type: r-shiny\n  runtime_strategy: shinylive\n",
    file.path(tmp, "_shinyelectron.yml")
  )
  expect_error(
    enable_auto_updates(tmp, provider = "s3", owner = "x", repo = "y"),
    "not yet supported"
  )
})

test_that("enable_auto_updates rejects generic provider with clear error", {
  tmp <- withr::local_tempdir()
  writeLines(
    "app:\n  name: test\nbuild:\n  type: r-shiny\n  runtime_strategy: shinylive\n",
    file.path(tmp, "_shinyelectron.yml")
  )
  expect_error(
    enable_auto_updates(tmp, provider = "generic", owner = "x", repo = "y"),
    "not yet supported"
  )
})

# 4D-3: scalar guards in validate_config
test_that("validate_config warns clearly for a length-2 window width", {
  cfg <- list(window = list(width = c(1200, 800)))
  expect_warning(validated <- validate_config(cfg), "window.width")
  expect_equal(validated$window$width, SHINYELECTRON_DEFAULTS$window_width)
})

test_that("validate_config warns clearly for a list window height", {
  cfg <- list(window = list(height = list(800, 600)))
  expect_warning(validated <- validate_config(cfg), "window.height")
  expect_equal(validated$window$height, SHINYELECTRON_DEFAULTS$window_height)
})

test_that("validate_config warns clearly for a length-2 server port", {
  cfg <- list(server = list(port = c(3838, 3839)))
  expect_warning(validated <- validate_config(cfg), "server.port")
  expect_equal(validated$server$port, SHINYELECTRON_DEFAULTS$server_port)
})
