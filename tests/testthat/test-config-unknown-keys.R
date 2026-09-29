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
    app = list(version = "1.0.0", slug = "s", product_name = "P",
               description = "d", author = "a"),
    build = list(runtime_strategy = "bundled"),
    window = list(width = 1400, height = 900),
    icon = "x.ico",
    icons = list(win = "x.ico"),
    installer = list(one_click = FALSE,
                     allow_to_change_installation_directory = TRUE,
                     per_machine = TRUE),
    optimize = list(r_library = TRUE, r_runtime = TRUE),
    container = list(engine = "docker", volumes = list("/a" = "/b"),
                     env = list(KEY = "v")),
    dependencies = list(r = list(repos = list("https://cloud.r-project.org"),
                                 packages = list("Seurat"))),
    signing = list(sign = FALSE, mac = list(identity = NULL)),
    apps = list(list(id = "a", name = "A", path = "p"))
  )
  expect_length(collect_unknown_config_keys(cfg), 0L)
})