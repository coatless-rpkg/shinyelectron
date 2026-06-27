test_that("generate_package_json creates valid JSON for shinylive backend", {
  result <- generate_package_json(
    app_slug = "my-app",
    app_version = "1.0.0",
    backend = "shinylive",
    config = list()
  )
  parsed <- jsonlite::fromJSON(result, simplifyVector = FALSE)

  expect_equal(parsed$name, "my-app")
  expect_equal(parsed$version, "1.0.0")
  expect_equal(parsed$main, "main.js")
  expect_true("express" %in% names(parsed$dependencies))
  expect_true("serve-static" %in% names(parsed$dependencies))
  expect_true("electron" %in% names(parsed$devDependencies))
  expect_true("electron-builder" %in% names(parsed$devDependencies))
  expect_false("electron-updater" %in% names(parsed$dependencies))
})

test_that("generate_package_json includes updater deps when updates enabled", {
  result <- generate_package_json(
    app_slug = "my-app",
    app_version = "1.0.0",
    backend = "shinylive",
    config = list(updates = list(enabled = TRUE, provider = "github",
                                 github = list(owner = "me", repo = "app")))
  )
  parsed <- jsonlite::fromJSON(result, simplifyVector = FALSE)

  expect_true("electron-updater" %in% names(parsed$dependencies))
  expect_true("electron-log" %in% names(parsed$dependencies))
  expect_true("publish" %in% names(parsed$build))
})

test_that("generate_package_json omits express for native backends", {
  result <- generate_package_json(
    app_slug = "my-app",
    app_version = "1.0.0",
    backend = "native-r",
    config = list()
  )
  parsed <- jsonlite::fromJSON(result, simplifyVector = FALSE)

  expect_false("express" %in% names(parsed$dependencies))
  expect_false("serve-static" %in% names(parsed$dependencies))
})

test_that("generate_package_json includes all build scripts", {
  result <- generate_package_json(
    app_slug = "test-app",
    app_version = "2.0.0",
    backend = "shinylive",
    config = list()
  )
  parsed <- jsonlite::fromJSON(result, simplifyVector = FALSE)

  expect_true("build-win" %in% names(parsed$scripts))
  expect_true("build-mac" %in% names(parsed$scripts))
  expect_true("build-linux" %in% names(parsed$scripts))
  expect_true("build-mac-arm64" %in% names(parsed$scripts))
})

test_that("generate_package_json handles icon config", {
  result <- generate_package_json(
    app_slug = "my-app",
    app_version = "1.0.0",
    backend = "shinylive",
    config = list(),
    has_icon = TRUE
  )
  parsed <- jsonlite::fromJSON(result, simplifyVector = FALSE)

  expect_equal(parsed$build$win$icon, "assets/icon.ico")
  expect_equal(parsed$build$mac$icon, "assets/icon.icns")
  expect_equal(parsed$build$linux$icon, "assets/icon.png")
})

test_that("generate_package_json includes lifecycle.html and preload.js in files", {
  result <- generate_package_json(
    app_slug = "my-app",
    app_version = "1.0.0",
    backend = "shinylive",
    config = list()
  )
  parsed <- jsonlite::fromJSON(result, simplifyVector = FALSE)

  expect_true("lifecycle.html" %in% parsed$build$files)
  expect_true("preload.js" %in% parsed$build$files)
})

test_that("generate_package_json uses default electron and toolchain versions", {
  result <- generate_package_json(
    app_slug = "my-app",
    app_version = "1.0.0",
    backend = "native-r",
    config = list()
  )
  parsed <- jsonlite::fromJSON(result, simplifyVector = FALSE)

  expect_equal(
    parsed$devDependencies$electron,
    paste0("^", SHINYELECTRON_DEFAULTS$runtime_versions$electron)
  )
  expect_equal(
    parsed$devDependencies[["electron-builder"]],
    paste0("^", SHINYELECTRON_DEFAULTS$electron_toolchain$builder)
  )
})

test_that("generate_package_json uses toolchain pins for updater and log", {
  result <- generate_package_json(
    app_slug = "my-app",
    app_version = "1.0.0",
    backend = "native-r",
    config = list(updates = list(enabled = TRUE, provider = "github",
                                 github = list(owner = "me", repo = "app")))
  )
  parsed <- jsonlite::fromJSON(result, simplifyVector = FALSE)

  expect_equal(
    parsed$dependencies[["electron-updater"]],
    paste0("^", SHINYELECTRON_DEFAULTS$electron_toolchain$updater)
  )
  expect_equal(
    parsed$dependencies[["electron-log"]],
    paste0("^", SHINYELECTRON_DEFAULTS$electron_toolchain$log)
  )
})

test_that("generate_package_json respects config electron version override", {
  config <- list(dependencies = list(electron = list(version = "42.1.0")))
  result <- generate_package_json(
    app_slug = "my-app",
    app_version = "1.0.0",
    backend = "native-r",
    config = config
  )
  parsed <- jsonlite::fromJSON(result, simplifyVector = FALSE)

  expect_equal(parsed$devDependencies$electron, "^42.1.0")
})
