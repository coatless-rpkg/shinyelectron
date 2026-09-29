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
})

test_that("collect_unknown_config_keys accepts valid nested config and exemptions", {
  cfg <- list(
    app = list(version = "1.0.0", slug = "s", log_level = "debug"),
    build = list(runtime_strategy = "bundled"),
    window = list(width = 1400, height = 900),
    icon = "x.ico",
    icons = list(win = "x.ico"),
    installer = list(one_click = FALSE, app_id = "com.example.app"),
    container = list(engine = "docker", volumes = list("/a" = "/b"),
                     env = list(KEY = "v")),
    dependencies = list(r = list(repos = list("https://cloud.r-project.org"),
                                 packages = list("Seurat"))),
    signing = list(sign = FALSE, mac = list(identity = NULL)),
    apps = list(list(id = "a", name = "A", path = "p"))
  )
  expect_length(collect_unknown_config_keys(cfg), 0L)
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
