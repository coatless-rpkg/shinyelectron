test_that("validate_python_available checks for Python on PATH", {
  mockery::stub(validate_python_available, "find_python_command", function() "python3")
  mockery::stub(validate_python_available, "processx::run", function(...) {
    list(status = 0, stdout = "Python 3.12.0\n")
  })
  expect_silent(validate_python_available())
})

test_that("validate_python_available errors when Python not found", {
  mockery::stub(validate_python_available, "find_python_command", function() NULL)
  expect_error(validate_python_available(), "Python is required")
})

test_that("validate_python_shinylive_installed passes when shinylive CLI is on PATH", {
  mockery::stub(validate_python_shinylive_installed, "Sys.which", function(cmd) "/usr/local/bin/shinylive")
  mockery::stub(validate_python_shinylive_installed, "processx::run", function(...) {
    list(status = 0, stdout = "shinylive 0.8.6\n", stderr = "")
  })
  expect_silent(validate_python_shinylive_installed())
})

test_that("validate_python_shinylive_installed falls back to python -m shinylive", {
  mockery::stub(validate_python_shinylive_installed, "Sys.which", function(cmd) "")
  mockery::stub(validate_python_shinylive_installed, "find_python_command", function() "python3")
  mockery::stub(validate_python_shinylive_installed, "processx::run", function(...) {
    list(status = 0, stdout = "shinylive 0.7.0\n", stderr = "")
  })
  expect_silent(validate_python_shinylive_installed())
})

test_that("validate_python_shinylive_installed errors when CLI is missing entirely", {
  mockery::stub(validate_python_shinylive_installed, "Sys.which", function(cmd) "")
  mockery::stub(validate_python_shinylive_installed, "find_python_command", function() "python3")
  mockery::stub(validate_python_shinylive_installed, "processx::run", function(...) {
    list(status = 1, stdout = "", stderr = "No module named shinylive\n")
  })
  expect_error(validate_python_shinylive_installed(), "shinylive.*Python package")
})

test_that("validate_python_shinylive_installed hints at PATH when only __main__ is missing", {
  mockery::stub(validate_python_shinylive_installed, "Sys.which", function(cmd) "")
  mockery::stub(validate_python_shinylive_installed, "find_python_command", function() "python3")
  mockery::stub(validate_python_shinylive_installed, "processx::run", function(...) {
    list(
      status = 1,
      stdout = "",
      stderr = "No module named shinylive.__main__; 'shinylive' is a package and cannot be directly executed\n"
    )
  })
  expect_error(validate_python_shinylive_installed(), "not on PATH")
})

test_that("validate_python_shiny_installed passes when shiny imports", {
  mockery::stub(validate_python_shiny_installed, "find_python_command", function() "python3")
  mockery::stub(validate_python_shiny_installed, "processx::run", function(...) {
    list(status = 0, stdout = "1.0.0\n", stderr = "")
  })
  expect_silent(validate_python_shiny_installed())
})

test_that("validate_python_shiny_installed errors when shiny is missing", {
  mockery::stub(validate_python_shiny_installed, "find_python_command", function() "python3")
  mockery::stub(validate_python_shiny_installed, "processx::run", function(...) {
    list(status = 1, stdout = "", stderr = "No module named shiny\n")
  })
  expect_error(validate_python_shiny_installed(), "shiny.*Python package")
})

test_that("find_python_command finds python3 first", {
  mockery::stub(find_python_command, "Sys.which", function(cmd) {
    if (cmd == "python3") "/usr/bin/python3" else ""
  })
  expect_equal(find_python_command(), "python3")
})

test_that("find_python_command falls back to python", {
  mockery::stub(find_python_command, "Sys.which", function(cmd) {
    if (cmd == "python") "/usr/bin/python" else ""
  })
  expect_equal(find_python_command(), "python")
})

test_that("find_python_command returns NULL when no Python found", {
  mockery::stub(find_python_command, "Sys.which", function(cmd) "")
  expect_null(find_python_command())
})
