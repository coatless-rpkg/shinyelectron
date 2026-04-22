test_that("SHINYELECTRON_DEFAULTS contains runtime strategy options", {
  expect_true("valid_runtime_strategies" %in% names(SHINYELECTRON_DEFAULTS))
  expect_equal(
    SHINYELECTRON_DEFAULTS$valid_runtime_strategies,
    c("bundled", "system", "auto-download", "container")
  )
})

test_that("SHINYELECTRON_DEFAULTS contains container engine options", {
  expect_true("valid_container_engines" %in% names(SHINYELECTRON_DEFAULTS))
  expect_equal(
    SHINYELECTRON_DEFAULTS$valid_container_engines,
    c("docker", "podman")
  )
})

test_that("SHINYELECTRON_DEFAULTS contains container defaults", {
  expect_true("container" %in% names(SHINYELECTRON_DEFAULTS))
  expect_equal(SHINYELECTRON_DEFAULTS$container$engine, "docker")
  expect_null(SHINYELECTRON_DEFAULTS$container$image)
  expect_equal(SHINYELECTRON_DEFAULTS$container$tag, "latest")
  expect_true(SHINYELECTRON_DEFAULTS$container$pull_on_start)
})

test_that("SHINYELECTRON_DEFAULTS contains dependency defaults", {
  expect_true("dependencies" %in% names(SHINYELECTRON_DEFAULTS))
  expect_true(SHINYELECTRON_DEFAULTS$dependencies$auto_detect)
  expect_equal(
    SHINYELECTRON_DEFAULTS$dependencies$r$repos,
    list("https://cloud.r-project.org")
  )
  expect_equal(
    SHINYELECTRON_DEFAULTS$dependencies$python$index_urls,
    list("https://pypi.org/simple")
  )
})

test_that("SHINYELECTRON_DEFAULTS contains logging defaults", {
  expect_true("logging" %in% names(SHINYELECTRON_DEFAULTS))
  expect_null(SHINYELECTRON_DEFAULTS$logging$log_dir)
  expect_equal(SHINYELECTRON_DEFAULTS$logging$log_level, "info")
})

test_that("get_default retrieves existing keys", {
  expect_equal(get_default("window_width"), 1200L)
  expect_equal(get_default("server_port"), 3838L)
})

test_that("get_default returns fallback for missing keys", {
  expect_null(get_default("nonexistent_key"))
  expect_equal(get_default("nonexistent_key", "fallback"), "fallback")
})
