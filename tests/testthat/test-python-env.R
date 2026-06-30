# python_subprocess_env() strips R's lib directory from LD_LIBRARY_PATH so a
# spawned Python child does not lose site-packages (the cause of "No module
# named shinylive" when shinyelectron called the shinylive CLI from R on Linux).

test_that("python_subprocess_env strips R's lib dir from LD_LIBRARY_PATH", {
  r_lib <- normalizePath(R.home("lib"), winslash = "/", mustWork = FALSE)
  old <- Sys.getenv("LD_LIBRARY_PATH", unset = NA)
  on.exit(
    if (is.na(old)) Sys.unsetenv("LD_LIBRARY_PATH") else Sys.setenv(LD_LIBRARY_PATH = old),
    add = TRUE
  )

  Sys.setenv(LD_LIBRARY_PATH = paste(
    R.home("lib"), "/usr/lib/keepme", "/opt/py/lib",
    sep = .Platform$path.sep
  ))
  env <- python_subprocess_env()
  ld <- env[["LD_LIBRARY_PATH"]]

  expect_false(grepl(r_lib, ld, fixed = TRUE))   # R's lib removed
  expect_true(grepl("keepme", ld, fixed = TRUE)) # other entries kept
  expect_true(grepl("/opt/py/lib", ld, fixed = TRUE))
})

test_that("python_subprocess_env is a no-op when LD_LIBRARY_PATH is unset", {
  old <- Sys.getenv("LD_LIBRARY_PATH", unset = NA)
  on.exit(
    if (is.na(old)) Sys.unsetenv("LD_LIBRARY_PATH") else Sys.setenv(LD_LIBRARY_PATH = old),
    add = TRUE
  )

  Sys.unsetenv("LD_LIBRARY_PATH")
  env <- python_subprocess_env()
  expect_false("LD_LIBRARY_PATH" %in% names(env) && nzchar(env[["LD_LIBRARY_PATH"]]))
})
