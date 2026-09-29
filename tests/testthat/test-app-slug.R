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
  captured <- NULL
  mockery::stub(export, "convert_app_to_shinylive", function(...) tempdir())
  mockery::stub(export, "build_electron_app", function(...) {
    captured <<- list(...)
    tempdir()
  })
  export(appdir, withr::local_tempdir(), build = TRUE, overwrite = TRUE,
         verbose = FALSE, ...)
  captured
}

non_ascii_name <- "数据分析"

# --- resolve_app_slug() ---

test_that("resolve_app_slug prefers app.slug, then the name", {
  expect_equal(
    resolve_app_slug(list(app = list(slug = "pinned")), "Sales Dashboard", "/x/dash-app"),
    "pinned"
  )
  expect_equal(resolve_app_slug(list(), "Sales Dashboard", "/x/dash-app"), "sales-dashboard")
})

test_that("resolve_app_slug falls back to the directory for a name without ASCII letters", {
  expect_message(
    slug <- resolve_app_slug(list(), non_ascii_name, "/x/dash-app"),
    "directory name"
  )
  expect_equal(slug, "dash-app")
  expect_null(resolve_app_slug(list(), non_ascii_name, paste0("/x/", non_ascii_name)))
})

test_that("resolve_app_slug warns only when app.name moves the slug", {
  expect_warning(
    resolve_app_slug(list(), "Sales Dashboard", "/x/dash-app", name_from_config = TRUE),
    class = "shinyelectron_slug_changed"
  )
  expect_no_warning(
    resolve_app_slug(list(), "Sales Dashboard", "/x/sales-dashboard", name_from_config = TRUE)
  )
  expect_no_warning(resolve_app_slug(list(), "Sales Dashboard", "/x/dash-app"))
  expect_no_warning(resolve_app_slug(
    list(app = list(slug = "dash-app")), "Sales Dashboard", "/x/dash-app",
    name_from_config = TRUE
  ))
})

# --- export() ---

test_that("export() warns when app.name changes the slug and names both slugs", {
  appdir <- local_app("dash-app", list(app = list(name = "Sales Dashboard")))
  warning <- expect_warning(
    args <- export_args(appdir),
    class = "shinyelectron_slug_changed"
  )
  expect_equal(args$app_name, "Sales Dashboard")
  expect_equal(args$config$app$slug, "sales-dashboard")
  message <- conditionMessage(warning)
  expect_match(message, "sales-dashboard", fixed = TRUE)
  expect_match(message, 'slug: "dash-app"', fixed = TRUE)
})

test_that("export() keeps quiet when app.slug is set or the slugs agree", {
  pinned <- local_app("dash-app", list(app = list(name = "Sales Dashboard", slug = "dash-app")))
  expect_no_warning(args <- export_args(pinned))
  expect_equal(args$app_name, "Sales Dashboard")
  expect_equal(args$config$app$slug, "dash-app")

  same <- local_app("sales-dashboard", list(app = list(name = "Sales Dashboard")))
  expect_no_warning(args <- export_args(same))
  expect_equal(args$config$app$slug, "sales-dashboard")
})

test_that("export() takes the slug from an app_name argument without a warning", {
  appdir <- local_app("dash-app", list(app = list(name = "Sales Dashboard")))
  expect_no_warning(args <- export_args(appdir, app_name = "Custom Name"))
  expect_equal(args$app_name, "Custom Name")
  expect_equal(args$config$app$slug, "custom-name")
})

test_that("export() falls back to the directory slug for a non-ASCII app.name", {
  appdir <- local_app("dash-app", list(app = list(name = non_ascii_name)))
  expect_message(args <- export_args(appdir), "directory name")
  expect_equal(args$app_name, non_ascii_name)
  expect_equal(args$config$app$slug, "dash-app")
})

test_that("export() builds package.json from the resolved name and slug", {
  appdir <- local_app("dash-app", list(app = list(name = "Sales Dashboard", slug = "dash-app")))
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
  result <- export(appdir, withr::local_tempdir(), overwrite = TRUE, verbose = FALSE)
  pkg <- jsonlite::fromJSON(fs::path(result$electron_app, "package.json"))
  expect_equal(pkg$name, "dash-app")
  expect_equal(pkg$build$appId, "com.shinyelectron.dash-app")
  expect_equal(pkg$build$productName, "Sales Dashboard")
  expect_equal(pkg$build$win$executableName, "dash-app")
})

test_that("a suite follows the same slug rules and warns once", {
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
  captured <- NULL
  local_mocked_bindings(
    convert_shiny_to_shinylive = function(appdir, output_dir, subdir = NULL, ...) {
      fs::dir_create(fs::path(output_dir, subdir), recurse = TRUE)
      writeLines("<html></html>", fs::path(output_dir, subdir, "index.html"))
      fs::path_abs(output_dir)
    },
    validate_node_npm = function(...) invisible(TRUE),
    process_templates = function(output_dir, app_name, app_type, ..., config = NULL) {
      captured <<- list(app_name = app_name, slug = config$app$slug)
      invisible(TRUE)
    },
    install_npm_dependencies = function(...) invisible(TRUE),
    build_for_platforms = function(...) invisible(TRUE),
    validate_build_output = function(...) invisible(TRUE)
  )
  changes <- 0L
  withCallingHandlers(
    export(appdir, withr::local_tempdir(), overwrite = TRUE, verbose = FALSE),
    shinyelectron_slug_changed = function(w) {
      changes <<- changes + 1L
      invokeRestart("muffleWarning")
    }
  )
  expect_equal(changes, 1L)
  expect_equal(captured$app_name, "Sales Tools")
  expect_equal(captured$slug, "sales-tools")
})

# --- init_config() and show_config() ---

test_that("init_config() writes an explicit slug", {
  appdir <- local_app("dash-app")
  init_config(appdir, app_name = "Sales Dashboard", verbose = FALSE)
  lines <- readLines(file.path(appdir, "_shinyelectron.yml"))
  expect_true('  slug: "sales-dashboard"' %in% lines)
  expect_equal(read_config(appdir)$app$slug, "sales-dashboard")
})

test_that("init_config() takes the directory slug for a non-ASCII name", {
  appdir <- local_app("dash-app")
  expect_message(
    init_config(appdir, app_name = non_ascii_name, verbose = FALSE),
    "directory name"
  )
  expect_equal(read_config(appdir)$app$slug, "dash-app")
})

test_that("show_config() reports the slug that export() would use", {
  appdir <- local_app("dash-app", list(app = list(name = non_ascii_name)))
  expect_message(
    output <- cli::cli_fmt(show_config(appdir)),
    "directory name"
  )
  expect_true(any(grepl("Slug: \"dash-app\"", output, fixed = TRUE)))
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

test_that("export() stops early when neither the name nor the directory gives a slug", {
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
  messages <- character(0)
  withCallingHandlers(
    init_config(appdir),
    message = function(m) {
      messages <<- c(messages, conditionMessage(m))
      invokeRestart("muffleMessage")
    }
  )
  expect_true(any(grepl("app.slug", messages, fixed = TRUE)))
  lines <- readLines(file.path(appdir, "_shinyelectron.yml"))
  expect_true(any(startsWith(lines, "  # slug: null")))
  expect_null(read_config(appdir)$app$slug)
})

test_that("init_config() warns when replacing a config changes the slug", {
  # A config from before slug: was written out, which shipped under the
  # directory's slug.
  appdir <- local_app("dash-app", list(app = list(name = "dash-app")))
  expect_warning(
    init_config(appdir, app_name = "Sales Dashboard", overwrite = TRUE, verbose = FALSE),
    "dash-app", class = "shinyelectron_slug_changed"
  )
  # The slug the replaced config pinned is kept, so no warning.
  expect_no_warning(
    init_config(appdir, app_name = "Sales Dashboard", overwrite = TRUE, verbose = FALSE)
  )
  # A fresh config has nothing to compare with.
  expect_no_warning(init_config(local_app("new-app"), app_name = "Sales Dashboard", verbose = FALSE))
})
