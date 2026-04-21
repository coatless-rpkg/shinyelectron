# True end-to-end tests — build full Electron apps and verify output
# These are SLOW (1-2 minutes each) and require Node.js + npm.
# Skipped on CI, CRAN, and inside R CMD check. Run locally with:
#   testthat::test_file("tests/testthat/test-e2e.R")

skip_on_cran()
skip_on_ci()
skip_if(nzchar(Sys.getenv("_R_CHECK_PACKAGE_NAME_", "")),
        "R CMD check sandbox restricts pkgcache and the Rscript shim")
skip_if_not(nzchar(Sys.which("node")), "Node.js not available")
skip_if_not(nzchar(Sys.which("npm")), "npm not available")

# --- r-shinylive full build ---

test_that("e2e: r-shinylive full build produces working Electron app", {
  d <- tempfile(); dir.create(d); o <- tempfile()
  on.exit(unlink(c(d, o), TRUE))
  writeLines("library(shiny)\nshinyApp(ui=fluidPage(h1('E2E')), server=function(i,o){})",
             file.path(d, "app.R"))

  r <- export(d, o, app_type = "r-shinylive", sign = FALSE,
              build = TRUE, overwrite = TRUE, verbose = FALSE)

  electron_dir <- r$electron_app

  # Verify Electron project structure

  expect_true(file.exists(file.path(electron_dir, "main.js")))
  expect_true(file.exists(file.path(electron_dir, "lifecycle.html")))
  expect_true(file.exists(file.path(electron_dir, "preload.js")))
  expect_true(file.exists(file.path(electron_dir, "package.json")))
  expect_true(file.exists(file.path(electron_dir, "backends", "shinylive.js")))
  expect_true(file.exists(file.path(electron_dir, "backends", "utils.js")))
  expect_true(dir.exists(file.path(electron_dir, "node_modules")))
  expect_true(dir.exists(file.path(electron_dir, "dist")))

  # Verify main.js uses shinylive backend
  main <- readLines(file.path(electron_dir, "main.js"))
  expect_true(any(grepl("shinylive", main)))

  # Verify package.json has express dependency
  pkg <- jsonlite::fromJSON(file.path(electron_dir, "package.json"))
  expect_true("express" %in% names(pkg$dependencies))

  # Verify shinylive app files
  expect_true(file.exists(file.path(electron_dir, "src", "app", "index.html")))
})

# --- r-shiny system full build ---

test_that("e2e: r-shiny system full build produces working Electron app", {
  d <- tempfile(); dir.create(d); o <- tempfile()
  on.exit(unlink(c(d, o), TRUE))
  writeLines(c("library(shiny)", "library(ggplot2)",
               "shinyApp(ui=fluidPage(h1('E2E')), server=function(i,o){})"),
             file.path(d, "app.R"))

  r <- export(d, o, app_type = "r-shiny", runtime_strategy = "system",
              sign = FALSE, build = TRUE, overwrite = TRUE, verbose = FALSE)

  electron_dir <- r$electron_app

  # Verify native backend
  expect_true(file.exists(file.path(electron_dir, "backends", "native-r.js")))
  expect_true(file.exists(file.path(electron_dir, "backends", "utils.js")))
  expect_true(file.exists(file.path(electron_dir, "backends", "dependency-checker.js")))
  expect_false("express" %in% names(jsonlite::fromJSON(
    file.path(electron_dir, "package.json"))$dependencies))

  # Verify main.js uses native-r backend
  main <- readLines(file.path(electron_dir, "main.js"))
  expect_true(any(grepl("native-r", main)))

  # Verify app files and dependency manifest
  expect_true(file.exists(file.path(electron_dir, "src", "app", "app.R")))
  expect_true(file.exists(file.path(electron_dir, "src", "app", "dependencies.json")))

  # Verify dependencies detected
  deps <- jsonlite::fromJSON(file.path(electron_dir, "src", "app", "dependencies.json"))
  expect_true("shiny" %in% deps$packages)
  expect_true("ggplot2" %in% deps$packages)

  # Verify dist was created (installer built)
  expect_true(dir.exists(file.path(electron_dir, "dist")))
})

# --- r-shiny container full build ---

test_that("e2e: r-shiny container full build embeds Dockerfile", {
  d <- tempfile(); dir.create(d); o <- tempfile()
  on.exit(unlink(c(d, o), TRUE))
  writeLines("library(shiny)\nshinyApp(ui=fluidPage(), server=function(i,o){})",
             file.path(d, "app.R"))

  suppressWarnings(
    r <- export(d, o, app_type = "r-shiny", runtime_strategy = "container",
                sign = FALSE, build = TRUE, overwrite = TRUE, verbose = FALSE)
  )

  electron_dir <- r$electron_app

  # Verify container backend and Dockerfile
  expect_true(file.exists(file.path(electron_dir, "backends", "container.js")))
  expect_true(file.exists(file.path(electron_dir, "dockerfiles", "Dockerfile")))
  expect_true(file.exists(file.path(electron_dir, "dockerfiles", "entrypoint.sh")))

  # Verify it's the R Dockerfile
  dockerfile <- readLines(file.path(electron_dir, "dockerfiles", "Dockerfile"))
  expect_true(any(grepl("rocker|r-base", dockerfile, ignore.case = TRUE)))

  # Verify container.js has socket resolution
  container_js <- readLines(file.path(electron_dir, "backends", "container.js"))
  expect_true(any(grepl("resolveDockerHost", container_js)))
  expect_true(any(grepl("ensureImage", container_js)))
})

# --- py-shiny system full build ---

test_that("e2e: py-shiny system full build produces working Electron app", {
  d <- tempfile(); dir.create(d); o <- tempfile()
  on.exit(unlink(c(d, o), TRUE))
  writeLines("from shiny import App, ui\napp=App(ui.page_fluid(ui.h1('E2E')),None)",
             file.path(d, "app.py"))
  writeLines("shiny", file.path(d, "requirements.txt"))

  r <- export(d, o, app_type = "py-shiny", runtime_strategy = "system",
              sign = FALSE, build = TRUE, overwrite = TRUE, verbose = FALSE)

  electron_dir <- r$electron_app

  # Verify native-py backend
  expect_true(file.exists(file.path(electron_dir, "backends", "native-py.js")))
  main <- readLines(file.path(electron_dir, "main.js"))
  expect_true(any(grepl("native-py", main)))

  # Verify app files
  expect_true(file.exists(file.path(electron_dir, "src", "app", "app.py")))
  deps <- jsonlite::fromJSON(file.path(electron_dir, "src", "app", "dependencies.json"))
  expect_equal(deps$language, "python")
  expect_true("shiny" %in% deps$packages)
})

# --- py-shinylive full build ---

test_that("e2e: py-shinylive full build produces working Electron app", {
  skip_if_not(py_shinylive_available(), "Python shinylive CLI not available")
  d <- tempfile(); dir.create(d); o <- tempfile()
  on.exit(unlink(c(d, o), TRUE))
  writeLines("from shiny import App, ui\napp=App(ui.page_fluid(ui.h1('E2E')),None)",
             file.path(d, "app.py"))

  r <- export(d, o, app_type = "py-shinylive", sign = FALSE,
              build = TRUE, overwrite = TRUE, verbose = FALSE)

  electron_dir <- r$electron_app

  # Verify shinylive backend (same as r-shinylive)
  expect_true(file.exists(file.path(electron_dir, "backends", "shinylive.js")))
  pkg <- jsonlite::fromJSON(file.path(electron_dir, "package.json"))
  expect_true("express" %in% names(pkg$dependencies))

  # Verify shinylive conversion produced output
  expect_true(file.exists(file.path(electron_dir, "src", "app", "index.html")))
})

# --- Electron app launch test ---

test_that("e2e: r-shiny native Electron app starts and emits lifecycle events", {
  skip_if_not(nzchar(Sys.which("npx")), "npx not available")

  d <- tempfile(); dir.create(d); o <- tempfile()
  on.exit(unlink(c(d, o), TRUE))
  writeLines("library(shiny)\nshinyApp(ui=fluidPage(h1('Launch')), server=function(i,o){})",
             file.path(d, "app.R"))

  r <- export(d, o, app_type = "r-shiny", runtime_strategy = "system",
              sign = FALSE, build = TRUE, overwrite = TRUE, verbose = FALSE)

  electron_dir <- r$electron_app

  # Launch for 15 seconds and capture output.
  # SHINYELECTRON_DEBUG=1 surfaces the backend diagnostic log lines
  # we grep for below — otherwise the app runs silently by design.
  result <- processx::run(
    "npx", c("electron", "."),
    wd = electron_dir,
    timeout = 15,
    error_on_status = FALSE,
    env = c(Sys.getenv(), SHINYELECTRON_DEBUG = "1")
  )

  output <- paste(result$stdout, result$stderr)

  # Verify the app at least started (lifecycle events or R output)
  # The exact lifecycle event format may vary with backend changes
  app_started <- grepl("server_ready|Listening on|Shiny server|R Shiny server ready", output)
  expect_true(app_started)
})
