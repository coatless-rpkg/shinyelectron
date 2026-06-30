# python_subprocess_env() removes LD_LIBRARY_PATH so a spawned Python child does
# not resolve a system libpython ahead of its own and lose site-packages (the
# cause of "No module named shinylive" when shinyelectron called the shinylive
# CLI from R on Linux).

test_that("python_subprocess_env removes LD_LIBRARY_PATH", {
  old <- Sys.getenv("LD_LIBRARY_PATH", unset = NA)
  on.exit(
    if (is.na(old)) Sys.unsetenv("LD_LIBRARY_PATH") else Sys.setenv(LD_LIBRARY_PATH = old),
    add = TRUE
  )

  Sys.setenv(LD_LIBRARY_PATH = paste(
    R.home("lib"), "/usr/lib/x86_64-linux-gnu",
    sep = .Platform$path.sep
  ))
  env <- python_subprocess_env()
  expect_false("LD_LIBRARY_PATH" %in% names(env))
})

test_that("python_subprocess_env preserves other environment variables", {
  env <- python_subprocess_env()
  expect_true("PATH" %in% names(env))
  expect_type(env, "character")
})
