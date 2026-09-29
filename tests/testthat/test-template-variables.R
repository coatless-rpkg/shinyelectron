# Render the shared Electron templates the way export() does: write
# `config` as _shinyelectron.yml, read it back with read_config(), then run
# process_templates(). Returns the path to the generated main.js; the
# temporary directories live until `env` exits.
render_main_js <- function(config = list(), app_name = "Test App",
                           is_multi_app = FALSE, apps_manifest = NULL,
                           env = parent.frame()) {
  appdir <- withr::local_tempdir(.local_envir = env)
  if (length(config) > 0) {
    yaml::write_yaml(config, file.path(appdir, "_shinyelectron.yml"))
  }
  out <- withr::local_tempdir(.local_envir = env)
  process_templates(
    out, app_name, "r-shiny", runtime_strategy = "system",
    config = read_config(appdir), is_multi_app = is_multi_app,
    apps_manifest = apps_manifest, verbose = FALSE
  )
  file.path(out, "main.js")
}

# --- Help menu ---

test_that("has_help_url is TRUE only for a non-empty help_url", {
  has_help_url <- function(help_url) {
    generate_template_variables(
      app_name = "Test App", app_slug = "test-app", app_type = "r-shiny",
      runtime_strategy = "shinylive", icon = NULL,
      backend_module = "shinylive.js", brand = NULL,
      config = list(menu = list(help_url = help_url))
    )$has_help_url
  }
  expect_false(has_help_url(NULL))
  expect_false(has_help_url(""))
  expect_true(has_help_url("https://docs.example.com"))
})

test_that("Help > Documentation renders only when help_url is set", {
  has_docs_item <- function(config) {
    main <- readLines(render_main_js(config))
    any(grepl("label: 'Documentation'", main, fixed = TRUE))
  }
  expect_false(has_docs_item(list()))
  expect_false(has_docs_item(list(menu = list(help_url = ""))))
  expect_true(has_docs_item(list(menu = list(help_url = "https://docs.example.com"))))
})

test_that("is_nonempty_string accepts only a single non-empty string", {
  expect_true(is_nonempty_string("x"))
  expect_false(is_nonempty_string(NULL))
  expect_false(is_nonempty_string(""))
  expect_false(is_nonempty_string(NA_character_))
  expect_false(is_nonempty_string(c("a", "b")))
  expect_false(is_nonempty_string(1))
})
