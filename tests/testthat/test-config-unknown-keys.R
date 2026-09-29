# Write `lines` as the _shinyelectron.yml of a temporary app directory that is
# removed when the calling test finishes.
.config_dir <- function(lines, env = parent.frame()) {
  dir <- withr::local_tempdir(.local_envir = env)
  writeLines(lines, file.path(dir, CONFIG_FILENAME))
  dir
}

test_that("collect_unknown_config_keys flags flat/legacy keys", {
  cfg <- list(app_name = "x", display_name = "y", runtime_strategy = "bundled",
              r_dependencies = list("Seurat"))
  expect_setequal(
    collect_unknown_config_keys(cfg),
    c("app_name", "display_name", "runtime_strategy", "r_dependencies")
  )
})

test_that("collect_unknown_config_keys flags nested typos", {
  cfg <- list(installer = list(one_click = FALSE, one_clickk = TRUE))
  expect_equal(collect_unknown_config_keys(cfg), "installer.one_clickk")

  cfg <- list(updates = list(github = list(ownr = "me")),
              icons = list(macos = "icon.icns"))
  expect_equal(collect_unknown_config_keys(cfg),
               c("updates.github.ownr", "icons.macos"))
})

test_that("collect_unknown_config_keys accepts valid nested config and exemptions", {
  cfg <- list(
    app = list(version = "1.0.0", slug = "s", log_level = "debug"),
    build = list(runtime_strategy = "bundled"),
    window = list(width = 1400, height = 900),
    icon = "x.ico",
    icons = list(win = "x.ico"),
    installer = list(one_click = FALSE, app_id = "com.example.app"),
    logging = list(log_dir = "logs", log_level = "debug"),
    container = list(engine = "docker", volumes = list("/a" = "/b"),
                     env = list(KEY = "v")),
    dependencies = list(r = list(repos = list("https://cloud.r-project.org"),
                                 packages = list("Seurat"))),
    signing = list(sign = FALSE, mac = list(identity = NULL)),
    apps = list(list(id = "a", name = "A", path = "p"))
  )
  expect_length(collect_unknown_config_keys(cfg), 0L)
})

test_that("collect_unknown_config_keys takes whole the maps the merge takes whole", {
  cfg <- list(
    dependencies = list(r = list(repos = list(
      CRAN = "https://cloud.r-project.org",
      BioCsoft = "https://bioconductor.org/packages/3.20/bioc"
    ))),
    container = list(volumes = list("/data" = "/app/data"),
                     env = list(SHINY_LOG_LEVEL = "debug"))
  )
  expect_length(collect_unknown_config_keys(cfg), 0L)
})

test_that("collect_unknown_config_keys exempts apps entries and icon only at the top level", {
  cfg <- list(
    icon = "icon.png",
    apps = list(
      list(id = "a", name = "A", path = "a", colour = "red"),
      list(id = "b", name = "B", path = "b")
    ),
    window = list(icon = "icon.png")
  )
  expect_equal(collect_unknown_config_keys(cfg), "window.icon")
})

test_that("read_config warns about an unknown key and still returns the config", {
  dir <- .config_dir(c("app:", "  name: Demo", "  nmae: Typo"))
  w <- expect_warning(
    config <- read_config(dir),
    "Unknown configuration key in",
    class = "shinyelectron_unknown_config_key"
  )
  expect_equal(w$keys, "app.nmae")
  expect_match(conditionMessage(w), CONFIG_FILENAME, fixed = TRUE)
  expect_equal(config$app$name, "Demo")
  expect_equal(config$app$version, SHINYELECTRON_DEFAULTS$app_version)
})

test_that("read_config names every unknown key in one warning", {
  dir <- .config_dir(c("app_name: Demo", "window:", "  widht: 900"))
  w <- expect_warning(
    config <- read_config(dir),
    "Unknown configuration keys in",
    class = "shinyelectron_unknown_config_key"
  )
  expect_equal(w$keys, c("app_name", "window.widht"))
  expect_equal(config$window$width, SHINYELECTRON_DEFAULTS$window_width)
})

test_that("read_config reports a nested typo by its dotted path", {
  dir <- .config_dir(c("updates:", "  enabled: true", "  github:", "    ownr: me"))
  w <- expect_warning(read_config(dir),
                      class = "shinyelectron_unknown_config_key")
  expect_equal(w$keys, "updates.github.ownr")
})

test_that("read_config accepts named maps that are values, not sections", {
  dir <- .config_dir(c(
    "dependencies:",
    "  r:",
    "    repos:",
    "      CRAN: https://cloud.r-project.org",
    "      BioCsoft: https://bioconductor.org/packages/3.20/bioc",
    "container:",
    "  volumes:",
    "    /data: /app/data",
    "  env:",
    "    SHINY_LOG_LEVEL: debug"
  ))
  expect_no_warning(config <- read_config(dir))
  expect_named(config$dependencies$r$repos, c("CRAN", "BioCsoft"))
  expect_equal(config$container$env$SHINY_LOG_LEVEL, "debug")
})

test_that("read_config does not report apps entries or the icon shortcut", {
  dir <- .config_dir(c(
    "icon: icon.png",
    "apps:",
    "  - id: a",
    "    name: A",
    "    path: apps/a",
    "    colour: red",
    "  - id: b",
    "    name: B",
    "    path: apps/b"
  ))
  expect_no_warning(config <- read_config(dir))
  expect_length(config$apps, 2L)
  expect_equal(config[["icon"]], "icon.png")
})

test_that("read_config applies a top-level logging section without warning", {
  dir <- .config_dir(c("logging:", "  log_dir: logs", "  log_level: debug"))
  expect_no_warning(config <- read_config(dir))
  expect_equal(config$app$log_level, "debug")
  expect_equal(config$app$log_dir, "logs")
  expect_null(config[["logging"]])

  vars <- generate_template_variables(
    app_name = "Demo", app_slug = "demo", app_type = "r-shiny",
    runtime_strategy = "shinylive", icon = NULL,
    backend_module = "shinylive.js", brand = NULL, config = config
  )
  expect_equal(vars$log_level, "debug")
  expect_equal(vars$log_dir, "logs")
})

test_that("read_config still accepts app.log_dir and app.log_level", {
  dir <- .config_dir(c("app:", "  log_dir: logs", "  log_level: warn"))
  expect_no_warning(config <- read_config(dir))
  expect_equal(config$app$log_level, "warn")
  expect_equal(config$app$log_dir, "logs")
})

test_that("read_config prefers logging when it and app set a field differently", {
  dir <- .config_dir(c(
    "app:", "  log_dir: logs", "  log_level: warn",
    "logging:", "  log_level: debug"
  ))
  expect_warning(config <- read_config(dir), "logging.log_level", fixed = TRUE)
  expect_equal(config$app$log_level, "debug")
  expect_equal(config$app$log_dir, "logs")

  dir <- .config_dir(c("app:", "  log_level: debug",
                       "logging:", "  log_level: debug"))
  expect_no_warning(config <- read_config(dir))
  expect_equal(config$app$log_level, "debug")
})

test_that("read_config reports unknown keys inside logging", {
  dir <- .config_dir(c("logging:", "  level: debug", "  log_dir: logs"))
  w <- expect_warning(config <- read_config(dir),
                      class = "shinyelectron_unknown_config_key")
  expect_equal(w$keys, "logging.level")
  expect_equal(config$app$log_dir, "logs")
  expect_equal(config$app$log_level, SHINYELECTRON_DEFAULTS$logging$log_level)
})
