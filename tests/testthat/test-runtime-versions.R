test_that("resolve_runtime_version returns the pin when unset", {
  cfg <- list(dependencies = list())
  expect_equal(resolve_runtime_version("r", cfg), SHINYELECTRON_DEFAULTS$runtime_versions$r)
  expect_equal(resolve_runtime_version("python", cfg), SHINYELECTRON_DEFAULTS$runtime_versions$python$version)
  expect_equal(resolve_runtime_version("node", cfg), SHINYELECTRON_DEFAULTS$runtime_versions$node)
})

test_that("resolve_runtime_version honors an explicit pin", {
  cfg <- list(dependencies = list(r = list(version = "4.4.1")))
  expect_equal(resolve_runtime_version("r", cfg), "4.4.1")
})

test_that("resolve_runtime_version 'latest' calls the live resolver", {
  skip_if_not_installed("mockery")
  cfg <- list(dependencies = list(node = list(version = "latest")))
  mockery::stub(resolve_runtime_version, "nodejs_latest_lts", function() "99.9.9")
  expect_equal(resolve_runtime_version("node", cfg), "99.9.9")
})
