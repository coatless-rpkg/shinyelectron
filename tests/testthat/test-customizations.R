# Helper: build a minimal config that satisfies generate_template_variables.
# Tests then layer overrides on top of this base.
.cust_base_config <- function(splash = list(), preloader = list()) {
  list(
    app = list(version = "1.0.0"),
    window = list(width = 1200L, height = 800L),
    server = list(port = 3838L),
    splash = splash,
    preloader = preloader,
    tray = list(),
    menu = list(),
    updates = list(),
    lifecycle = list(),
    container = list()
  )
}

.cust_template_vars <- function(splash = list(), preloader = list(),
                                brand = NULL) {
  generate_template_variables(
    app_name = "Test App",
    app_slug = "test-app",
    app_type = "r-shiny",
    runtime_strategy = "shinylive",
    icon = NULL,
    backend_module = "shinylive.js",
    brand = brand,
    config = .cust_base_config(splash = splash, preloader = preloader)
  )
}

test_that("SHINYELECTRON_DEFAULTS$splash matches the wired schema", {
  defaults <- SHINYELECTRON_DEFAULTS$splash
  expect_true(defaults$enabled)
  expect_equal(defaults$duration, 1500L)
  expect_null(defaults$background)
  expect_null(defaults$image)
  expect_equal(defaults$text, "Loading...")
  expect_equal(defaults$text_color, "#333333")
  expect_false("width" %in% names(defaults))
  expect_false("height" %in% names(defaults))
})

test_that("SHINYELECTRON_DEFAULTS$preloader matches the wired schema", {
  defaults <- SHINYELECTRON_DEFAULTS$preloader
  expect_equal(defaults$style, "spinner")
  expect_equal(defaults$message, "Loading application...")
  expect_null(defaults$background)
  expect_false("enabled" %in% names(defaults))
})

test_that("splash defaults flow through to template variables", {
  vars <- .cust_template_vars()
  expect_true(vars$splash_enabled)
  expect_equal(vars$splash_duration, 1500L)
  expect_equal(vars$splash_text, "Loading...")
  expect_equal(vars$splash_text_color, "#333333")
})

test_that("splash.enabled FALSE flows through to template variables", {
  vars <- .cust_template_vars(splash = list(enabled = FALSE))
  expect_false(vars$splash_enabled)
})

test_that("splash.duration overrides flow through to template variables", {
  vars <- .cust_template_vars(splash = list(duration = 3000L))
  expect_equal(vars$splash_duration, 3000L)
})

test_that("splash.background falls back to brand background, then to a literal default", {
  no_brand <- .cust_template_vars()
  expect_equal(no_brand$splash_background, "#f8fafc")

  with_brand <- .cust_template_vars(brand = list(color = list(background = "#1a1a2e")))
  expect_equal(with_brand$splash_background, "#1a1a2e")

  override <- .cust_template_vars(
    splash = list(background = "#000000"),
    brand = list(color = list(background = "#1a1a2e"))
  )
  expect_equal(override$splash_background, "#000000")
})

test_that("preloader.background falls back to brand background, then to a literal default", {
  no_brand <- .cust_template_vars()
  expect_equal(no_brand$preloader_background, "#f8fafc")

  with_brand <- .cust_template_vars(brand = list(color = list(background = "#1a1a2e")))
  expect_equal(with_brand$preloader_background, "#1a1a2e")

  override <- .cust_template_vars(
    preloader = list(background = "#222222"),
    brand = list(color = list(background = "#1a1a2e"))
  )
  expect_equal(override$preloader_background, "#222222")
})

test_that("preloader_style booleans are mutually exclusive and match preloader.style", {
  spinner <- .cust_template_vars(preloader = list(style = "spinner"))
  expect_true(spinner$preloader_style_spinner)
  expect_false(spinner$preloader_style_bar)
  expect_false(spinner$preloader_style_dots)

  bar <- .cust_template_vars(preloader = list(style = "bar"))
  expect_false(bar$preloader_style_spinner)
  expect_true(bar$preloader_style_bar)
  expect_false(bar$preloader_style_dots)

  dots <- .cust_template_vars(preloader = list(style = "dots"))
  expect_false(dots$preloader_style_spinner)
  expect_false(dots$preloader_style_bar)
  expect_true(dots$preloader_style_dots)
})

test_that("preloader_style defaults to spinner when not set", {
  vars <- .cust_template_vars()
  expect_equal(vars$preloader_style, "spinner")
  expect_true(vars$preloader_style_spinner)
})

test_that("validate_config rejects invalid preloader.style and falls back to spinner", {
  bad <- list(preloader = list(style = "wiggle"))
  expect_warning(validated <- validate_config(bad), "preloader style")
  expect_equal(validated$preloader$style, "spinner")
})

test_that("validate_config rejects invalid menu.template and falls back to default", {
  bad <- list(menu = list(template = "custom"))
  expect_warning(validated <- validate_config(bad), "menu template")
  expect_equal(validated$menu$template, "default")
})

test_that("validate_config rejects negative splash.duration and falls back to default", {
  bad <- list(splash = list(duration = -100))
  expect_warning(validated <- validate_config(bad), "splash.duration")
  expect_equal(validated$splash$duration, SHINYELECTRON_DEFAULTS$splash$duration)
})
