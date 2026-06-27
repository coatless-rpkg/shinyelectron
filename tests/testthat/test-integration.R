# Integration tests for shinyelectron
# These test the full export pipeline across app types and strategies
# Availability helpers live in helper-shinylive.R
shinylive_available <- r_shinylive_available

# --- App Check ---

test_that("e2e: app_check passes for valid R app", {
  skip_if_not(shinylive_available(), "shinylive not available")
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
  skip_if_not_installed("renv")
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
  skip_if_not_installed("renv")
  d <- tempfile(); dir.create(d); o <- tempfile()
  on.exit(unlink(c(d, o), TRUE))
  writeLines("library(shiny)\nshinyApp(ui=fluidPage(), server=function(i,o){})", file.path(d, "app.R"))
  # Pin R version via config so the test doesn't depend on r_latest_version()
  yaml::write_yaml(list(dependencies = list(r = list(version = "4.4.1"))),
                   file.path(d, "_shinyelectron.yml"))
  r <- export(d, o, app_type = "r-shiny", runtime_strategy = "auto-download",
              sign = FALSE, build = FALSE, overwrite = TRUE, verbose = FALSE)
  manifest_path <- fs::path(o, "shiny-app", "runtime-manifest.json")
  expect_true(fs::file_exists(manifest_path))
  m <- jsonlite::fromJSON(manifest_path)
  expect_equal(m$language, "r")
  expect_equal(m$version, "4.4.1")
})

test_that("e2e: r-shiny container export warns but succeeds", {
  skip_if_not_installed("renv")
  d <- tempfile(); dir.create(d); o <- tempfile()
  on.exit(unlink(c(d, o), TRUE))
  writeLines("library(shiny)\nshinyApp(ui=fluidPage(), server=function(i,o){})", file.path(d, "app.R"))
  call_export <- function() {
    r <<- export(d, o, app_type = "r-shiny", runtime_strategy = "container",
                 sign = FALSE, build = FALSE, overwrite = TRUE, verbose = FALSE)
  }
  r <- NULL
  if (is.null(detect_container_engine())) {
    # No docker/podman on the build machine: the missing-engine warning fires.
    expect_warning(call_export(), "Container engine not available")
  } else {
    call_export()
  }
  expect_true(!is.null(r$converted_app))
})

# --- py-shiny ---

test_that("e2e: py-shiny container export warns but succeeds", {
  d <- tempfile(); dir.create(d); o <- tempfile()
  on.exit(unlink(c(d, o), TRUE))
  writeLines("from shiny import App, ui\napp=App(ui.page_fluid(),None)", file.path(d, "app.py"))
  writeLines("shiny", file.path(d, "requirements.txt"))
  call_export <- function() {
    r <<- export(d, o, app_type = "py-shiny", runtime_strategy = "container",
                 sign = FALSE, build = FALSE, overwrite = TRUE, verbose = FALSE)
  }
  r <- NULL
  if (is.null(detect_container_engine())) {
    expect_warning(call_export(), "Container engine not available")
  } else {
    call_export()
  }
  expect_true(!is.null(r$converted_app))
})

test_that("e2e: py-shiny auto-download writes Python runtime manifest", {
  d <- tempfile(); dir.create(d); o <- tempfile()
  on.exit(unlink(c(d, o), TRUE))
  writeLines("from shiny import App, ui\napp=App(ui.page_fluid(),None)", file.path(d, "app.py"))
  writeLines("shiny", file.path(d, "requirements.txt"))
  # Avoid network access: return pin release for any version
  local_mocked_bindings(
    python_resolve_pbs = function(v) list(version = v, release = "20250101"),
    .package = "shinyelectron"
  )
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
  skip_if_not_installed("renv")
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

# --- run_after failure must not delete a successful build ---

test_that("export keeps build output when run_after fails", {
  skip_if_not_installed("mockery")
  appdir <- withr::local_tempdir()
  writeLines("library(shiny); shinyApp(fluidPage(), function(input, output){})",
             file.path(appdir, "app.R"))
  destdir <- withr::local_tempdir()

  # Stub the build entrypoints to avoid real shinylive/npm work, and make
  # run_electron_app throw to simulate a non-zero Electron exit.
  mockery::stub(export, "convert_app_to_shinylive",
                function(...) file.path(destdir, "shinylive-app"))
  mockery::stub(export, "build_electron_app", function(...) {
    d <- file.path(destdir, "electron-app")
    fs::dir_create(d)
    d
  })
  mockery::stub(export, "run_electron_app",
                function(...) stop("electron exited 1"))

  expect_warning(
    export(appdir, destdir, run_after = TRUE, build = TRUE,
           overwrite = TRUE, verbose = FALSE),
    "exited with an error"
  )
  expect_true(fs::dir_exists(file.path(destdir, "electron-app")))
})

# --- Container Version Baking ---

test_that("e2e: r-shiny container Dockerfile encodes pinned R version, sysreqs, and install.packages", {
  out <- withr::local_tempdir()

  # Create app dependencies manifest consumed by bake_dockerfile_dependencies
  app_dir <- fs::path(out, "src", "app")
  fs::dir_create(app_dir, recurse = TRUE)
  jsonlite::write_json(
    list(language = "r", packages = list("shiny", "ggplot2")),
    fs::path(app_dir, "dependencies.json"),
    auto_unbox = TRUE
  )

  cfg <- list(
    dependencies = list(
      r = list(version = "4.5.1"),
      system_packages = c("libfoo-dev")
    )
  )

  # Avoid network sysreqs calls; libfoo-dev still comes from config escape hatch
  local_mocked_bindings(
    query_sysreqs = function(...) character(0),
    .package = "shinyelectron"
  )

  copy_and_bake_dockerfiles(out, "r-shiny", config = cfg, verbose = FALSE)

  dockerfile_path <- fs::path(out, "dockerfiles", "Dockerfile")
  expect_true(fs::file_exists(dockerfile_path))
  df_lines <- readLines(dockerfile_path)

  # Base image is rocker/r-ver
  expect_true(any(grepl("rocker/r-ver", df_lines)))

  # ARG encodes the pinned R version
  expect_true(any(grepl("^ARG R_VERSION=4\\.5\\.1$", df_lines)))

  # config system_packages escape hatch reaches the apt RUN line
  expect_true(any(grepl("libfoo-dev", df_lines)))

  # R packages are installed via install.packages (not r-cran-*)
  expect_true(any(grepl("install\\.packages", df_lines)))
  expect_false(any(grepl("r-cran-", df_lines)))

  # generate_container_config encodes the runtime version as the image tag
  expect_equal(generate_container_config(cfg, "r-shiny")$container_tag, "4.5.1")
})
