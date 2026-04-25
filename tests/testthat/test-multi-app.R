test_that("is_multi_app detects multi-app config", {
  config_multi <- list(apps = list(
    list(id = "app1", name = "App 1", path = "./apps/app1"),
    list(id = "app2", name = "App 2", path = "./apps/app2")
  ))
  config_single <- list(app = list(name = "Single App"))

  expect_true(is_multi_app(config_multi))
  expect_false(is_multi_app(config_single))
  expect_false(is_multi_app(list()))
})

test_that("validate_multi_app_config validates app entries", {
  tmpdir <- tempfile(); dir.create(tmpdir)
  dir.create(file.path(tmpdir, "apps", "app1"), recursive = TRUE)
  writeLines("library(shiny)", file.path(tmpdir, "apps", "app1", "app.R"))
  dir.create(file.path(tmpdir, "apps", "app2"), recursive = TRUE)
  writeLines("library(shiny)", file.path(tmpdir, "apps", "app2", "app.R"))
  on.exit(unlink(tmpdir, recursive = TRUE))

  config <- list(
    build = list(type = "r-shiny"),
    apps = list(
      list(id = "app1", name = "App 1", path = "./apps/app1"),
      list(id = "app2", name = "App 2", path = "./apps/app2")
    )
  )

  expect_silent(validate_multi_app_config(config, tmpdir))
})

test_that("validate_multi_app_config errors on missing app dir", {
  tmpdir <- tempfile(); dir.create(tmpdir)
  on.exit(unlink(tmpdir, recursive = TRUE))

  config <- list(
    build = list(type = "r-shiny"),
    apps = list(
      list(id = "app1", name = "App 1", path = "./apps/missing")
    )
  )

  expect_error(validate_multi_app_config(config, tmpdir), "does not exist")
})

test_that("validate_multi_app_config errors on duplicate ids", {
  tmpdir <- tempfile(); dir.create(tmpdir)
  dir.create(file.path(tmpdir, "apps", "app1"), recursive = TRUE)
  writeLines("library(shiny)", file.path(tmpdir, "apps", "app1", "app.R"))
  on.exit(unlink(tmpdir, recursive = TRUE))

  config <- list(
    build = list(type = "r-shiny"),
    apps = list(
      list(id = "myapp", name = "App 1", path = "./apps/app1"),
      list(id = "myapp", name = "App 2", path = "./apps/app1")
    )
  )

  expect_error(validate_multi_app_config(config, tmpdir), "Duplicate")
})

test_that("resolve_app_type uses per-app override or default", {
  config <- list(build = list(type = "r-shiny"))
  app_no_type <- list(id = "a", name = "A", path = ".")
  app_with_type <- list(id = "b", name = "B", path = ".", type = "py-shiny")

  expect_equal(resolve_app_type(app_no_type, config), "r-shiny")
  expect_equal(resolve_app_type(app_with_type, config), "py-shiny")
})

test_that("resolve_app_type maps legacy per-app r-shinylive with a deprecation warning", {
  config <- list(build = list(type = "r-shiny"))
  app <- list(id = "a", name = "A", path = ".", type = "r-shinylive")

  expect_warning(
    resolve_app_type(app, config),
    class = "shinyelectron_deprecated_app_type"
  )
  expect_equal(
    suppressWarnings(resolve_app_type(app, config)),
    "r-shiny"
  )
})

test_that("resolve_app_strategy falls back through app > suite > default", {
  # Explicit per-app strategy wins
  app_explicit <- list(id = "a", name = "A", path = ".",
                      type = "r-shiny", runtime_strategy = "bundled")
  config_default <- list(build = list(type = "r-shiny", runtime_strategy = "system"))
  expect_equal(resolve_app_strategy(app_explicit, config_default), "bundled")

  # Suite strategy when app does not set one
  app_plain <- list(id = "b", name = "B", path = ".", type = "r-shiny")
  expect_equal(resolve_app_strategy(app_plain, config_default), "system")

  # shinylive default when nothing is set
  config_empty <- list(build = list(type = "r-shiny"))
  expect_equal(resolve_app_strategy(app_plain, config_empty), "shinylive")
})

test_that("resolve_app_strategy treats legacy per-app r-shinylive as shinylive", {
  config <- list(build = list(type = "r-shiny", runtime_strategy = "system"))
  app_legacy <- list(id = "a", name = "A", path = ".", type = "r-shinylive")

  expect_equal(suppressWarnings(resolve_app_strategy(app_legacy, config)), "shinylive")
})

test_that("mixed-strategy multi-app suite picks per-app strategy in the manifest", {
  # Hand-build the apps manifest loop the way export-multi.R does, to verify
  # that different strategies produce different per-app manifest entries.
  config <- list(
    build = list(type = "r-shiny", runtime_strategy = "system"),
    apps = list(
      list(id = "dash",  name = "D", path = "./d"),
      list(id = "quick", name = "Q", path = "./q", runtime_strategy = "shinylive")
    )
  )

  strategies <- vapply(
    config$apps,
    function(a) resolve_app_strategy(a, config),
    character(1)
  )
  expect_equal(strategies, c("system", "shinylive"))
})

# --- Integration Tests ---

test_that("export detects multi-app and copies all apps", {
  tmpdir <- tempfile(); dir.create(tmpdir)
  dir.create(file.path(tmpdir, "apps", "dash"), recursive = TRUE)
  dir.create(file.path(tmpdir, "apps", "admin"), recursive = TRUE)
  writeLines("library(shiny)\nshinyApp(ui=fluidPage(), server=function(i,o){})",
             file.path(tmpdir, "apps", "dash", "app.R"))
  writeLines("library(shiny)\nshinyApp(ui=fluidPage(), server=function(i,o){})",
             file.path(tmpdir, "apps", "admin", "app.R"))

  yaml::write_yaml(list(
    app = list(name = "Test Suite", version = "1.0.0"),
    build = list(type = "r-shiny", runtime_strategy = "system"),
    apps = list(
      list(id = "dash", name = "Dashboard", path = "./apps/dash"),
      list(id = "admin", name = "Admin", path = "./apps/admin")
    )
  ), file.path(tmpdir, "_shinyelectron.yml"))

  outdir <- tempfile()
  on.exit(unlink(c(tmpdir, outdir), recursive = TRUE))

  mockery::stub(export, "build_multi_app", function(...) tempdir())

  result <- export(appdir = tmpdir, destdir = outdir, build = TRUE,
                   sign = FALSE, verbose = FALSE)

  expect_true(fs::dir_exists(fs::path(outdir, "apps", "dash")))
  expect_true(fs::dir_exists(fs::path(outdir, "apps", "admin")))
  expect_true(fs::file_exists(fs::path(outdir, "apps", "dash", "app.R")))
})

test_that("process_templates creates launcher.html for multi-app", {
  d <- tempfile(); dir.create(d)
  dir.create(file.path(d, "src"), recursive = TRUE)
  dir.create(file.path(d, "assets"))
  dir.create(file.path(d, "build"))
  on.exit(unlink(d, TRUE))

  apps <- list(
    list(id = "app1", name = "App One", description = "First app",
         path = "src/apps/app1", type = "r-shiny"),
    list(id = "app2", name = "App Two", description = "Second app",
         path = "src/apps/app2", type = "py-shiny")
  )

  process_templates(d, "Multi Suite", "r-shiny", runtime_strategy = "system",
                    config = list(app = list(version = "1.0.0")),
                    is_multi_app = TRUE, apps_manifest = apps,
                    verbose = FALSE)

  # Launcher should exist
  expect_true(file.exists(file.path(d, "launcher.html")))
  launcher <- readLines(file.path(d, "launcher.html"))
  expect_true(any(grepl("App One", launcher)))
  expect_true(any(grepl("App Two", launcher)))

  # All backends should be copied
  expect_true(file.exists(file.path(d, "backends", "native-r.js")))
  expect_true(file.exists(file.path(d, "backends", "native-py.js")))
  expect_true(file.exists(file.path(d, "backends", "shinylive.js")))

  # main.js should have multi-app references
  main <- readLines(file.path(d, "main.js"))
  expect_true(any(grepl("apps-manifest", main)))
  expect_true(any(grepl("select_app", main)))

  # package.json should include launcher and apps
  pkg <- jsonlite::fromJSON(file.path(d, "package.json"))
  expect_true("launcher.html" %in% pkg$build$files)
  expect_true("apps-manifest.json" %in% pkg$build$files)
})
