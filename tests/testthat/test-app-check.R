test_that("app_check passes for valid R shiny app", {
  tmpdir <- tempfile()
  dir.create(tmpdir)
  writeLines("library(shiny)\nshinyApp(ui=fluidPage(), server=function(i,o){})",
             file.path(tmpdir, "app.R"))
  on.exit(unlink(tmpdir, recursive = TRUE))

  result <- app_check(tmpdir, verbose = FALSE)
  expect_true(result$pass)
  expect_length(result$errors, 0)
})

test_that("app_check fails for missing app files", {
  tmpdir <- tempfile()
  dir.create(tmpdir)
  on.exit(unlink(tmpdir, recursive = TRUE))

  result <- app_check(tmpdir, verbose = FALSE)
  expect_false(result$pass)
  expect_true(any(grepl("app.R|server.R", result$errors)))
})

test_that("app_check fails for nonexistent directory", {
  result <- app_check("/nonexistent/path", verbose = FALSE)
  expect_false(result$pass)
  expect_true(any(grepl("does not exist", result$errors)))
})

test_that("app_check validates Python app structure", {
  tmpdir <- tempfile()
  dir.create(tmpdir)
  writeLines("from shiny import App", file.path(tmpdir, "app.py"))
  on.exit(unlink(tmpdir, recursive = TRUE))

  # Warns about missing requirements.txt — expected since we only test app structure
  expect_warning(
    result <- app_check(tmpdir, app_type = "py-shiny", verbose = FALSE),
    "requirements.txt"
  )
  expect_false(any(grepl("app.py", result$errors)))
})

test_that("app_check warns about missing icon", {
  tmpdir <- tempfile()
  dir.create(tmpdir)
  writeLines("library(shiny)\nshinyApp(ui=fluidPage(), server=function(i,o){})",
             file.path(tmpdir, "app.R"))
  on.exit(unlink(tmpdir, recursive = TRUE))

  result <- app_check(tmpdir, verbose = FALSE)
  expect_true(any(grepl("icon|Icon", result$info)))
})

test_that("app_check detects dependencies", {
  tmpdir <- tempfile()
  dir.create(tmpdir)
  writeLines(c("library(shiny)", "library(ggplot2)"),
             file.path(tmpdir, "app.R"))
  on.exit(unlink(tmpdir, recursive = TRUE))

  result <- app_check(tmpdir, verbose = FALSE)
  expect_true(any(grepl("shiny|ggplot2", result$info)))
})

test_that("app_check returns correct structure", {
  tmpdir <- tempfile()
  dir.create(tmpdir)
  writeLines("library(shiny)\nshinyApp(ui=fluidPage(), server=function(i,o){})",
             file.path(tmpdir, "app.R"))
  on.exit(unlink(tmpdir, recursive = TRUE))

  result <- app_check(tmpdir, verbose = FALSE)
  expect_true(is.list(result))
  expect_true("pass" %in% names(result))
  expect_true("errors" %in% names(result))
  expect_true("warnings" %in% names(result))
  expect_true("info" %in% names(result))
})
