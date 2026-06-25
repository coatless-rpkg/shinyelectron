# Tests for the cache-management functions. cache_dir() is stubbed to a
# temporary directory so nothing touches the user's real cache.

test_that("cache_dir(create = FALSE) returns a path without creating it", {
  p <- cache_dir(create = FALSE)
  expect_type(p, "character")
  expect_true(nzchar(p))
})

test_that("cache_info returns an empty data frame when nothing is cached", {
  empty <- file.path(tempfile("cache-"), "missing")
  mockery::stub(cache_info, "cache_dir", function(...) empty)
  df <- cache_info(quiet = TRUE)
  expect_s3_class(df, "data.frame")
  expect_identical(nrow(df), 0L)
})

test_that("cache_info lists cached runtimes with canonical platform names", {
  root <- tempfile("cache-")
  on.exit(unlink(root, recursive = TRUE), add = TRUE)
  dir.create(file.path(root, "r", "mac", "arm64", "4.5.3"), recursive = TRUE)
  dir.create(file.path(root, "nodejs", "v22.11.0", "darwin-arm64"), recursive = TRUE)
  mockery::stub(cache_info, "cache_dir", function(...) root)

  df <- cache_info(quiet = TRUE)
  expect_true("4.5.3" %in% df$version)
  # The Node.js row reports the canonical "mac", not Node's "darwin".
  expect_true("mac" %in% df$platform)
  expect_false("darwin" %in% df$platform)
})

test_that("cache_remove deletes only the targeted version", {
  root <- tempfile("cache-")
  on.exit(unlink(root, recursive = TRUE), add = TRUE)
  keep <- file.path(root, "r", "mac", "arm64", "4.4.1")
  drop <- file.path(root, "r", "mac", "arm64", "4.5.3")
  dir.create(keep, recursive = TRUE)
  dir.create(drop, recursive = TRUE)
  mockery::stub(cache_remove, "cache_dir", function(...) root)

  expect_true(cache_remove("r", "4.5.3", "mac", "arm64"))
  expect_false(dir.exists(drop))
  expect_true(dir.exists(keep))
})

test_that("cache_remove requires platform and arch for r/python", {
  root <- tempfile("cache-")
  on.exit(unlink(root, recursive = TRUE), add = TRUE)
  dir.create(root)
  mockery::stub(cache_remove, "cache_dir", function(...) root)
  expect_error(cache_remove("r", "4.5.3"), "platform")
})

test_that("cache_clear removes only the targeted runtime subtree", {
  root <- tempfile("cache-")
  on.exit(unlink(root, recursive = TRUE), add = TRUE)
  r_dir <- file.path(root, "r")
  npm_dir <- file.path(root, "npm")
  dir.create(r_dir, recursive = TRUE)
  dir.create(npm_dir, recursive = TRUE)
  mockery::stub(cache_clear, "cache_dir", function(...) root)

  cache_clear("r")
  expect_false(dir.exists(r_dir))
  expect_true(dir.exists(npm_dir))
})

test_that("show_config runs on a directory with a config file", {
  appdir <- tempfile("app-")
  on.exit(unlink(appdir, recursive = TRUE), add = TRUE)
  dir.create(appdir)
  writeLines("from shiny import App", file.path(appdir, "app.py"))
  init_config(appdir, verbose = FALSE)

  expect_no_error(show_config(appdir))
})
