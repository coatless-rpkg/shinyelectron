test_that("validate_suite_strategies accepts shinylive + bundled-R + system-Py", {
  config <- list(
    build = list(type = "r-shiny"),
    apps = list(
      list(id = "home", name = "Home", path = ".", runtime_strategy = "shinylive"),
      list(id = "dash", name = "Dash", path = ".", runtime_strategy = "bundled"),
      list(id = "api",  name = "API",  path = ".", type = "py-shiny",
           runtime_strategy = "system")
    )
  )
  expect_true(validate_suite_strategies(config$apps, config))
})

test_that("validate_suite_strategies accepts two bundled-R apps", {
  config <- list(
    build = list(type = "r-shiny", runtime_strategy = "bundled"),
    apps = list(
      list(id = "dash",   name = "Dash",   path = "."),
      list(id = "report", name = "Report", path = ".")
    )
  )
  expect_true(validate_suite_strategies(config$apps, config))
})

test_that("validate_suite_strategies accepts bundled-R + container-R", {
  config <- list(
    build = list(type = "r-shiny"),
    apps = list(
      list(id = "dash", name = "Dash", path = ".", runtime_strategy = "bundled"),
      list(id = "box",  name = "Box",  path = ".", runtime_strategy = "container")
    )
  )
  expect_true(validate_suite_strategies(config$apps, config))
})

test_that("validate_suite_strategies accepts bundled-R + bundled-Py", {
  config <- list(
    build = list(type = "r-shiny", runtime_strategy = "bundled"),
    apps = list(
      list(id = "dash", name = "Dash", path = "."),
      list(id = "api",  name = "API",  path = ".", type = "py-shiny")
    )
  )
  expect_true(validate_suite_strategies(config$apps, config))
})

test_that("validate_suite_strategies rejects bundled-R + auto-download-R naming both apps and strategies", {
  config <- list(
    build = list(type = "r-shiny"),
    apps = list(
      list(id = "alpha", name = "Alpha", path = ".", runtime_strategy = "bundled"),
      list(id = "beta",  name = "Beta",  path = ".", runtime_strategy = "auto-download")
    )
  )
  err <- expect_error(
    validate_suite_strategies(config$apps, config),
    class = "shinyelectron_suite_strategy_conflict"
  )
  msg <- conditionMessage(err)
  expect_match(msg, "alpha", fixed = TRUE)
  expect_match(msg, "beta", fixed = TRUE)
  expect_match(msg, "bundled", fixed = TRUE)
  expect_match(msg, "auto-download", fixed = TRUE)
})

test_that("validate_suite_strategies rejects bundled-R + system-R naming both apps and strategies", {
  config <- list(
    build = list(type = "r-shiny"),
    apps = list(
      list(id = "alpha", name = "Alpha", path = ".", runtime_strategy = "bundled"),
      list(id = "beta",  name = "Beta",  path = ".", runtime_strategy = "system")
    )
  )
  err <- expect_error(
    validate_suite_strategies(config$apps, config),
    class = "shinyelectron_suite_strategy_conflict"
  )
  msg <- conditionMessage(err)
  expect_match(msg, "alpha", fixed = TRUE)
  expect_match(msg, "beta", fixed = TRUE)
  expect_match(msg, "bundled", fixed = TRUE)
  expect_match(msg, "system", fixed = TRUE)
})

test_that("validate_suite_strategies rejects system-R + auto-download-R naming both apps and strategies", {
  config <- list(
    build = list(type = "r-shiny"),
    apps = list(
      list(id = "alpha", name = "Alpha", path = ".", runtime_strategy = "system"),
      list(id = "beta",  name = "Beta",  path = ".", runtime_strategy = "auto-download")
    )
  )
  err <- expect_error(
    validate_suite_strategies(config$apps, config),
    class = "shinyelectron_suite_strategy_conflict"
  )
  msg <- conditionMessage(err)
  expect_match(msg, "alpha", fixed = TRUE)
  expect_match(msg, "beta", fixed = TRUE)
  expect_match(msg, "system", fixed = TRUE)
  expect_match(msg, "auto-download", fixed = TRUE)
})
