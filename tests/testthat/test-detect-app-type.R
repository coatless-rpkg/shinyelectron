test_that("detect_app_type picks r-shiny from app.R", {
  appdir <- withr::local_tempdir()
  writeLines("", fs::path(appdir, "app.R"))
  expect_identical(detect_app_type(appdir), "r-shiny")
})

test_that("detect_app_type picks r-shiny from server.R + ui.R", {
  appdir <- withr::local_tempdir()
  writeLines("", fs::path(appdir, "server.R"))
  writeLines("", fs::path(appdir, "ui.R"))
  expect_identical(detect_app_type(appdir), "r-shiny")
})

test_that("detect_app_type picks py-shiny from app.py", {
  appdir <- withr::local_tempdir()
  writeLines("", fs::path(appdir, "app.py"))
  expect_identical(detect_app_type(appdir), "py-shiny")
})

test_that("detect_app_type errors when only server.R is present", {
  appdir <- withr::local_tempdir()
  writeLines("", fs::path(appdir, "server.R"))
  expect_error(detect_app_type(appdir), "Incomplete R Shiny app")
})

test_that("detect_app_type errors when only ui.R is present", {
  appdir <- withr::local_tempdir()
  writeLines("", fs::path(appdir, "ui.R"))
  expect_error(detect_app_type(appdir), "Incomplete R Shiny app")
})

test_that("detect_app_type errors on empty directory with actionable hint", {
  appdir <- withr::local_tempdir()
  expect_error(detect_app_type(appdir), "Could not autodetect app type")
  expect_error(detect_app_type(appdir), "app_type")
})

test_that("detect_app_type errors when both app.py and app.R are present", {
  appdir <- withr::local_tempdir()
  writeLines("", fs::path(appdir, "app.R"))
  writeLines("", fs::path(appdir, "app.py"))
  expect_error(detect_app_type(appdir), "Ambiguous app type")
})

test_that("detect_app_type errors when both app.py and server.R/ui.R are present", {
  appdir <- withr::local_tempdir()
  writeLines("", fs::path(appdir, "server.R"))
  writeLines("", fs::path(appdir, "ui.R"))
  writeLines("", fs::path(appdir, "app.py"))
  expect_error(detect_app_type(appdir), "Ambiguous app type")
})

test_that("detect_app_type errors when given a non-existent directory", {
  expect_error(
    detect_app_type(fs::path(tempdir(), "does-not-exist-xyz")),
    "does not exist"
  )
})

test_that("detect_app_type follows symlinked entrypoints", {
  skip_on_os("windows")
  appdir <- withr::local_tempdir()
  realfile <- withr::local_tempfile(fileext = ".R")
  writeLines("", realfile)
  file.symlink(realfile, fs::path(appdir, "app.R"))
  expect_identical(detect_app_type(appdir), "r-shiny")
})

test_that("detect_app_type does not recurse into subdirectories", {
  appdir <- withr::local_tempdir()
  fs::dir_create(fs::path(appdir, "subdir"))
  writeLines("", fs::path(appdir, "subdir", "app.R"))
  expect_error(detect_app_type(appdir), "Could not autodetect app type")
})

test_that("app_entrypoints returns logical flags for each entrypoint", {
  appdir <- withr::local_tempdir()
  writeLines("", fs::path(appdir, "app.R"))
  writeLines("", fs::path(appdir, "app.py"))

  found <- app_entrypoints(appdir)
  expect_true(found$app_r)
  expect_true(found$app_py)
  expect_false(found$server_r)
  expect_false(found$ui_r)
})

# --- Snapshots of the three abort messages ---

test_that("detect_app_type error: no entrypoint (snapshot)", {
  appdir <- withr::local_tempdir()
  expect_snapshot(
    detect_app_type(appdir),
    error = TRUE,
    transform = function(x) gsub(appdir, "<tmp>", x, fixed = TRUE)
  )
})

test_that("detect_app_type error: ambiguous (snapshot)", {
  appdir <- withr::local_tempdir()
  writeLines("", fs::path(appdir, "app.R"))
  writeLines("", fs::path(appdir, "app.py"))
  expect_snapshot(
    detect_app_type(appdir),
    error = TRUE,
    transform = function(x) gsub(appdir, "<tmp>", x, fixed = TRUE)
  )
})

test_that("detect_app_type error: incomplete R app (snapshot)", {
  appdir <- withr::local_tempdir()
  writeLines("", fs::path(appdir, "server.R"))
  expect_snapshot(
    detect_app_type(appdir),
    error = TRUE,
    transform = function(x) gsub(appdir, "<tmp>", x, fixed = TRUE)
  )
})
