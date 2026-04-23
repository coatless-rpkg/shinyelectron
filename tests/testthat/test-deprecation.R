test_that("normalize_app_type_arg passes NULL through unchanged", {
  out <- normalize_app_type_arg(NULL, NULL)
  expect_null(out$app_type)
  expect_null(out$runtime_strategy)
  expect_false(out$deprecated)
})

test_that("normalize_app_type_arg passes canonical values through silently", {
  out <- expect_silent(normalize_app_type_arg("r-shiny", "bundled"))
  expect_identical(out$app_type, "r-shiny")
  expect_identical(out$runtime_strategy, "bundled")
  expect_false(out$deprecated)
})

test_that("normalize_app_type_arg maps r-shinylive to r-shiny + shinylive", {
  expect_warning(
    normalize_app_type_arg("r-shinylive", NULL),
    class = "shinyelectron_deprecated_app_type"
  )
  out <- suppressWarnings(normalize_app_type_arg("r-shinylive", NULL))
  expect_identical(out$app_type, "r-shiny")
  expect_identical(out$runtime_strategy, "shinylive")
  expect_true(out$deprecated)
})

test_that("normalize_app_type_arg maps py-shinylive to py-shiny + shinylive", {
  expect_warning(
    normalize_app_type_arg("py-shinylive", NULL),
    class = "shinyelectron_deprecated_app_type"
  )
  out <- suppressWarnings(normalize_app_type_arg("py-shinylive", NULL))
  expect_identical(out$app_type, "py-shiny")
  expect_identical(out$runtime_strategy, "shinylive")
  expect_true(out$deprecated)
})

test_that("normalize_app_type_arg errors when legacy app_type conflicts with non-shinylive strategy", {
  expect_error(
    normalize_app_type_arg("r-shinylive", "bundled"),
    "Conflicting arguments"
  )
  expect_error(
    normalize_app_type_arg("py-shinylive", "system"),
    "Conflicting arguments"
  )
})

test_that("normalize_app_type_arg accepts legacy app_type with explicit shinylive strategy", {
  expect_warning(
    normalize_app_type_arg("r-shinylive", "shinylive"),
    class = "shinyelectron_deprecated_app_type"
  )
  out <- suppressWarnings(normalize_app_type_arg("r-shinylive", "shinylive"))
  expect_identical(out$app_type, "r-shiny")
  expect_identical(out$runtime_strategy, "shinylive")
})

test_that("export emits a deprecation warning when passed a legacy app_type", {
  appdir <- withr::local_tempdir()
  destdir <- withr::local_tempdir()
  writeLines("library(shiny); ui <- fluidPage(); server <- function(i,o,s) {}; shinyApp(ui, server)",
             fs::path(appdir, "app.R"))

  expect_warning(
    tryCatch(
      export(appdir, fs::path(destdir, "out"),
             app_type = "r-shinylive", build = FALSE,
             overwrite = TRUE, verbose = FALSE),
      error = function(e) NULL
    ),
    class = "shinyelectron_deprecated_app_type"
  )
})
