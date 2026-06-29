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

test_that("export_multi_app emits serve descriptors for native and container apps", {
  skip_if_not_installed("renv")

  appdir <- withr::local_tempdir()
  dir.create(file.path(appdir, "apps", "dash"), recursive = TRUE)
  dir.create(file.path(appdir, "apps", "box"), recursive = TRUE)
  writeLines("library(shiny)\nshinyApp(ui=fluidPage(), server=function(i,o){})",
             file.path(appdir, "apps", "dash", "app.R"))
  writeLines("library(shiny)\nshinyApp(ui=fluidPage(), server=function(i,o){})",
             file.path(appdir, "apps", "box", "app.R"))

  config <- list(
    app = list(name = "Suite", version = "1.0.0"),
    build = list(type = "r-shiny", runtime_strategy = "system"),
    apps = list(
      list(id = "dash", name = "Dashboard", path = "./apps/dash"),
      list(id = "box",  name = "Boxed",     path = "./apps/box",
           runtime_strategy = "container")
    )
  )

  destdir <- file.path(withr::local_tempdir(), "out")
  export_multi_app(appdir = appdir, destdir = destdir, config = config,
                   app_name = "Suite", runtime_strategy = "system",
                   build = FALSE, overwrite = TRUE, verbose = FALSE)

  manifest_path <- fs::path(destdir, "apps-manifest.json")
  expect_true(fs::file_exists(manifest_path))

  manifest <- jsonlite::fromJSON(manifest_path, simplifyVector = FALSE)
  expect_equal(manifest$schema_version, "2")

  # Ordering preserved.
  ids <- vapply(manifest$apps, function(a) a$id, character(1))
  expect_equal(ids, c("dash", "box"))

  # Native serve descriptor; no stray top-level path.
  dash <- manifest$apps[[1]]
  expect_null(dash$path)
  expect_equal(dash$serve$kind, "native")
  expect_equal(dash$serve$path, "src/apps/dash")
  expect_equal(dash$serve$runtime_strategy, "system")

  # Container serve descriptor.
  box <- manifest$apps[[2]]
  expect_null(box$path)
  expect_equal(box$serve$kind, "container")
  expect_equal(box$serve$path, "src/apps/box")
  expect_null(box$serve$runtime_strategy)
})

# --- Integration Tests ---

test_that("export detects multi-app and copies all apps", {
  skip_if_not_installed("renv")
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

  # build = FALSE exercises multi-app detection and the app-copy step without
  # a real Electron build. (Previously this stubbed build_multi_app on export,
  # but export delegates to export_multi_app, so the stub never fired and a
  # full npm/electron-builder build ran.)
  result <- export(appdir = tmpdir, destdir = outdir, build = FALSE,
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

# --- run_after failure must not delete a successful build (multi-app) ---

test_that("export_multi_app keeps build output when run_after fails", {
  skip_if_not_installed("mockery")

  # Build a minimal multi-app fixture that passes validate_multi_app_config.
  appdir <- withr::local_tempdir()
  dir.create(file.path(appdir, "apps", "dash"), recursive = TRUE)
  dir.create(file.path(appdir, "apps", "admin"), recursive = TRUE)
  writeLines("library(shiny)\nshinyApp(ui=fluidPage(), server=function(i,o){})",
             file.path(appdir, "apps", "dash", "app.R"))
  writeLines("library(shiny)\nshinyApp(ui=fluidPage(), server=function(i,o){})",
             file.path(appdir, "apps", "admin", "app.R"))

  yaml::write_yaml(list(
    app = list(name = "Test Suite", version = "1.0.0"),
    build = list(type = "r-shiny", runtime_strategy = "system"),
    apps = list(
      list(id = "dash",  name = "Dashboard", path = "./apps/dash"),
      list(id = "admin", name = "Admin",     path = "./apps/admin")
    )
  ), file.path(appdir, "_shinyelectron.yml"))

  config <- read_config(appdir)
  destdir <- withr::local_tempdir()

  # Stub build_multi_app to avoid real npm/Electron work; simulate a
  # successful build by creating the expected electron-app directory.
  mockery::stub(export_multi_app, "build_multi_app", function(...) {
    d <- file.path(destdir, "electron-app")
    fs::dir_create(d)
    d
  })
  # Stub run_electron_app to simulate a non-zero Electron exit.
  mockery::stub(export_multi_app, "run_electron_app",
                function(...) stop("electron exited 1"))

  expect_warning(
    export_multi_app(
      appdir          = appdir,
      destdir         = destdir,
      config          = config,
      app_name        = "Test Suite",
      runtime_strategy = NULL,
      sign            = FALSE,
      platform        = NULL,
      arch            = NULL,
      icon            = NULL,
      overwrite       = TRUE,
      build           = TRUE,
      run_after       = TRUE,
      open_after      = FALSE,
      verbose         = FALSE
    ),
    "exited with an error"
  )

  # The build directory must survive the failed run_electron_app call.
  expect_true(fs::dir_exists(file.path(destdir, "electron-app")))
})

test_that("build_multi_app aborts multi-platform when any app resolves to a native bundled strategy", {
  skip_if_not_installed("mockery")

  apps_dir <- withr::local_tempdir()
  output_dir <- file.path(withr::local_tempdir(), "electron-app")

  # Suite default is shinylive; only the per-app override is bundled.
  config <- list(
    build = list(type = "r-shiny"),
    apps = list(
      list(id = "dash",   name = "Dash",   path = "./apps/dash"),
      list(id = "report", name = "Report", path = "./apps/report",
           runtime_strategy = "bundled")
    )
  )
  apps_manifest <- list(
    list(id = "dash", name = "Dash", path = "src/apps/dash",
         type = "r-shiny", runtime_strategy = "shinylive"),
    list(id = "report", name = "Report", path = "src/apps/report",
         type = "r-shiny", runtime_strategy = "bundled")
  )

  # Stub everything after the guard so that, absent the fix, build_multi_app
  # would complete without error (making the missing abort observable).
  mockery::stub(build_multi_app, "validate_node_npm", function() invisible(TRUE))
  mockery::stub(build_multi_app, "setup_electron_project", function(...) invisible(TRUE))
  mockery::stub(build_multi_app, "process_templates", function(...) invisible(TRUE))
  mockery::stub(build_multi_app, "install_npm_dependencies", function(...) invisible(TRUE))
  mockery::stub(build_multi_app, "build_for_platforms", function(...) invisible(TRUE))

  expect_error(
    build_multi_app(
      apps_dir = apps_dir, output_dir = output_dir, app_name = "Suite",
      apps_manifest = apps_manifest, default_type = "r-shiny",
      runtime_strategy = "shinylive", sign = FALSE,
      platform = c("win", "mac"), arch = "x64", icon = NULL,
      config = config, overwrite = TRUE, verbose = FALSE
    ),
    "only one platform"
  )
})

test_that("export rejects a one-app apps: suite with a clear error", {
  appdir <- withr::local_tempdir()
  dir.create(file.path(appdir, "apps", "solo"), recursive = TRUE)
  writeLines("library(shiny)\nshinyApp(ui=fluidPage(), server=function(i,o){})",
             file.path(appdir, "apps", "solo", "app.R"))
  yaml::write_yaml(list(
    app = list(name = "Solo Suite"),
    build = list(type = "r-shiny"),
    apps = list(
      list(id = "solo", name = "Solo", path = "./apps/solo")
    )
  ), file.path(appdir, "_shinyelectron.yml"))

  destdir <- file.path(withr::local_tempdir(), "out")
  err <- expect_error(
    export(appdir = appdir, destdir = destdir, build = FALSE, verbose = FALSE),
    class = "shinyelectron_one_app_suite"
  )
  expect_match(conditionMessage(err), "2 apps", fixed = TRUE)
})

test_that("build_multi_app embeds the R runtime once with the unioned package set", {
  skip_if_not_installed("mockery")

  apps_dir <- withr::local_tempdir()
  output_dir <- file.path(withr::local_tempdir(), "electron-app")

  config <- list(
    build = list(type = "r-shiny", runtime_strategy = "bundled"),
    apps = list(
      list(id = "dash",   name = "Dash",   path = "./apps/dash"),
      list(id = "report", name = "Report", path = "./apps/report")
    )
  )
  apps_manifest <- list(
    list(id = "dash", name = "Dash", path = "src/apps/dash",
         type = "r-shiny", runtime_strategy = "bundled"),
    list(id = "report", name = "Report", path = "src/apps/report",
         type = "r-shiny", runtime_strategy = "bundled")
  )

  # Direct union of each app's packages, deliberately unsorted with a duplicate.
  union_pkgs <- c("shiny", "bslib", "shiny", "DT")

  captured <- NULL
  n_calls <- 0
  mockery::stub(build_multi_app, "embed_r_runtime",
    function(output_dir, packages, repos, version, platform, arch, verbose = TRUE) {
      captured <<- packages
      n_calls <<- n_calls + 1
      invisible(TRUE)
    })
  mockery::stub(build_multi_app, "validate_node_npm", function() invisible(TRUE))
  mockery::stub(build_multi_app, "setup_electron_project", function(...) invisible(TRUE))
  mockery::stub(build_multi_app, "process_templates", function(...) invisible(TRUE))
  mockery::stub(build_multi_app, "install_npm_dependencies", function(...) invisible(TRUE))
  mockery::stub(build_multi_app, "build_for_platforms", function(...) invisible(TRUE))
  mockery::stub(build_multi_app, "validate_build_output", function(...) invisible(TRUE))

  build_multi_app(
    apps_dir = apps_dir, output_dir = output_dir, app_name = "Suite",
    apps_manifest = apps_manifest, default_type = "r-shiny",
    runtime_strategy = "bundled", sign = FALSE,
    platform = "mac", arch = "arm64", icon = NULL, config = config,
    overwrite = TRUE, verbose = FALSE,
    r_packages = union_pkgs
  )

  expect_equal(n_calls, 1)
  expect_equal(captured, sort(unique(union_pkgs)))
})

test_that("build_multi_app writes runtime-manifest.json into each auto-download app dir", {
  skip_if_not_installed("mockery")

  apps_dir <- withr::local_tempdir()
  dir.create(file.path(apps_dir, "dash"))
  dir.create(file.path(apps_dir, "report"))
  writeLines("library(shiny)", file.path(apps_dir, "dash", "app.R"))
  writeLines("library(shiny)", file.path(apps_dir, "report", "app.R"))

  output_dir <- file.path(withr::local_tempdir(), "electron-app")

  config <- list(
    build = list(type = "r-shiny", runtime_strategy = "auto-download"),
    apps = list(
      list(id = "dash",   name = "Dash",   path = "./apps/dash"),
      list(id = "report", name = "Report", path = "./apps/report")
    )
  )
  apps_manifest <- list(
    list(id = "dash", name = "Dash", path = "src/apps/dash",
         type = "r-shiny", runtime_strategy = "auto-download"),
    list(id = "report", name = "Report", path = "src/apps/report",
         type = "r-shiny", runtime_strategy = "auto-download")
  )

  mockery::stub(build_multi_app, "validate_node_npm", function() invisible(TRUE))
  mockery::stub(build_multi_app, "setup_electron_project", function(...) invisible(TRUE))
  mockery::stub(build_multi_app, "process_templates", function(...) invisible(TRUE))
  mockery::stub(build_multi_app, "install_npm_dependencies", function(...) invisible(TRUE))
  mockery::stub(build_multi_app, "build_for_platforms", function(...) invisible(TRUE))
  mockery::stub(build_multi_app, "validate_build_output", function(...) invisible(TRUE))

  build_multi_app(
    apps_dir = apps_dir, output_dir = output_dir, app_name = "Suite",
    apps_manifest = apps_manifest, default_type = "r-shiny",
    runtime_strategy = "auto-download", sign = FALSE,
    platform = "mac", arch = "arm64", icon = NULL, config = config,
    overwrite = TRUE, verbose = FALSE
  )

  expect_true(fs::file_exists(
    fs::path(output_dir, "src", "apps", "dash", "runtime-manifest.json")))
  expect_true(fs::file_exists(
    fs::path(output_dir, "src", "apps", "report", "runtime-manifest.json")))
})

test_that("resolve_brand_yml finds _brand.yml for native serve descriptor", {
  output_dir <- withr::local_tempdir()
  brand_dir <- file.path(output_dir, "src", "apps", "dash")
  dir.create(brand_dir, recursive = TRUE)
  writeLines("meta:\n  name: Dash", file.path(brand_dir, "_brand.yml"))

  apps_manifest <- list(
    list(
      id = "dash",
      serve = list(kind = "native", path = "src/apps/dash",
                   runtime_strategy = "system")
    )
  )

  result <- resolve_brand_yml(output_dir, TRUE, apps_manifest)
  expect_false(is.null(result))
  expect_equal(result$meta$name, "Dash")
})

test_that("resolve_brand_yml finds _brand.yml for shinylive serve descriptor", {
  output_dir <- withr::local_tempdir()
  brand_dir <- file.path(output_dir, "src", "shinylive-site", "viewer")
  dir.create(brand_dir, recursive = TRUE)
  writeLines("meta:\n  name: Viewer", file.path(brand_dir, "_brand.yml"))

  apps_manifest <- list(
    list(
      id = "viewer",
      serve = list(kind = "shinylive", site = "src/shinylive-site",
                   subdir = "viewer")
    )
  )

  result <- resolve_brand_yml(output_dir, TRUE, apps_manifest)
  expect_false(is.null(result))
  expect_equal(result$meta$name, "Viewer")
})

test_that("export_multi_app stages one shared shinylive site and build copies it once", {
  skip_if_not_installed("mockery")

  appdir <- withr::local_tempdir()
  dir.create(file.path(appdir, "apps", "alpha"), recursive = TRUE)
  dir.create(file.path(appdir, "apps", "beta"), recursive = TRUE)
  writeLines("library(shiny)\nshinyApp(ui=fluidPage(), server=function(i,o){})",
             file.path(appdir, "apps", "alpha", "app.R"))
  writeLines("library(shiny)\nshinyApp(ui=fluidPage(), server=function(i,o){})",
             file.path(appdir, "apps", "beta", "app.R"))

  yaml::write_yaml(list(
    app = list(name = "Suite", version = "1.0.0"),
    build = list(type = "r-shiny", runtime_strategy = "shinylive"),
    apps = list(
      list(id = "alpha", name = "Alpha", path = "./apps/alpha"),
      list(id = "beta",  name = "Beta",  path = "./apps/beta")
    )
  ), file.path(appdir, "_shinyelectron.yml"))

  config  <- read_config(appdir)
  destdir <- withr::local_tempdir()

  # Fake the converter: write the per-app subdir entry plus a SHARED, additive
  # shinylive/ asset tree at the site root (the subdir export model).
  fake_convert <- function(appdir, output_dir, subdir = NULL,
                           overwrite = FALSE, verbose = TRUE) {
    fs::dir_create(output_dir, recurse = TRUE)
    fs::dir_create(fs::path(output_dir, "shinylive"), recurse = TRUE)
    writeLines("asset", fs::path(output_dir, "shinylive", "webr.js"))
    fs::dir_create(fs::path(output_dir, subdir), recurse = TRUE)
    writeLines("<html></html>", fs::path(output_dir, subdir, "index.html"))
    fs::path_abs(output_dir)
  }

  testthat::local_mocked_bindings(
    convert_shiny_to_shinylive = fake_convert,
    validate_node_npm        = function(...) invisible(TRUE),
    setup_electron_project   = function(output_dir, ...) {
      fs::dir_create(fs::path(output_dir, "src"), recurse = TRUE); invisible(output_dir)
    },
    process_templates        = function(...) invisible(TRUE),
    install_npm_dependencies = function(...) invisible(TRUE),
    build_for_platforms      = function(...) invisible(TRUE)
  )

  result <- export_multi_app(
    appdir = appdir, destdir = destdir, config = config,
    app_name = "Suite", overwrite = TRUE, build = TRUE, verbose = FALSE
  )
  out <- result$electron_app

  # Exactly one shared asset tree + two app subdirs under the shared site.
  expect_true(fs::dir_exists(fs::path(out, "src", "shinylive-site", "shinylive")))
  expect_true(fs::dir_exists(fs::path(out, "src", "shinylive-site", "alpha")))
  expect_true(fs::dir_exists(fs::path(out, "src", "shinylive-site", "beta")))
  expect_true(fs::file_exists(fs::path(out, "src", "shinylive-site", "alpha", "index.html")))

  # No per-app shinylive copies leaked into src/apps/<id> (Defect 2 stays fixed).
  expect_false(fs::dir_exists(fs::path(out, "src", "apps", "alpha")))
  expect_false(fs::dir_exists(fs::path(out, "src", "apps", "beta")))

  # Serve descriptors, order preserved, no stray top-level path.
  expect_equal(result$apps[[1]]$serve$kind, "shinylive")
  expect_equal(result$apps[[1]]$serve$site, "src/shinylive-site")
  expect_equal(result$apps[[1]]$serve$subdir, "alpha")
  expect_equal(result$apps[[2]]$serve$subdir, "beta")
  expect_null(result$apps[[1]]$path)
})

# --- Bundled-union scoping bug (container packages must not reach embed_r_runtime) ---

test_that("export_multi_app does not include container-app packages in bundled embed", {
  # Fixture: two R apps -- one bundled, one container. The bundled app declares
  # pkgA; the container app declares pkgB. After the fix, embed_r_runtime must
  # receive only pkgA.  Before the fix it received both, because the union
  # accumulation was gated on app TYPE not app STRATEGY.

  appdir <- withr::local_tempdir()
  dir.create(file.path(appdir, "apps", "rbundled"), recursive = TRUE)
  dir.create(file.path(appdir, "apps", "rcontainer"), recursive = TRUE)
  writeLines(
    "library(shiny)\nshinyApp(ui=fluidPage(), server=function(i,o){})",
    file.path(appdir, "apps", "rbundled", "app.R")
  )
  writeLines(
    "library(shiny)\nshinyApp(ui=fluidPage(), server=function(i,o){})",
    file.path(appdir, "apps", "rcontainer", "app.R")
  )

  config <- list(
    app  = list(name = "Suite", version = "1.0.0"),
    build = list(type = "r-shiny", runtime_strategy = "bundled"),
    apps = list(
      list(id = "rbundled",   name = "Bundled App",   path = "./apps/rbundled"),
      list(id = "rcontainer", name = "Container App", path = "./apps/rcontainer",
           runtime_strategy = "container")
    )
  )

  destdir <- withr::local_tempdir()
  captured_packages <- NULL

  local_mocked_bindings(
    # Controlled dependency resolution: bundled app gets pkgA, container gets pkgB.
    resolve_app_dependencies = function(appdir, app_type, runtime_strategy, config) {
      if (identical(runtime_strategy, "bundled")) {
        list(language = "r", packages = c("pkgA"), repos = list())
      } else {
        list(language = "r", packages = c("pkgB"), repos = list())
      }
    },
    # Avoid network calls inside generate_dependency_manifest (query_sysreqs).
    generate_dependency_manifest = function(packages, language,
                                            repos = NULL, index_urls = NULL) {
      '{"schema_version":"2","language":"r","packages":[]}'
    },
    # Capture what embed_r_runtime receives.
    embed_r_runtime = function(output_dir, packages, repos, version,
                               platform, arch, verbose = TRUE) {
      captured_packages <<- packages
      invisible(TRUE)
    },
    # Stub the heavy build-pipeline steps that require npm / Electron.
    validate_node_npm        = function(...) invisible(TRUE),
    setup_electron_project   = function(output_dir, ...) {
      fs::dir_create(fs::path(output_dir, "src"), recurse = TRUE)
      invisible(output_dir)
    },
    process_templates        = function(...) invisible(TRUE),
    install_npm_dependencies = function(...) invisible(TRUE),
    build_for_platforms      = function(...) invisible(TRUE),
    validate_build_output    = function(...) invisible(TRUE)
  )

  export_multi_app(
    appdir   = appdir,
    destdir  = destdir,
    config   = config,
    app_name = "Suite",
    platform = "mac",
    arch     = "arm64",
    build    = TRUE,
    overwrite = TRUE,
    verbose  = FALSE
  )

  expect_true("pkgA" %in% captured_packages,
    label = "bundled app's package (pkgA) must reach embed_r_runtime")
  expect_false("pkgB" %in% captured_packages,
    label = "container app's package (pkgB) must NOT reach embed_r_runtime")
})
