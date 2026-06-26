# tests/testthat/test-examples.R

# --- available_examples ---

test_that("available_examples returns a data frame invisibly", {
  result <- NULL
  capture.output(suppressMessages({ result <- available_examples() }), type = "output")
  expect_s3_class(result, "data.frame")
})

test_that("available_examples data frame has required columns", {
  result <- NULL
  capture.output(suppressMessages({ result <- available_examples() }), type = "output")
  expect_true(all(c("name", "language", "type", "description") %in% names(result)))
})

test_that("available_examples includes the three bundled examples", {
  result <- NULL
  capture.output(suppressMessages({ result <- available_examples() }), type = "output")
  expect_setequal(result$name, c("r", "python", "suite"))
})

test_that("available_examples language column is 'r' or 'python' only", {
  result <- NULL
  capture.output(suppressMessages({ result <- available_examples() }), type = "output")
  expect_true(all(result$language %in% c("r", "python")))
})

test_that("available_examples type column maps r -> r-shiny and python -> py-shiny", {
  result <- NULL
  capture.output(suppressMessages({ result <- available_examples() }), type = "output")
  r_row <- result[result$name == "r", ]
  py_row <- result[result$name == "python", ]
  expect_equal(r_row$type, "r-shiny")
  expect_equal(py_row$type, "py-shiny")
})

test_that("available_examples description column contains non-empty strings", {
  result <- NULL
  capture.output(suppressMessages({ result <- available_examples() }), type = "output")
  expect_true(all(nzchar(result$description)))
})

# --- example_app ---

test_that("example_app aborts on an unknown example name", {
  expect_error(example_app("not_a_real_example"), "Unknown example")
})

test_that("example_app abort message mentions available_examples", {
  expect_error(example_app("bogus"), "available_examples")
})

test_that("example_app returns a character string path for the 'r' example", {
  path <- example_app("r")
  expect_type(path, "character")
  expect_true(nzchar(path))
})

test_that("example_app path for 'r' exists on disk", {
  path <- example_app("r")
  expect_true(dir.exists(path))
})

test_that("example_app returns a valid path for the 'python' example", {
  path <- example_app("python")
  expect_true(dir.exists(path))
})

test_that("example_app returns a valid path for the 'suite' example", {
  path <- example_app("suite")
  expect_true(dir.exists(path))
})

test_that("example_app path for 'r' is inside the package inst directory", {
  path <- example_app("r")
  expect_match(path, "demo-single")
})
