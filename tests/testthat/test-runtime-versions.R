test_that("resolve_runtime_version returns the pin when unset", {
  cfg <- list(dependencies = list())
  expect_equal(resolve_runtime_version("r", cfg), SHINYELECTRON_DEFAULTS$runtime_versions$r)
  expect_equal(resolve_runtime_version("python", cfg), SHINYELECTRON_DEFAULTS$runtime_versions$python$version)
  expect_equal(resolve_runtime_version("electron", cfg), SHINYELECTRON_DEFAULTS$runtime_versions$electron)
})

test_that("resolve_runtime_version honors an explicit pin", {
  cfg <- list(dependencies = list(r = list(version = "4.4.1")))
  expect_equal(resolve_runtime_version("r", cfg), "4.4.1")
})

test_that("resolve_runtime_version 'latest' calls the live resolver for electron", {
  skip_if_not_installed("mockery")
  cfg <- list(dependencies = list(electron = list(version = "latest")))
  mockery::stub(resolve_runtime_version, "electron_latest_version", function() "99.9.9")
  expect_equal(resolve_runtime_version("electron", cfg), "99.9.9")
})

test_that("electron_latest_version returns a version string from the registry", {
  skip_if_not_installed("mockery")
  fake_json <- '{"version": "41.0.0"}'
  fake_tf <- tempfile(fileext = ".json")
  withr::defer(unlink(fake_tf))
  writeLines(fake_json, fake_tf)
  mockery::stub(electron_latest_version, "utils::download.file", function(url, dest, ...) {
    file.copy(fake_tf, dest)
    invisible(0L)
  })
  result <- electron_latest_version()
  expect_equal(result, "41.0.0")
})
