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

# --- app.description, app.homepage, and app.copyright ---

test_that("package.json carries the description, homepage, and copyright", {
  pkg <- package_json(list(app = list(
    description = "Quarterly sales explorer",
    homepage = "https://example.org/sales",
    copyright = "Copyright 2026 Example Inc."
  )))
  expect_equal(pkg$description, "Quarterly sales explorer")
  expect_equal(pkg$homepage, "https://example.org/sales")
  expect_equal(pkg$build$copyright, "Copyright 2026 Example Inc.")
})

test_that("unset or blank metadata leaves package.json at its defaults", {
  blank <- list(description = "", homepage = "", copyright = "  ")
  for (app in list(list(), blank)) {
    pkg <- package_json(list(app = app))
    expect_equal(pkg$description, "my-app - Shiny Electron App")
    expect_null(pkg$homepage)
    expect_null(pkg$build$copyright)
  }
})

test_that("validate_config accepts an http or https app.homepage", {
  ok <- c("https://example.org", "http://example.org/a?b=1", "HTTPS://EXAMPLE.ORG", "", "  ")
  for (homepage in ok) {
    expect_no_error(validate_config(list(app = list(homepage = homepage))))
  }
})

test_that("validate_config aborts on any other app.homepage", {
  bad <- list(
    "example.org", "ftp://example.org", "javascript:alert(1)",
    "file:///etc/passwd", "https://", 42, list("https://a.org", "https://b.org")
  )
  for (homepage in bad) {
    expect_error(
      validate_config(list(app = list(homepage = homepage))),
      class = "shinyelectron_invalid_homepage"
    )
  }
})

test_that("read_config aborts on a homepage that is not a web URL", {
  appdir <- withr::local_tempdir()
  writeLines(
    c("app:", "  homepage: \"javascript:alert(1)\""),
    file.path(appdir, "_shinyelectron.yml")
  )
  expect_error(read_config(appdir), "app.homepage", class = "shinyelectron_invalid_homepage")
})

test_that("validate_config drops a description or copyright that is not a string", {
  expect_warning(
    config <- validate_config(list(app = list(description = list("a", "b")))),
    "app.description"
  )
  expect_null(config$app$description)
  expect_warning(
    config <- validate_config(list(app = list(copyright = 2026))),
    "app.copyright"
  )
  expect_null(config$app$copyright)
})

test_that("a homepage that is not a web URL never reaches package.json or main.js", {
  # generate_package_json() and process_templates() can receive a config that
  # never went through validate_config().
  config <- list(app = list(homepage = "javascript:alert(1)"))
  expect_null(package_json(config)$homepage)
  expect_null(app_metadata(config)$homepage)
})

test_that("metadata text is reduced to one line", {
  # A YAML block scalar keeps its line breaks and adds a trailing one.
  appdir <- withr::local_tempdir()
  writeLines(c(
    "app:",
    "  description: |",
    "    Quarterly sales",
    "    explorer",
    "  copyright: >",
    "    Copyright 2026",
    "    Example Inc.",
    "  author:",
    "    name: \"Jane\\nDoe\""
  ), file.path(appdir, "_shinyelectron.yml"))
  pkg <- package_json(read_config(appdir))
  expect_equal(pkg$description, "Quarterly sales explorer")
  expect_equal(pkg$build$copyright, "Copyright 2026 Example Inc.")
  expect_equal(pkg$author, list(name = "Jane Doe"))
  expect_null(metadata_text(" \n "))
})

# --- Windows installer strings ---

test_that("smart_quotes turns straight double quotes into typographic ones", {
  expect_equal(smart_quotes('Sales "Q3" Dashboard'), "Sales \u201cQ3\u201d Dashboard")
  expect_equal(smart_quotes('"Acme" Inc.'), "\u201cAcme\u201d Inc.")
  expect_equal(smart_quotes('A 5" screen'), "A 5\u201d screen")
  expect_equal(smart_quotes("Plain"), "Plain")
  expect_null(smart_quotes(NULL))
})

test_that("package.json keeps straight double quotes out of Windows installer strings", {
  pkg <- package_json(
    list(app = list(
      author = 'Jane "JD" Doe <jane@example.org>',
      copyright = 'Copyright 2026 "Acme" Inc.',
      description = 'The "best" app'
    )),
    app_name = 'Sales "Q3" Dashboard'
  )
  expect_equal(pkg$build$productName, "Sales \u201cQ3\u201d Dashboard")
  expect_equal(pkg$build$copyright, "Copyright 2026 \u201cAcme\u201d Inc.")
  expect_equal(pkg$author, list(name = "Jane \u201cJD\u201d Doe", email = "jane@example.org"))
  # electron-builder smartens the description's quotes itself.
  expect_equal(pkg$description, 'The "best" app')
})

test_that("a $ in the app name or metadata stops a Windows build and warns otherwise", {
  config <- list(app = list(copyright = "Copyright $YEAR Acme"))
  expect_error(
    check_installer_text("Price Tracker", config, windows = TRUE),
    "app.copyright", class = "shinyelectron_installer_dollar"
  )
  expect_warning(
    check_installer_text("Price Tracker", config, windows = FALSE),
    "app.copyright", class = "shinyelectron_installer_dollar"
  )
  expect_error(
    check_installer_text("Price$Tracker", list(), windows = TRUE),
    "app name", class = "shinyelectron_installer_dollar"
  )
  for (field in c("description", "author")) {
    app <- stats::setNames(list("Save $5"), field)
    expect_error(
      check_installer_text("Price Tracker", list(app = app), windows = TRUE),
      paste0("app.", field), class = "shinyelectron_installer_dollar"
    )
  }
  expect_silent(check_installer_text(
    "Price Tracker", list(app = list(copyright = "Copyright 2026 Acme")), windows = TRUE
  ))
})

test_that("export() stops a Windows build with a $ in the app name before converting", {
  appdir <- withr::local_tempdir()
  writeLines(
    "library(shiny)\nshinyApp(ui = fluidPage(), server = function(input, output) {})",
    file.path(appdir, "app.R")
  )
  mockery::stub(export, "convert_app_to_shinylive", function(...) stop("converted"))
  mockery::stub(export, "build_electron_app", function(...) stop("built"))
  expect_error(
    export(appdir, withr::local_tempdir(), app_name = "Price$Tracker",
           platform = "win", overwrite = TRUE, verbose = FALSE),
    class = "shinyelectron_installer_dollar"
  )

  # Building for another platform only warns, and the export goes on.
  mockery::stub(export, "convert_app_to_shinylive", function(...) tempdir())
  mockery::stub(export, "build_electron_app", function(...) tempdir())
  expect_warning(
    export(appdir, withr::local_tempdir(), app_name = "Price$Tracker",
           platform = "mac", overwrite = TRUE, verbose = FALSE),
    class = "shinyelectron_installer_dollar"
  )
})
