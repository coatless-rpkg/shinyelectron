# Render main.js through the package's own template pipeline and let Node
# parse it, covering the template sections that auto-updates and the system
# tray switch on and off.

render_main_js <- function(config, is_multi_app = FALSE, env = parent.frame()) {
  out <- withr::local_tempdir(.local_envir = env)
  vars <- generate_template_variables(
    app_name = "Test App", app_slug = "test-app", app_type = "r-shiny",
    runtime_strategy = "system", icon = NULL, backend_module = "native-r.js",
    brand = NULL, config = config, is_multi_app = is_multi_app,
    apps_manifest = if (is_multi_app) list(list(id = "a", name = "A")) else NULL
  )
  render_shared_templates(out, vars, is_multi_app)
  file.path(out, "main.js")
}

node_check <- function(path) {
  processx::run(Sys.which("node"), c("--check", path), error_on_status = FALSE)
}

test_that("rendered main.js parses with auto-updates enabled and disabled", {
  skip_on_cran()
  skip_if_not(nzchar(Sys.which("node")), "Node.js not available")

  for (updates in c(TRUE, FALSE)) {
    for (tray in c(TRUE, FALSE)) {
      cfg <- default_config()
      cfg$updates$enabled <- updates
      cfg$tray$enabled <- tray
      cfg$tray$close_to_tray <- tray
      main_js <- render_main_js(cfg, is_multi_app = tray)
      label <- sprintf("updates = %s, tray and multi-app = %s", updates, tray)

      res <- node_check(main_js)
      expect_equal(res$status, 0, info = paste(label, res$stderr))

      main <- paste(readLines(main_js), collapse = "\n")
      if (updates) {
        expect_match(main, "cancelId: 1", fixed = TRUE, info = label)
        expect_match(main, "setTimeout(resolve, 10000)", fixed = TRUE, info = label)
      } else {
        expect_no_match(main, "autoUpdater", fixed = TRUE, info = label)
      }
    }
  }
})

test_that("an unvalidated shutdown_timeout still renders a parseable main.js", {
  skip_on_cran()
  skip_if_not(nzchar(Sys.which("node")), "Node.js not available")

  cfg <- default_config()
  cfg$updates$enabled <- TRUE
  cfg$lifecycle$shutdown_timeout <- "10s"
  main_js <- render_main_js(cfg)

  res <- node_check(main_js)
  expect_equal(res$status, 0, info = res$stderr)
  expect_no_match(paste(readLines(main_js), collapse = "\n"), "10s", fixed = TRUE)
})
