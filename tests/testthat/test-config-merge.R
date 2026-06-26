test_that("merge_config_deep overrides unnamed sequence values instead of keeping defaults", {
  defaults <- list(dependencies = list(r = list(repos = list("https://cloud.r-project.org"))))
  config   <- list(dependencies = list(r = list(repos = list("https://my.mirror.example"))))
  merged <- merge_config_deep(defaults, config)
  expect_equal(merged$dependencies$r$repos, list("https://my.mirror.example"))
})

test_that("merge_config_deep still deep-merges named (map) subtrees", {
  defaults <- list(window = list(width = 1200, height = 800))
  config   <- list(window = list(width = 1024))
  merged <- merge_config_deep(defaults, config)
  expect_equal(merged$window$width, 1024)
  expect_equal(merged$window$height, 800)
})
