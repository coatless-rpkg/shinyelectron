# An app directory named `dir` holding a minimal R Shiny app and, when
# `config` is given, a _shinyelectron.yml written from it.
local_app <- function(dir = "dash-app", config = NULL, env = parent.frame()) {
  appdir <- file.path(withr::local_tempdir(.local_envir = env), dir)
  dir.create(appdir)
  writeLines(
    "library(shiny)\nshinyApp(ui = fluidPage(), server = function(input, output) {})",
    file.path(appdir, "app.R")
  )
  if (!is.null(config)) {
    yaml::write_yaml(config, file.path(appdir, "_shinyelectron.yml"))
  }
  appdir
}

# Run export() with conversion and the Electron build replaced, returning the
# arguments build_electron_app() received.
export_args <- function(appdir, ...) {
  rec <- mockery::mock()
  mockery::stub(export, "convert_app_to_shinylive", function(...) tempdir())
  mockery::stub(export, "build_electron_app", function(...) {
    rec(...)
    tempdir()
  })
  export(appdir, withr::local_tempdir(), build = TRUE, overwrite = TRUE,
         verbose = FALSE, ...)
  # The arguments of the last call, or NULL when the build was never reached.
  calls <- mockery::mock_args(rec)
  if (length(calls) == 0) NULL else calls[[length(calls)]]
}

non_ascii_name <- "\u6570\u636e\u5206\u6790"

# --- resolve_app_slug() ---

test_that("resolve_app_slug prefers app.slug, then the given name, then the directory", {
  expect_equal(
    resolve_app_slug(list(app = list(slug = "pinned")), "Sales Dashboard", "/x/dash-app"),
    "pinned"
  )
  expect_equal(resolve_app_slug(list(), "Sales Dashboard", "/x/dash-app"), "sales-dashboard")
  expect_equal(resolve_app_slug(list(), NULL, "/x/dash-app"), "dash-app")
  expect_null(resolve_app_slug(list(), NULL, paste0("/x/", non_ascii_name)))
})

test_that("resolve_app_slug falls back to the directory for a name without ASCII letters", {
  expect_message(
    slug <- resolve_app_slug(list(), non_ascii_name, "/x/dash-app"),
    "directory name"
  )
  expect_equal(slug, "dash-app")
  expect_null(resolve_app_slug(list(), non_ascii_name, paste0("/x/", non_ascii_name)))
})

# --- export() ---

test_that("export() takes the display name from app.name and the slug from the directory", {
  appdir <- local_app("dash-app", list(app = list(name = "Sales Dashboard")))
  expect_no_warning(args <- export_args(appdir))
  expect_equal(args$app_name, "Sales Dashboard")
  expect_equal(args$config$app$slug, "dash-app")

  # A directory whose name matches gives the matching slug.
  same <- local_app("sales-dashboard", list(app = list(name = "Sales Dashboard")))
  expect_equal(export_args(same)$config$app$slug, "sales-dashboard")
})

test_that("export() takes the slug from app.slug when it is set", {
  appdir <- local_app("dash-app", list(app = list(name = "Sales Dashboard", slug = "sales")))
  args <- export_args(appdir)
  expect_equal(args$app_name, "Sales Dashboard")
  expect_equal(args$config$app$slug, "sales")
})

test_that("export() takes the slug from an app_name argument", {
  appdir <- local_app("dash-app", list(app = list(name = "Sales Dashboard")))
  args <- export_args(appdir, app_name = "Custom Name")
  expect_equal(args$app_name, "Custom Name")
  expect_equal(args$config$app$slug, "custom-name")
})

test_that("export() falls back to the directory slug for a non-ASCII app_name argument", {
  appdir <- local_app("dash-app")
  expect_message(args <- export_args(appdir, app_name = non_ascii_name), "directory name")
  expect_equal(args$app_name, non_ascii_name)
  expect_equal(args$config$app$slug, "dash-app")
})

test_that("a non-ASCII app.name sets only the display name", {
  appdir <- local_app("dash-app", list(app = list(name = non_ascii_name)))
  expect_no_message(args <- export_args(appdir))
  expect_equal(args$app_name, non_ascii_name)
  expect_equal(args$config$app$slug, "dash-app")
})

# The messages export() prints with verbose = TRUE, with the build replaced.
export_messages <- function(appdir, ...) {
  mockery::stub(export, "convert_app_to_shinylive", function(...) tempdir())
  mockery::stub(export, "build_electron_app", function(...) tempdir())
  testthat::capture_messages(
    export(appdir, withr::local_tempdir(), overwrite = TRUE, verbose = TRUE, ...)
  )
}

test_that("export() shows the slug, and how to change it when the folder gives it", {
  from_folder <- export_messages(local_app("dash-app", list(app = list(name = "Sales Dashboard"))))
  expect_true(any(grepl('Application: "Sales Dashboard" (slug: "dash-app")', from_folder, fixed = TRUE)))
  expect_true(any(grepl("app.slug", from_folder, fixed = TRUE)))

  pinned <- export_messages(local_app("dash-app", list(app = list(name = "Sales Dashboard", slug = "sales"))))
  expect_true(any(grepl('Application: "Sales Dashboard" (slug: "sales")', pinned, fixed = TRUE)))
  expect_false(any(grepl("app.slug", pinned, fixed = TRUE)))

  # Without app.name the display name gives the same slug, so no note.
  plain <- export_messages(local_app("dash-app"))
  expect_true(any(grepl('Application: "dash-app" (slug: "dash-app")', plain, fixed = TRUE)))
  expect_false(any(grepl("app.slug", plain, fixed = TRUE)))
})

test_that("export() builds package.json from the resolved name and slug", {
  local_mocked_bindings(
    convert_app_to_shinylive = function(appdir, destdir, ...) {
      out <- fs::path(destdir, "shinylive-app")
      fs::dir_create(out)
      writeLines("<html></html>", fs::path(out, "index.html"))
      out
    },
    validate_node_npm = function(...) invisible(TRUE),
    install_npm_dependencies = function(...) invisible(TRUE),
    build_for_platforms = function(...) invisible(TRUE),
    validate_build_output = function(...) invisible(TRUE)
  )
  package_json_for <- function(config) {
    appdir <- local_app("dash-app", config)
    result <- export(appdir, withr::local_tempdir(), overwrite = TRUE, verbose = FALSE)
    jsonlite::fromJSON(fs::path(result$electron_app, "package.json"))
  }

  pkg <- package_json_for(list(app = list(name = "Sales Dashboard")))
  expect_equal(pkg$name, "dash-app")
  expect_equal(pkg$build$appId, "com.shinyelectron.dash-app")
  expect_equal(pkg$build$productName, "Sales Dashboard")
  expect_equal(pkg$build$win$executableName, "dash-app")

  pinned <- package_json_for(list(app = list(name = "Sales Dashboard", slug = "sales")))
  expect_equal(pinned$name, "sales")
  expect_equal(pinned$build$appId, "com.shinyelectron.sales")
})

test_that("a suite takes its display name from app.name and its slug from the directory", {
  appdir <- local_app("suite-dir", list(
    app = list(name = "Sales Tools"),
    build = list(type = "r-shiny", runtime_strategy = "shinylive"),
    apps = list(
      list(id = "a", name = "A", path = "apps/a"),
      list(id = "b", name = "B", path = "apps/b")
    )
  ))
  for (id in c("a", "b")) {
    dir.create(file.path(appdir, "apps", id), recursive = TRUE)
    file.copy(file.path(appdir, "app.R"), file.path(appdir, "apps", id))
  }
  rec <- mockery::mock()
  local_mocked_bindings(
    convert_shiny_to_shinylive = function(appdir, output_dir, subdir = NULL, ...) {
      fs::dir_create(fs::path(output_dir, subdir), recurse = TRUE)
      writeLines("<html></html>", fs::path(output_dir, subdir, "index.html"))
      fs::path_abs(output_dir)
    },
    validate_node_npm = function(...) invisible(TRUE),
    process_templates = function(output_dir, app_name, app_type, ..., config = NULL) {
      rec(app_name = app_name, slug = config$app$slug)
      invisible(TRUE)
    },
    install_npm_dependencies = function(...) invisible(TRUE),
    build_for_platforms = function(...) invisible(TRUE),
    validate_build_output = function(...) invisible(TRUE)
  )
  expect_no_warning(
    export(appdir, withr::local_tempdir(), overwrite = TRUE, verbose = FALSE)
  )
  calls <- mockery::mock_args(rec)
  captured <- if (length(calls) == 0) NULL else calls[[length(calls)]]
  expect_equal(captured$app_name, "Sales Tools")
  expect_equal(captured$slug, "suite-dir")
})

# --- init_config() and show_config() ---

test_that("init_config() writes the directory's slug", {
  appdir <- local_app("dash-app")
  init_config(appdir, app_name = "Sales Dashboard", verbose = FALSE)
  lines <- readLines(file.path(appdir, "_shinyelectron.yml"))
  expect_true('  name: "Sales Dashboard"' %in% lines)
  expect_true('  slug: "dash-app"' %in% lines)
  expect_equal(read_config(appdir)$app$slug, "dash-app")
})

test_that("show_config() reports the slug that export() would use", {
  appdir <- local_app("dash-app", list(app = list(name = non_ascii_name)))
  output <- cli::cli_fmt(show_config(appdir))
  expect_true(any(grepl("Slug: \"dash-app\"", output, fixed = TRUE)))

  pinned <- local_app("dash-app", list(app = list(name = "Sales", slug = "sales")))
  output <- cli::cli_fmt(show_config(pinned))
  expect_true(any(grepl("Slug: \"sales\"", output, fixed = TRUE)))
})

# --- app.name and app.slug values ---

test_that("read_config reads a numeric app.name or app.slug as text", {
  appdir <- local_app("dash-app")
  writeLines(c("app:", "  name: 2048", "  slug: 2048"), file.path(appdir, "_shinyelectron.yml"))
  config <- read_config(appdir)
  expect_identical(config$app$name, "2048")
  expect_identical(config$app$slug, "2048")
})

test_that("export() takes a numeric app.name as the display name", {
  appdir <- local_app("dash-app")
  writeLines(c("app:", "  name: 2048", "  slug: dash-app"), file.path(appdir, "_shinyelectron.yml"))
  expect_identical(export_args(appdir)$app_name, "2048")
})

test_that("an invalid app.name is reported under its config key", {
  for (value in c('""', "yes", "[Sales, Dashboard]")) {
    appdir <- local_app("dash-app")
    writeLines(c("app:", paste("  name:", value)), file.path(appdir, "_shinyelectron.yml"))
    error <- expect_error(export_args(appdir), "app.name", fixed = TRUE, info = value)
    expect_no_match(conditionMessage(error), "app_name", fixed = TRUE)
  }
})

# --- Checking the slug before a build ---

test_that("check_app_slug accepts a valid slug and names app.slug otherwise", {
  expect_invisible(check_app_slug("dash-app"))
  for (slug in list("My Slug", "-dash", 42, c("a", "b"))) {
    expect_error(check_app_slug(slug), "app.slug", fixed = TRUE,
                 class = "shinyelectron_invalid_slug")
  }
  expect_error(check_app_slug(NULL), class = "shinyelectron_invalid_slug")
})

test_that("export() rejects an invalid app.slug before converting the app", {
  appdir <- local_app("dash-app", list(app = list(name = "Sales", slug = "Sales Dashboard")))
  mockery::stub(export, "convert_app_to_shinylive", function(...) stop("converted"))
  expect_error(
    export(appdir, withr::local_tempdir(), overwrite = TRUE, verbose = FALSE),
    class = "shinyelectron_invalid_slug"
  )
})

test_that("export() stops early when the directory gives no slug", {
  appdir <- local_app(non_ascii_name)
  mockery::stub(export, "convert_app_to_shinylive", function(...) stop("converted"))
  expect_error(
    export(appdir, withr::local_tempdir(), overwrite = TRUE, verbose = FALSE),
    class = "shinyelectron_invalid_slug"
  )
  # Without a build no slug is needed.
  mockery::stub(export, "convert_app_to_shinylive", function(...) tempdir())
  expect_no_error(
    export(appdir, withr::local_tempdir(), build = FALSE, overwrite = TRUE, verbose = FALSE)
  )
})

test_that("export_multi_app() checks the slug before a build too", {
  appdir <- local_app("suite-dir")
  config <- list(
    app = list(name = "Sales Tools", slug = "Sales Tools"),
    build = list(type = "r-shiny", runtime_strategy = "shinylive"),
    apps = list(list(id = "a", name = "A", path = "."), list(id = "b", name = "B", path = "."))
  )
  expect_error(
    export_multi_app(appdir, withr::local_tempdir(), config, overwrite = TRUE, verbose = FALSE),
    class = "shinyelectron_invalid_slug"
  )
})

test_that("init_config() says to set app.slug when none can be derived", {
  appdir <- local_app(non_ascii_name)
  messages <- testthat::capture_messages(init_config(appdir))
  expect_true(any(grepl("app.slug", messages, fixed = TRUE)))
  lines <- readLines(file.path(appdir, "_shinyelectron.yml"))
  expect_true(any(startsWith(lines, "  # slug: null")))
  expect_null(read_config(appdir)$app$slug)
})

test_that("init_config() warns when replacing a config changes the slug", {
  # The replaced config pinned a slug that is not the directory's.
  appdir <- local_app("dash-app", list(app = list(name = "Sales", slug = "sales")))
  expect_warning(
    init_config(appdir, app_name = "Sales", overwrite = TRUE, verbose = FALSE),
    '"sales"', class = "shinyelectron_config_slug_changed"
  )
  # Without app.slug the replaced config gave the directory's slug, which the
  # new one keeps, whatever the name.
  unpinned <- local_app("dash-app", list(app = list(name = "Sales Dashboard")))
  expect_no_warning(
    init_config(unpinned, app_name = "Sales Dashboard", overwrite = TRUE, verbose = FALSE)
  )
  # A fresh config has nothing to compare with.
  expect_no_warning(init_config(local_app("new-app"), app_name = "Sales Dashboard", verbose = FALSE))
})

# --- An app directory given as "." or ".." ---

# Enter a new app directory named `dir`, which also holds an empty folder
# "sub", for the rest of the calling test.
local_app_wd <- function(dir = "dash-app", config = NULL, env = parent.frame()) {
  appdir <- local_app(dir, config, env = env)
  dir.create(file.path(appdir, "sub"))
  withr::local_dir(appdir, .local_envir = env)
  appdir
}

test_that("resolve_app_slug takes the slug from the folder that '.' or '..' points to", {
  local_app_wd()
  expect_equal(resolve_app_slug(list(), NULL, "."), "dash-app")
  expect_equal(resolve_app_slug(list(), NULL, "./"), "dash-app")
  expect_message(
    slug <- resolve_app_slug(list(), non_ascii_name, "."),
    "dash-app", fixed = TRUE
  )
  expect_equal(slug, "dash-app")

  withr::local_dir("sub")
  expect_equal(resolve_app_slug(list(), NULL, ".."), "dash-app")
  expect_equal(resolve_app_slug(list(), NULL, "../sub/.."), "dash-app")
})

test_that("export() names the app after the folder that '.' or '..' points to", {
  local_app_wd()
  # Without a build no slug is needed, but the output still shows both.
  messages <- export_messages(".", build = FALSE)
  expect_true(any(grepl('Application: "dash-app" (slug: "dash-app")', messages, fixed = TRUE)))
  args <- export_args(".")
  expect_equal(args$app_name, "dash-app")
  expect_equal(args$config$app$slug, "dash-app")

  withr::local_dir("sub")
  messages <- export_messages("..", build = FALSE)
  expect_true(any(grepl('Application: "dash-app" (slug: "dash-app")', messages, fixed = TRUE)))
  args <- export_args("..")
  expect_equal(args$app_name, "dash-app")
  expect_equal(args$config$app$slug, "dash-app")
})

test_that("a suite given as '.' is named after its folder", {
  local_app_wd("suite-dir")
  config <- list(
    build = list(type = "r-shiny", runtime_strategy = "shinylive"),
    apps = list(list(id = "a", name = "A", path = "."), list(id = "b", name = "B", path = "."))
  )
  local_mocked_bindings(convert_shiny_to_shinylive = function(...) invisible(NULL))
  messages <- testthat::capture_messages(
    export_multi_app(".", withr::local_tempdir(), config, overwrite = TRUE, build = FALSE)
  )
  expect_true(any(grepl('Suite: "suite-dir" (slug: "suite-dir")', messages, fixed = TRUE)))
})

test_that("build_electron_app() names an app given as '.' after its folder", {
  local_mocked_bindings(
    validate_node_npm = function(...) invisible(TRUE),
    install_npm_dependencies = function(...) invisible(TRUE),
    build_for_platforms = function(...) invisible(TRUE),
    validate_build_output = function(...) invisible(TRUE)
  )
  local_app_wd()
  out <- build_electron_app(".", fs::path(withr::local_tempdir(), "electron-app"),
                            verbose = FALSE)
  pkg <- jsonlite::fromJSON(fs::path(out, "package.json"))
  expect_equal(pkg$name, "dash-app")
  expect_equal(pkg$build$productName, "dash-app")
})

test_that("init_config() names the app after the folder that '.' or '..' points to", {
  local_app_wd()
  init_config(".", verbose = FALSE)
  config <- read_config(".")
  expect_equal(config$app$name, "dash-app")
  expect_equal(config$app$slug, "dash-app")

  withr::local_dir("sub")
  init_config("..", overwrite = TRUE, verbose = FALSE)
  config <- read_config("..")
  expect_equal(config$app$name, "dash-app")
  expect_equal(config$app$slug, "dash-app")
})

test_that("show_config() names the app after the folder that '.' or '..' points to", {
  local_app_wd()
  # The app directory defaults to ".".
  output <- cli::cli_fmt(show_config())
  expect_true(any(grepl('Name: "dash-app"', output, fixed = TRUE)))
  expect_true(any(grepl('Slug: "dash-app"', output, fixed = TRUE)))

  withr::local_dir("sub")
  output <- cli::cli_fmt(show_config(".."))
  expect_true(any(grepl('Name: "dash-app"', output, fixed = TRUE)))
  expect_true(any(grepl('Slug: "dash-app"', output, fixed = TRUE)))
})

test_that("a linked app directory is named after the link, not its target", {
  # A config without app.slug, so the slug comes from the directory's name.
  target <- local_app("dash-app-v2", list(app = list(name = "Sales")))
  link <- file.path(dirname(target), "dash-app")
  linked <- suppressWarnings(file.symlink(target, link))
  skip_if_not(linked, "Symbolic links are not supported on this system")

  # app_check() and init_config() agree with export(), which takes the slug
  # from the link's name rather than from the folder it points to.
  expect_equal(export_args(link)$config$app$slug, "dash-app")
  checked <- testthat::capture_messages(app_check(link))
  # The space keeps "dash-app-v2" from matching.
  expect_true(any(grepl("App Check: dash-app\\s", checked)))
  expect_true(any(grepl('App slug: "dash-app"', checked, fixed = TRUE)))

  # The config being replaced had the link's slug too, so nothing changes.
  expect_no_warning(init_config(link, overwrite = TRUE, verbose = FALSE))
  expect_equal(read_config(link)$app$slug, "dash-app")
})
