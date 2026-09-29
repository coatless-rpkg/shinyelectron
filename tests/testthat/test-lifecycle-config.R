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

# --- init_config template documents new dependency keys ---

test_that("init_config template documents r/python/electron version and system_packages", {
  tmpdir <- tempfile()
  dir.create(tmpdir)
  on.exit(unlink(tmpdir, recursive = TRUE))

  init_config(tmpdir, app_name = "TestApp", verbose = FALSE)
  config_path <- file.path(tmpdir, "_shinyelectron.yml")
  template_text <- paste(readLines(config_path), collapse = "\n")

  # r, python, electron version keys should be documented
  expect_match(template_text, "r:", fixed = TRUE)
  expect_match(template_text, "python:", fixed = TRUE)
  expect_match(template_text, "electron:", fixed = TRUE)
  expect_match(template_text, "version:", fixed = TRUE)
  # system_packages should be documented
  expect_match(template_text, "system_packages", fixed = TRUE)
  # "latest" opt-in should be mentioned
  expect_match(template_text, "latest", fixed = TRUE)
})

# --- lifecycle timeouts ---

test_that("lifecycle.startup_timeout defaults to three minutes", {
  expect_identical(SHINYELECTRON_DEFAULTS$lifecycle$startup_timeout, 180000L)
  expect_identical(default_config()$lifecycle$startup_timeout, 180000L)
})

test_that("validate_config() keeps valid lifecycle timeouts", {
  cfg <- default_config()
  cfg$lifecycle$startup_timeout <- 300000L
  cfg$lifecycle$shutdown_timeout <- 5e3
  expect_no_warning(out <- validate_config(cfg))
  expect_equal(out$lifecycle$startup_timeout, 300000L)
  expect_equal(out$lifecycle$shutdown_timeout, 5000)
})

test_that("validate_config() resets invalid lifecycle timeouts to their defaults", {
  invalid <- list("10s", 999, 1500.5, c(2000, 3000), TRUE, NA_real_, 3e9)
  for (key in c("startup_timeout", "shutdown_timeout")) {
    for (value in invalid) {
      cfg <- default_config()
      cfg$lifecycle[[key]] <- value
      expect_warning(
        out <- validate_config(cfg),
        paste0("lifecycle.", key),
        fixed = TRUE
      )
      expect_identical(
        out$lifecycle[[key]],
        SHINYELECTRON_DEFAULTS$lifecycle[[key]]
      )
    }
  }
})

test_that("read_config() replaces a timeout written with a unit", {
  tmp <- withr::local_tempdir()
  writeLines(
    c("lifecycle:", "  startup_timeout: 3m", "  shutdown_timeout: 10s"),
    file.path(tmp, "_shinyelectron.yml")
  )
  expect_warning(
    expect_warning(cfg <- read_config(tmp), "startup_timeout"),
    "shutdown_timeout"
  )
  expect_identical(cfg$lifecycle$startup_timeout, 180000L)
  expect_identical(cfg$lifecycle$shutdown_timeout, 10000L)
})

test_that("lifecycle timeouts reach the backend config and main.js", {
  template_vars <- function(lifecycle, runtime_strategy = "system") {
    generate_template_variables(
      app_name = "Test App", app_slug = "test-app", app_type = "r-shiny",
      runtime_strategy = runtime_strategy, icon = NULL,
      backend_module = resolve_backend_module("r-shiny", runtime_strategy),
      brand = NULL,
      config = list(app = list(version = "1.0.0"), lifecycle = lifecycle)
    )
  }
  backend_config <- function(vars) jsonlite::fromJSON(vars$backend_config_json)

  defaults <- template_vars(list())
  expect_identical(backend_config(defaults)$startup_timeout, 180000L)
  expect_identical(defaults$shutdown_timeout, 10000L)

  custom <- template_vars(list(startup_timeout = 3e5, shutdown_timeout = 5000))
  expect_identical(backend_config(custom)$startup_timeout, 300000L)
  expect_identical(custom$shutdown_timeout, 5000L)

  container <- template_vars(list(startup_timeout = 60000L), "container")
  expect_identical(backend_config(container)$startup_timeout, 60000L)

  # A config that never went through validate_config() still yields numbers.
  unchecked <- template_vars(list(startup_timeout = "3m", shutdown_timeout = "10s"))
  expect_identical(backend_config(unchecked)$startup_timeout, 180000L)
  expect_identical(unchecked$shutdown_timeout, 10000L)
})

test_that("init_config template documents both lifecycle timeouts", {
  tmp <- withr::local_tempdir()
  init_config(tmp, app_name = "TestApp", verbose = FALSE)
  template_text <- paste(readLines(file.path(tmp, "_shinyelectron.yml")), collapse = "\n")
  expect_match(template_text, "startup_timeout: 180000", fixed = TRUE)
  expect_match(template_text, "shutdown_timeout: 10000", fixed = TRUE)
})
