# resolve_python_shinylive_cmd() picks a WORKING shinylive CLI invocation. The
# important case: a `shinylive` console script can be on PATH yet backed by a
# Python that lacks the module (a PATH / version skew CI environments hit). The
# resolver must then fall back to `python -m shinylive` rather than aborting.

test_that("resolve_python_shinylive_cmd uses the console script when it runs", {
  skip_if_not_installed("mockery")
  mockery::stub(resolve_python_shinylive_cmd, "Sys.which", function(...) "/usr/bin/shinylive")
  mockery::stub(resolve_python_shinylive_cmd, "find_python_command", function() "python3")
  mockery::stub(resolve_python_shinylive_cmd, "processx::run", function(command, args, ...) {
    if (command == "shinylive") {
      list(status = 0L, stdout = "shinylive 0.5.0\n", stderr = "")
    } else {
      stop("python -m must not be tried when the console script works")
    }
  })
  res <- resolve_python_shinylive_cmd()
  expect_equal(res$program, "shinylive")
  expect_equal(res$prefix, character(0))
})

test_that("resolve_python_shinylive_cmd falls back to python -m when the console script is broken", {
  skip_if_not_installed("mockery")
  mockery::stub(resolve_python_shinylive_cmd, "Sys.which", function(...) "/usr/bin/shinylive")
  mockery::stub(resolve_python_shinylive_cmd, "find_python_command", function() "python3")
  mockery::stub(resolve_python_shinylive_cmd, "processx::run", function(command, args, ...) {
    if (command == "shinylive") {
      list(status = 1L, stdout = "",
           stderr = "ModuleNotFoundError: No module named shinylive")
    } else {
      list(status = 0L, stdout = "0.5.0\n", stderr = "")
    }
  })
  res <- resolve_python_shinylive_cmd()
  expect_equal(res$program, "python3")
  expect_equal(res$prefix, c("-m", "shinylive"))
})

test_that("resolve_python_shinylive_cmd aborts when neither invocation works", {
  skip_if_not_installed("mockery")
  mockery::stub(resolve_python_shinylive_cmd, "Sys.which", function(...) "/usr/bin/shinylive")
  mockery::stub(resolve_python_shinylive_cmd, "find_python_command", function() "python3")
  mockery::stub(resolve_python_shinylive_cmd, "processx::run", function(command, args, ...) {
    list(status = 1L, stdout = "", stderr = "No module named shinylive")
  })
  expect_error(resolve_python_shinylive_cmd(), class = "rlang_error")
})

test_that("resolve_python_shinylive_cmd hints at PATH when the module lacks __main__", {
  skip_if_not_installed("mockery")
  mockery::stub(resolve_python_shinylive_cmd, "Sys.which", function(...) "")
  mockery::stub(resolve_python_shinylive_cmd, "find_python_command", function() "python3")
  mockery::stub(resolve_python_shinylive_cmd, "processx::run", function(command, args, ...) {
    list(status = 1L, stdout = "",
         stderr = "No module named shinylive.__main__; 'shinylive' is a package and cannot be directly executed")
  })
  expect_error(resolve_python_shinylive_cmd(), "PATH")
})
