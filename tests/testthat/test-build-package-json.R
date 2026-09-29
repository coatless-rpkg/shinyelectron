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

test_that("generate_package_json honours custom display name, description and author", {
  cfg <- list(app = list(description = "Custom desc", author = "Jane <j@x.org>"))
  parsed <- jsonlite::fromJSON(
    generate_package_json("myapp", "0.1.9", "native-r", cfg, app_name = "My App"),
    simplifyVector = FALSE
  )

  expect_equal(parsed$name, "myapp")
  expect_equal(parsed$version, "0.1.9")
  expect_equal(parsed$description, "Custom desc")
  expect_equal(parsed$author, list(name = "Jane", email = "j@x.org"))
  expect_equal(parsed$build$productName, "My App")
})

test_that("generate_package_json uses the slug as productName without a display name", {
  parsed <- jsonlite::fromJSON(
    generate_package_json("myapp", "1.0.0", "native-r", list()),
    simplifyVector = FALSE
  )
  expect_equal(parsed$build$productName, "myapp")
})

test_that("generate_package_json falls back to slug description and name product", {
  parsed <- jsonlite::fromJSON(
    generate_package_json("myapp", "1.0.0", "native-r", list(),
                          app_name = "Display Name"),
    simplifyVector = FALSE
  )

  expect_equal(parsed$description, "myapp - Shiny Electron App")
  expect_equal(parsed$author, "")
  expect_equal(parsed$build$productName, "Display Name")
})

test_that("installer file names come from the slug and include the architecture", {
  parsed <- jsonlite::fromJSON(
    generate_package_json("my-app", "1.0.0", "native-r", list(), app_name = "My App"),
    simplifyVector = FALSE
  )
  expect_equal(parsed$build$artifactName, "${name}-${version}-${arch}.${ext}")
  expect_equal(parsed$build$win$artifactName, "${name}-Setup-${version}-${arch}.${ext}")
  for (pattern in c(parsed$build$artifactName, parsed$build$win$artifactName)) {
    expect_match(pattern, "${name}", fixed = TRUE)
    expect_match(pattern, "${arch}", fixed = TRUE)
  }
})

test_that("the Windows executable keeps the slug while productName shows the app name", {
  parsed <- jsonlite::fromJSON(
    generate_package_json("my-app", "1.0.0", "native-r", list(), app_name = "My App"),
    simplifyVector = FALSE
  )
  expect_equal(parsed$build$productName, "My App")
  expect_equal(parsed$build$win$executableName, "my-app")
  expect_equal(parsed$build$win$target, "nsis")
})
