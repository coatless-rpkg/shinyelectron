# Integration tests for shinyelectron
# These test the full export pipeline across app types and strategies
# Availability helpers live in helper-shinylive.R
shinylive_available <- r_shinylive_available

# --- App Check ---

test_that("e2e: app_check passes for valid R app", {
  d <- tempfile(); dir.create(d)
  on.exit(unlink(d, TRUE))
  writeLines("library(shiny)\nshinyApp(ui=fluidPage(), server=function(i,o){})", file.path(d, "app.R"))
  r <- app_check(d, verbose = FALSE)
  expect_true(r$pass)
  expect_length(r$errors, 0)
})

test_that("e2e: app_check fails for invalid app", {
  d <- tempfile(); dir.create(d)
  on.exit(unlink(d, TRUE))
  r <- app_check(d, verbose = FALSE)
  expect_false(r$pass)
})

# --- shinylive strategy (new API) ---

test_that("e2e: r-shiny + shinylive strategy produces shinylive output", {
  skip_if_not(shinylive_available(), "shinylive not available")
  d <- tempfile(); dir.create(d); o <- tempfile()
  on.exit(unlink(c(d, o), TRUE))
  writeLines("library(shiny)\nshinyApp(ui=fluidPage(), server=function(i,o){})", file.path(d, "app.R"))
  r <- export(d, o, app_type = "r-shiny", runtime_strategy = "shinylive",
              sign = FALSE, build = FALSE, overwrite = TRUE, verbose = FALSE)
  expect_true(fs::dir_exists(r$converted_app))
  expect_true(fs::file_exists(fs::path(r$converted_app, "index.html")))
})

test_that("e2e: autodetect from app.R defaults to r-shiny + shinylive", {
  skip_if_not(shinylive_available(), "shinylive not available")
  d <- tempfile(); dir.create(d); o <- tempfile()
  on.exit(unlink(c(d, o), TRUE))
  writeLines("library(shiny)\nshinyApp(ui=fluidPage(), server=function(i,o){})", file.path(d, "app.R"))
  r <- export(d, o, sign = FALSE, build = FALSE, overwrite = TRUE, verbose = FALSE)
  expect_true(fs::dir_exists(r$converted_app))
  expect_true(fs::file_exists(fs::path(r$converted_app, "index.html")))
})

# --- shinylive strategy (legacy app_type) ---

test_that("e2e: legacy r-shinylive export still works with deprecation warning", {
  skip_if_not(shinylive_available(), "shinylive not available")
  d <- tempfile(); dir.create(d); o <- tempfile()
  on.exit(unlink(c(d, o), TRUE))
  writeLines("library(shiny)\nshinyApp(ui=fluidPage(), server=function(i,o){})", file.path(d, "app.R"))

  # The warning is expected; the build must still finish.
  expect_warning(
    export(d, o, app_type = "r-shinylive", sign = FALSE, build = FALSE,
           overwrite = TRUE, verbose = FALSE),
    class = "shinyelectron_deprecated_app_type"
  )

  # Re-run suppressed to capture the result.
  o2 <- tempfile(); on.exit(unlink(o2, TRUE), add = TRUE)
  r <- suppressWarnings(
    export(d, o2, app_type = "r-shinylive", sign = FALSE, build = FALSE,
           overwrite = TRUE, verbose = FALSE)
  )
  expect_true(fs::dir_exists(r$converted_app))
  expect_true(fs::file_exists(fs::path(r$converted_app, "index.html")))
})

# --- r-shiny ---

test_that("e2e: r-shiny system export copies app and writes dependencies", {
  d <- tempfile(); dir.create(d); o <- tempfile()
  on.exit(unlink(c(d, o), TRUE))
  writeLines(c("library(shiny)", "library(ggplot2)"), file.path(d, "app.R"))
  r <- export(d, o, app_type = "r-shiny", runtime_strategy = "system",
              sign = FALSE, build = FALSE, overwrite = TRUE, verbose = FALSE)
  expect_true(fs::file_exists(fs::path(o, "shiny-app", "app.R")))
  expect_true(fs::file_exists(fs::path(o, "shiny-app", "dependencies.json")))
  deps <- jsonlite::fromJSON(fs::path(o, "shiny-app", "dependencies.json"))
  expect_equal(deps$language, "r")
  expect_true("shiny" %in% deps$packages)
  expect_true("ggplot2" %in% deps$packages)
})

test_that("e2e: r-shiny auto-download writes runtime manifest", {
  # auto-download is unavailable on Linux (no portable-r builds).
  skip_on_os("linux")
  d <- tempfile(); dir.create(d); o <- tempfile()
  on.exit(unlink(c(d, o), TRUE))
  writeLines("library(shiny)\nshinyApp(ui=fluidPage(), server=function(i,o){})", file.path(d, "app.R"))
  # Pin R version via config so the test doesn't depend on r_latest_version()
  yaml::write_yaml(list(r = list(version = "4.4.1")), file.path(d, "_shinyelectron.yml"))
  r <- export(d, o, app_type = "r-shiny", runtime_strategy = "auto-download",
              sign = FALSE, build = FALSE, overwrite = TRUE, verbose = FALSE)
  manifest_path <- fs::path(o, "shiny-app", "runtime-manifest.json")
  expect_true(fs::file_exists(manifest_path))
  m <- jsonlite::fromJSON(manifest_path)
  expect_equal(m$language, "r")
  expect_equal(m$version, "4.4.1")
})

test_that("e2e: r-shiny container export warns but succeeds", {
  d <- tempfile(); dir.create(d); o <- tempfile()
  on.exit(unlink(c(d, o), TRUE))
  writeLines("library(shiny)\nshinyApp(ui=fluidPage(), server=function(i,o){})", file.path(d, "app.R"))
  suppressWarnings(
    r <- export(d, o, app_type = "r-shiny", runtime_strategy = "container",
                sign = FALSE, build = FALSE, overwrite = TRUE, verbose = FALSE)
  )
  expect_true(!is.null(r$converted_app))
})

# --- py-shiny ---

test_that("e2e: py-shiny container export warns but succeeds", {
  d <- tempfile(); dir.create(d); o <- tempfile()
  on.exit(unlink(c(d, o), TRUE))
  writeLines("from shiny import App, ui\napp=App(ui.page_fluid(),None)", file.path(d, "app.py"))
  writeLines("shiny", file.path(d, "requirements.txt"))
  suppressWarnings(
    r <- export(d, o, app_type = "py-shiny", runtime_strategy = "container",
                sign = FALSE, build = FALSE, overwrite = TRUE, verbose = FALSE)
  )
  expect_true(!is.null(r$converted_app))
})

test_that("e2e: py-shiny auto-download writes Python runtime manifest", {
  d <- tempfile(); dir.create(d); o <- tempfile()
  on.exit(unlink(c(d, o), TRUE))
  writeLines("from shiny import App, ui\napp=App(ui.page_fluid(),None)", file.path(d, "app.py"))
  writeLines("shiny", file.path(d, "requirements.txt"))
  r <- export(d, o, app_type = "py-shiny", runtime_strategy = "auto-download",
              sign = FALSE, build = FALSE, overwrite = TRUE, verbose = FALSE)
  manifest_path <- fs::path(o, "shiny-app", "runtime-manifest.json")
  expect_true(fs::file_exists(manifest_path))
  m <- jsonlite::fromJSON(manifest_path)
  expect_equal(m$language, "python")
})

test_that("e2e: py-shiny system export copies app and writes dependencies", {
  d <- tempfile(); dir.create(d); o <- tempfile()
  on.exit(unlink(c(d, o), TRUE))
  writeLines("from shiny import App, ui\napp=App(ui.page_fluid(),None)", file.path(d, "app.py"))
  writeLines("shiny", file.path(d, "requirements.txt"))
  r <- export(d, o, app_type = "py-shiny", runtime_strategy = "system",
              sign = FALSE, build = FALSE, overwrite = TRUE, verbose = FALSE)
  expect_true(fs::file_exists(fs::path(o, "shiny-app", "app.py")))
  deps <- jsonlite::fromJSON(fs::path(o, "shiny-app", "dependencies.json"))
  expect_equal(deps$language, "python")
  expect_true("shiny" %in% deps$packages)
})

# --- Python shinylive ---

test_that("e2e: py-shiny + shinylive strategy produces shinylive output", {
  skip_if_not(py_shinylive_available(), "Python shinylive CLI not available")
  d <- tempfile(); dir.create(d); o <- tempfile()
  on.exit(unlink(c(d, o), TRUE))
  writeLines("from shiny import App, ui\napp=App(ui.page_fluid(),None)", file.path(d, "app.py"))
  r <- export(d, o, app_type = "py-shiny", runtime_strategy = "shinylive",
              sign = FALSE, build = FALSE, overwrite = TRUE, verbose = FALSE)
  expect_true(fs::dir_exists(r$converted_app))
  expect_true(fs::file_exists(fs::path(r$converted_app, "index.html")))
})

test_that("e2e: autodetect from app.py defaults to py-shiny + shinylive", {
  skip_if_not(py_shinylive_available(), "Python shinylive CLI not available")
  d <- tempfile(); dir.create(d); o <- tempfile()
  on.exit(unlink(c(d, o), TRUE))
  writeLines("from shiny import App, ui\napp=App(ui.page_fluid(),None)", file.path(d, "app.py"))
  r <- export(d, o, sign = FALSE, build = FALSE, overwrite = TRUE, verbose = FALSE)
  expect_true(fs::dir_exists(r$converted_app))
  expect_true(fs::file_exists(fs::path(r$converted_app, "index.html")))
})

# --- Signing ---

test_that("e2e: unsigned build sets identity null in package.json", {
  r <- generate_package_json("test-app", "1.0.0", "shinylive", list(), sign = FALSE)
  p <- jsonlite::fromJSON(r, simplifyVector = FALSE)
  expect_null(p$build$mac$identity)
})

test_that("e2e: signed build includes identity and notarize in package.json", {
  cfg <- list(signing = list(sign = TRUE,
    mac = list(identity = "Developer ID Application: Test", team_id = "TEAM123", notarize = TRUE)))
  r <- generate_package_json("test-app", "1.0.0", "shinylive", cfg, sign = TRUE)
  p <- jsonlite::fromJSON(r, simplifyVector = FALSE)
  expect_equal(p$build$mac$identity, "Developer ID Application: Test")
  expect_equal(p$build$mac$notarize$teamId, "TEAM123")
})

# --- Template Assembly ---

test_that("e2e: process_templates assembles r-shiny native correctly", {
  d <- tempfile(); dir.create(d)
  dir.create(file.path(d, "src"), recursive = TRUE)
  dir.create(file.path(d, "assets"))
  dir.create(file.path(d, "build"))
  on.exit(unlink(d, TRUE))
  process_templates(d, "Test App", "r-shiny", runtime_strategy = "system",
                    config = list(app = list(version = "1.0.0")), verbose = FALSE)
  main <- readLines(file.path(d, "main.js"))
  expect_true(any(grepl("native-r", main)))
  expect_true(file.exists(file.path(d, "backends", "native-r.js")))
  expect_true(file.exists(file.path(d, "backends", "utils.js")))
  expect_true(file.exists(file.path(d, "backends", "dependency-checker.js")))
  expect_true(file.exists(file.path(d, "lifecycle.html")))
  expect_true(file.exists(file.path(d, "preload.js")))
  pkg <- jsonlite::fromJSON(file.path(d, "package.json"))
  expect_false("express" %in% names(pkg$dependencies))
})

test_that("e2e: process_templates assembles container with Dockerfile", {
  d <- tempfile(); dir.create(d)
  dir.create(file.path(d, "src"), recursive = TRUE)
  dir.create(file.path(d, "assets"))
  dir.create(file.path(d, "build"))
  on.exit(unlink(d, TRUE))
  process_templates(d, "Container App", "r-shiny", runtime_strategy = "container",
                    config = list(app = list(version = "1.0.0")), verbose = FALSE)
  expect_true(file.exists(file.path(d, "backends", "container.js")))
  expect_true(file.exists(file.path(d, "dockerfiles", "Dockerfile")))
  expect_true(file.exists(file.path(d, "dockerfiles", "entrypoint.sh")))
})

test_that("e2e: process_templates assembles py-shiny container with Python Dockerfile", {
  d <- tempfile(); dir.create(d)
  dir.create(file.path(d, "src"), recursive = TRUE)
  dir.create(file.path(d, "assets"))
  dir.create(file.path(d, "build"))
  on.exit(unlink(d, TRUE))
  process_templates(d, "Py Container", "py-shiny", runtime_strategy = "container",
                    config = list(app = list(version = "1.0.0")), verbose = FALSE)
  expect_true(file.exists(file.path(d, "backends", "container.js")))
  expect_true(file.exists(file.path(d, "dockerfiles", "Dockerfile")))
  # Verify it's the Python Dockerfile, not the R one
  dockerfile <- readLines(file.path(d, "dockerfiles", "Dockerfile"))
  expect_true(any(grepl("python", dockerfile, ignore.case = TRUE)))
})

test_that("e2e: process_templates assembles py-shiny native correctly", {
  d <- tempfile(); dir.create(d)
  dir.create(file.path(d, "src"), recursive = TRUE)
  dir.create(file.path(d, "assets"))
  dir.create(file.path(d, "build"))
  on.exit(unlink(d, TRUE))
  process_templates(d, "Py Native", "py-shiny", runtime_strategy = "system",
                    config = list(app = list(version = "1.0.0")), verbose = FALSE)
  main <- readLines(file.path(d, "main.js"))
  expect_true(any(grepl("native-py", main)))
  expect_true(file.exists(file.path(d, "backends", "native-py.js")))
  expect_false(file.exists(file.path(d, "dockerfiles", "Dockerfile")))
})

test_that("e2e: r-shiny container Dockerfile is R-based", {
  d <- tempfile(); dir.create(d)
  dir.create(file.path(d, "src"), recursive = TRUE)
  dir.create(file.path(d, "assets"))
  dir.create(file.path(d, "build"))
  on.exit(unlink(d, TRUE))
  process_templates(d, "R Container", "r-shiny", runtime_strategy = "container",
                    config = list(app = list(version = "1.0.0")), verbose = FALSE)
  dockerfile <- readLines(file.path(d, "dockerfiles", "Dockerfile"))
  expect_true(any(grepl("rocker|r-base", dockerfile, ignore.case = TRUE)))
})

test_that("e2e: process_templates assembles shinylive with express", {
  d <- tempfile(); dir.create(d)
  dir.create(file.path(d, "src"), recursive = TRUE)
  dir.create(file.path(d, "assets"))
  dir.create(file.path(d, "build"))
  on.exit(unlink(d, TRUE))
  process_templates(d, "Shinylive App", "r-shiny", runtime_strategy = "shinylive",
                    config = list(app = list(version = "1.0.0")), verbose = FALSE)
  main <- readLines(file.path(d, "main.js"))
  expect_true(any(grepl("shinylive", main)))
  pkg <- jsonlite::fromJSON(file.path(d, "package.json"))
  expect_true("express" %in% names(pkg$dependencies))
})

# --- Config Round-Trip ---

test_that("e2e: init_config creates valid config that reads back", {
  d <- tempfile(); dir.create(d)
  on.exit(unlink(d, TRUE))
  writeLines("library(shiny)", file.path(d, "app.R"))
  init_config(d, app_name = "Round Trip", verbose = FALSE)
  expect_true(file.exists(file.path(d, "_shinyelectron.yml")))
  cfg <- read_config(d)
  expect_equal(cfg$app$name, "Round Trip")
})

# --- Brand.yml ---

test_that("e2e: brand.yml is read and applied", {
  d <- tempfile(); dir.create(d)
  on.exit(unlink(d, TRUE))
  writeLines(c("meta:", "  name: Branded App", "color:", "  primary: '#ff0000'",
               "  background: '#000000'"),
             file.path(d, "_brand.yml"))
  brand <- read_brand_yml(d)
  expect_equal(brand$meta$name, "Branded App")
  expect_equal(brand$color$primary, "#ff0000")
  expect_equal(brand$color$background, "#000000")
})

# --- Dependency Detection ---

test_that("e2e: R dependencies detected via renv", {
  d <- tempfile(); dir.create(d)
  on.exit(unlink(d, TRUE))
  writeLines(c("library(shiny)", "library(ggplot2)", "DT::datatable(mtcars)"), file.path(d, "app.R"))
  deps <- detect_r_dependencies(d)
  expect_true(all(c("shiny", "ggplot2", "DT") %in% deps))
})

test_that("e2e: Python dependencies detected from requirements.txt", {
  d <- tempfile(); dir.create(d)
  on.exit(unlink(d, TRUE))
  writeLines(c("pandas>=2.0", "shiny", "numpy"), file.path(d, "requirements.txt"))
  deps <- detect_py_dependencies(d)
  expect_true(all(c("pandas", "shiny", "numpy") %in% deps))
})
