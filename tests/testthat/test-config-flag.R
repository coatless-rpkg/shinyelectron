test_that("config_flag passes logical values through", {
  expect_true(config_flag(TRUE, "x.y"))
  expect_false(config_flag(FALSE, "x.y"))
})

test_that("config_flag returns the default for NULL", {
  expect_null(config_flag(NULL, "x.y"))
  expect_true(config_flag(NULL, "x.y", default = TRUE))
})

test_that("config_flag reads quoted booleans with a warning", {
  for (v in c("true", "TRUE", "True", "yes", " Yes ")) {
    expect_warning(res <- config_flag(v, "installer.one_click"),
                   class = "shinyelectron_quoted_flag")
    expect_true(res)
  }
  for (v in c("false", "FALSE", "no", "No")) {
    expect_warning(res <- config_flag(v, "installer.one_click"),
                   class = "shinyelectron_quoted_flag")
    expect_false(res)
  }
})

test_that("config_flag stops on anything else", {
  bad <- list("maybe", "", 1, 0L, NA, NA_character_, c(TRUE, FALSE),
              list(a = 1))
  for (v in bad) {
    expect_error(config_flag(v, "dependencies.r.prune"),
                 class = "shinyelectron_invalid_flag")
  }
})

test_that("config_flag names the key in its messages", {
  expect_error(config_flag("maybe", "dependencies.r.prune"),
               "dependencies.r.prune")
  expect_warning(config_flag("false", "installer.per_machine"),
                 "installer.per_machine")
})

test_that("config_flag describes a value that is not a single value", {
  expect_error(config_flag(c(TRUE, FALSE), "dependencies.r.prune"),
               "logical vector of length 2")
  expect_error(config_flag(list(a = 1), "dependencies.r.prune"),
               "list of length 1")
})
