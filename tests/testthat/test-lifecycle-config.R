test_that("SHINYELECTRON_DEFAULTS contains lifecycle defaults", {
  expect_true("lifecycle" %in% names(SHINYELECTRON_DEFAULTS))
  expect_true(SHINYELECTRON_DEFAULTS$lifecycle$show_phase_details)
  expect_true(SHINYELECTRON_DEFAULTS$lifecycle$error_show_logs)
  expect_equal(SHINYELECTRON_DEFAULTS$lifecycle$shutdown_timeout, 10000L)
  expect_null(SHINYELECTRON_DEFAULTS$lifecycle$custom_splash_html)
  expect_null(SHINYELECTRON_DEFAULTS$lifecycle$custom_error_html)
})

test_that("default_config includes lifecycle section", {
  cfg <- default_config()
  expect_true("lifecycle" %in% names(cfg))
  expect_true(cfg$lifecycle$show_phase_details)
})

test_that("read_brand_yml returns NULL when no file exists", {
  tmpdir <- tempfile()
  dir.create(tmpdir)
  on.exit(unlink(tmpdir, recursive = TRUE))
  result <- read_brand_yml(tmpdir)
  expect_null(result)
})

test_that("read_brand_yml reads _brand.yml file", {
  tmpdir <- tempfile()
  dir.create(tmpdir)
  on.exit(unlink(tmpdir, recursive = TRUE))
  writeLines(c("meta:", "  name: Test App", "color:", "  primary: '#ff0000'", "  background: '#ffffff'"),
             file.path(tmpdir, "_brand.yml"))
  result <- read_brand_yml(tmpdir)
  expect_equal(result$meta$name, "Test App")
  expect_equal(result$color$primary, "#ff0000")
})

test_that("read_brand_yml warns on malformed file", {
  tmpdir <- tempfile()
  dir.create(tmpdir)
  on.exit(unlink(tmpdir, recursive = TRUE))
  writeLines("not: valid: yaml: [", file.path(tmpdir, "_brand.yml"))
  expect_warning(result <- read_brand_yml(tmpdir))
  expect_null(result)
})

# 4D-3: init_config app_name escaping round-trip
test_that("init_config round-trips an app_name containing a double quote", {
  tmp <- withr::local_tempdir()
  name_with_quote <- 'My "Special" App'
  init_config(tmp, app_name = name_with_quote, verbose = FALSE)
  result <- read_config(tmp)
  expect_equal(result$app$name, name_with_quote)
})

test_that("init_config round-trips an app_name containing a backslash", {
  tmp <- withr::local_tempdir()
  name_with_backslash <- "App\\Name"
  init_config(tmp, app_name = name_with_backslash, verbose = FALSE)
  result <- read_config(tmp)
  expect_equal(result$app$name, name_with_backslash)
})
