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

test_that("build_nsis_config maps installer options", {
  expect_equal(
    build_nsis_config(list(installer = list(one_click = TRUE))),
    list(oneClick = TRUE)
  )
  expect_equal(
    build_nsis_config(list(installer = list(one_click = FALSE))),
    list(oneClick = FALSE)
  )
  expect_equal(
    build_nsis_config(list(installer = list(
      one_click = FALSE,
      allow_to_change_installation_directory = TRUE,
      per_machine = FALSE
    ))),
    list(oneClick = FALSE, allowToChangeInstallationDirectory = TRUE,
         perMachine = FALSE)
  )
})

test_that("build_nsis_config passes explicit per_machine through", {
  expect_equal(
    build_nsis_config(list(installer = list(one_click = TRUE, per_machine = TRUE))),
    list(oneClick = TRUE, perMachine = TRUE)
  )
  expect_equal(
    build_nsis_config(list(installer = list(
      one_click = FALSE,
      allow_to_change_installation_directory = FALSE,
      per_machine = TRUE
    ))),
    list(oneClick = FALSE, allowToChangeInstallationDirectory = FALSE,
         perMachine = TRUE)
  )
})

test_that("build_nsis_config is empty without installer options", {
  expect_equal(build_nsis_config(list()), list())

  parsed <- jsonlite::fromJSON(
    generate_package_json("my-app", "1.0.0", "native-r", list()),
    simplifyVector = FALSE
  )
  expect_null(parsed$build$nsis)
})

test_that("generate_package_json emits only oneClick for the default installer", {
  parsed <- jsonlite::fromJSON(
    generate_package_json("my-app", "1.0.0", "native-r", default_config()),
    simplifyVector = FALSE
  )
  expect_equal(parsed$build$nsis, list(oneClick = TRUE))
})

test_that("generate_package_json adds no directory page to the wizard by default", {
  cfg <- default_config()
  cfg$installer$one_click <- FALSE
  parsed <- jsonlite::fromJSON(
    generate_package_json("my-app", "1.0.0", "native-r", cfg),
    simplifyVector = FALSE
  )
  expect_equal(parsed$build$nsis, list(oneClick = FALSE))
})

test_that("generate_package_json emits installer.license_file as the NSIS license", {
  cfg <- default_config()
  cfg$installer$license_file <- "/path/to/LICENSE.txt"
  parsed <- jsonlite::fromJSON(
    generate_package_json("my-app", "1.0.0", "native-r", cfg),
    simplifyVector = FALSE
  )
  # electron-builder 26 rejects `license` under `win`; it is an NSIS option.
  expect_null(parsed$build$win$license)
  expect_equal(parsed$build$nsis,
               list(oneClick = TRUE, license = "build/installer-license.txt"))
})

test_that("installer_license_path keeps the license format", {
  expect_equal(installer_license_path("docs/EULA.RTF"), "build/installer-license.rtf")
  expect_equal(installer_license_path("terms.html"), "build/installer-license.html")
  expect_equal(installer_license_path("LICENSE"), "build/installer-license.txt")
})

test_that("installer_license_path renames .htm licenses to .html", {
  # electron-builder renders a license as HTML only when it ends in .html.
  expect_equal(installer_license_path("terms.htm"), "build/installer-license.html")
  expect_equal(installer_license_path("TERMS.HTM"), "build/installer-license.html")
})
