# Parse a generated package.json into a list.
package_json <- function(config, app_slug = "my-app", app_name = NULL) {
  jsonlite::fromJSON(
    generate_package_json(app_slug, "1.0.0", "native-r", config, app_name = app_name),
    simplifyVector = FALSE
  )
}

# --- app.author ---

test_that("normalize_app_author splits an npm person string", {
  expect_equal(
    normalize_app_author("Jane Doe <jane@example.org> (https://jane.example.org)"),
    list(name = "Jane Doe", email = "jane@example.org", url = "https://jane.example.org")
  )
  expect_equal(
    normalize_app_author("Jane Doe <jane@example.org>"),
    list(name = "Jane Doe", email = "jane@example.org", url = NULL)
  )
  expect_equal(
    normalize_app_author("Jane Doe (https://jane.example.org)"),
    list(name = "Jane Doe", email = NULL, url = "https://jane.example.org")
  )
  expect_equal(
    normalize_app_author("  Jane Doe  "),
    list(name = "Jane Doe", email = NULL, url = NULL)
  )
  expect_equal(
    normalize_app_author("<jane@example.org>"),
    list(name = NULL, email = "jane@example.org", url = NULL)
  )
})

test_that("normalize_app_author accepts a map with name, email, and url", {
  expect_equal(
    normalize_app_author(list(name = "Jane Doe", email = "jane@example.org", url = "https://jane.example.org")),
    list(name = "Jane Doe", email = "jane@example.org", url = "https://jane.example.org")
  )
  expect_equal(
    normalize_app_author(list(name = "Jane Doe", email = "")),
    list(name = "Jane Doe", email = NULL, url = NULL)
  )
})

test_that("normalize_app_author treats unset and blank authors as unset", {
  expect_null(normalize_app_author(NULL))
  expect_null(normalize_app_author(""))
  expect_null(normalize_app_author("   "))
  expect_null(normalize_app_author(NA_character_))
  expect_null(normalize_app_author(list(name = NULL)))
})

test_that("normalize_app_author warns about other shapes and ignores them", {
  bad <- list(
    c("Jane", "Joe"),
    list("Jane", "Joe"),
    42,
    list(name = "Jane", handle = "@jane"),
    list(name = 42)
  )
  for (value in bad) {
    expect_warning(result <- normalize_app_author(value), "app.author")
    expect_null(result)
  }
})

test_that("package.json author takes the normalized author", {
  expect_equal(
    package_json(list(app = list(author = "Jane Doe <jane@example.org>")))$author,
    list(name = "Jane Doe", email = "jane@example.org")
  )
  map <- list(name = "Jane Doe", email = "jane@example.org", url = "https://jane.example.org")
  expect_equal(package_json(list(app = list(author = map)))$author, map)
  expect_equal(package_json(list())$author, "")
})

test_that("read_config drops a malformed app.author with a warning", {
  appdir <- withr::local_tempdir()
  writeLines(
    c("app:", "  author:", "    - Jane", "    - Joe"),
    file.path(appdir, "_shinyelectron.yml")
  )
  expect_warning(config <- read_config(appdir), "app.author")
  expect_null(config$app$author)
})

test_that("an author map gives the About dialog a name and an Email button", {
  vars <- generate_template_variables(
    app_name = "Test App", app_slug = "test-app", app_type = "r-shiny",
    runtime_strategy = "system", icon = NULL, backend_module = "native-r.js",
    brand = NULL,
    config = list(app = list(author = list(name = "Jane Doe", email = "jane@example.org")))
  )
  expect_identical(vars$app_author_js, "Jane Doe")
  expect_true(vars$has_app_author)
  expect_identical(vars$app_email_js, "jane@example.org")
  expect_true(vars$has_app_email)
})

test_that("process_templates warns once about a malformed author", {
  out <- withr::local_tempdir()
  warnings <- character(0)
  withCallingHandlers(
    process_templates(
      out, "Test App", "r-shiny", runtime_strategy = "system",
      config = list(app = list(author = c("Jane", "Joe"))), verbose = FALSE
    ),
    warning = function(w) {
      warnings <<- c(warnings, conditionMessage(w))
      invokeRestart("muffleWarning")
    }
  )
  expect_length(grep("app.author", warnings, fixed = TRUE), 1)
  expect_equal(jsonlite::fromJSON(file.path(out, "package.json"))$author, "")
})
