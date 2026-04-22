test_that("enable_auto_updates writes config correctly", {
  tmp <- withr::local_tempdir()
  dir.create(tmp, showWarnings = FALSE, recursive = TRUE)

  # Create a minimal config
  writeLines(
    "app:\n  name: test\nbuild:\n  type: r-shinylive\n",
    file.path(tmp, "_shinyelectron.yml")
  )

  result <- enable_auto_updates(
    tmp,
    provider = "github",
    owner = "testowner",
    repo = "testrepo",
    check_on_startup = TRUE,
    auto_download = FALSE,
    auto_install = FALSE,
    verbose = FALSE
  )

  config <- yaml::read_yaml(result)
  expect_true(config$updates$enabled)
  expect_equal(config$updates$provider, "github")
  expect_equal(config$updates$github$owner, "testowner")
  expect_equal(config$updates$github$repo, "testrepo")
  expect_true(config$updates$check_on_startup)
  expect_false(config$updates$auto_download)
  expect_false(config$updates$auto_install)
})

test_that("enable_auto_updates requires owner/repo for github provider", {
  tmp <- withr::local_tempdir()
  dir.create(tmp, showWarnings = FALSE, recursive = TRUE)
  writeLines(
    "app:\n  name: test\nbuild:\n  type: r-shinylive\n",
    file.path(tmp, "_shinyelectron.yml")
  )

  expect_error(
    enable_auto_updates(tmp, provider = "github", owner = NULL, repo = NULL),
    "owner.*repo"
  )
})

test_that("enable_auto_updates creates config if none exists", {
  tmp <- withr::local_tempdir()
  dir.create(tmp, showWarnings = FALSE, recursive = TRUE)

  # No config file exists yet
  expect_false(file.exists(file.path(tmp, "_shinyelectron.yml")))

  result <- enable_auto_updates(
    tmp,
    provider = "github",
    owner = "myorg",
    repo = "myapp",
    verbose = FALSE
  )

  expect_true(file.exists(result))
  config <- yaml::read_yaml(result)
  expect_true(config$updates$enabled)
})

test_that("disable_auto_updates sets enabled to FALSE", {
  tmp <- withr::local_tempdir()
  dir.create(tmp, showWarnings = FALSE, recursive = TRUE)

  # First enable
  writeLines(
    "app:\n  name: test\nupdates:\n  enabled: true\n  provider: github\n",
    file.path(tmp, "_shinyelectron.yml")
  )

  result <- disable_auto_updates(tmp, verbose = FALSE)
  config <- yaml::read_yaml(result)
  expect_false(config$updates$enabled)
})

test_that("disable_auto_updates is no-op when already disabled", {
  tmp <- withr::local_tempdir()
  dir.create(tmp, showWarnings = FALSE, recursive = TRUE)

  writeLines(
    "app:\n  name: test\nupdates:\n  enabled: false\n",
    file.path(tmp, "_shinyelectron.yml")
  )

  # Should not error
  result <- disable_auto_updates(tmp, verbose = FALSE)
  config <- yaml::read_yaml(result)
  expect_false(config$updates$enabled)
})

test_that("disable_auto_updates errors without config file", {
  tmp <- withr::local_tempdir()
  dir.create(tmp, showWarnings = FALSE, recursive = TRUE)

  expect_error(
    disable_auto_updates(tmp),
    "No configuration file"
  )
})

test_that("check_auto_update_status reports enabled status", {
  tmp <- withr::local_tempdir()
  dir.create(tmp, showWarnings = FALSE, recursive = TRUE)

  writeLines(
    "app:\n  name: test\nupdates:\n  enabled: true\n  provider: github\n  github:\n    owner: foo\n    repo: bar\n",
    file.path(tmp, "_shinyelectron.yml")
  )

  result <- check_auto_update_status(tmp)
  expect_true(result$enabled)
  expect_equal(result$provider, "github")
})

test_that("check_auto_update_status reports disabled status", {
  tmp <- withr::local_tempdir()
  dir.create(tmp, showWarnings = FALSE, recursive = TRUE)

  writeLines(
    "app:\n  name: test\n",
    file.path(tmp, "_shinyelectron.yml")
  )

  result <- check_auto_update_status(tmp)
  # Should be NULL or disabled
  expect_true(is.null(result) || !isTRUE(result$enabled))
})

test_that("enable_auto_updates preserves existing config values", {
  tmp <- withr::local_tempdir()
  dir.create(tmp, showWarnings = FALSE, recursive = TRUE)

  writeLines(
    "app:\n  name: My App\n  version: '2.0.0'\nbuild:\n  type: r-shiny\nwindow:\n  width: 1400\n",
    file.path(tmp, "_shinyelectron.yml")
  )

  result <- enable_auto_updates(
    tmp, provider = "github", owner = "me", repo = "app", verbose = FALSE
  )

  config <- yaml::read_yaml(result)
  expect_equal(config$app$name, "My App")
  expect_equal(config$app$version, "2.0.0")
  expect_equal(config$build$type, "r-shiny")
  expect_equal(config$window$width, 1400)
  expect_true(config$updates$enabled)
})
