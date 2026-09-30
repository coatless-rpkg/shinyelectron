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

# The icon that each platform's build config names, NULL when unset.
package_json_icons <- function(icon) {
  parsed <- jsonlite::fromJSON(
    generate_package_json("my-app", "1.0.0", "shinylive", list(), icon = icon),
    simplifyVector = FALSE
  )
  lapply(parsed$build[c("win", "mac", "linux")], function(p) p$icon)
}

test_that("generate_package_json points every platform at a PNG icon", {
  expect_equal(
    package_json_icons("branding/logo.png"),
    list(win = "assets/icon.png", mac = "assets/icon.png",
         linux = "assets/icon.png")
  )
})

test_that("generate_package_json points every platform at an .icns icon", {
  expect_equal(
    package_json_icons("branding/logo.icns"),
    list(win = "assets/icon.icns", mac = "assets/icon.icns",
         linux = "assets/icon.icns")
  )
})

test_that("generate_package_json gives an .ico icon to Windows only", {
  # electron-builder stops the build when asked to make a macOS icon or a
  # Linux icon set from an .ico file; with no icon it uses its default.
  expect_equal(
    package_json_icons("branding/logo.ico"),
    list(win = "assets/icon.ico", mac = NULL, linux = NULL)
  )
})

test_that("generate_package_json names no icon without a usable one", {
  none <- list(win = NULL, mac = NULL, linux = NULL)
  expect_equal(package_json_icons(NULL), none)
  expect_equal(package_json_icons("branding/logo.svg"), none)
})

test_that("icon_asset_path lowercases the extension", {
  # electron-builder reads the icon format from a lower-case extension only.
  expect_equal(icon_asset_path("branding/logo.png"), "assets/icon.png")
  expect_equal(icon_asset_path("C:/Art/LOGO.ICNS"), "assets/icon.icns")
  expect_equal(
    package_json_icons("Logo.ICO"),
    list(win = "assets/icon.ico", mac = NULL, linux = NULL)
  )
})

test_that("icon_platforms lists the platforms that can use each format", {
  expect_equal(icon_platforms("logo.png"), c("win", "mac", "linux"))
  expect_equal(icon_platforms("logo.PNG"), c("win", "mac", "linux"))
  expect_equal(icon_platforms("logo.icns"), c("win", "mac", "linux"))
  expect_equal(icon_platforms("logo.ico"), "win")
  expect_equal(icon_platforms("logo.svg"), character(0))
  expect_equal(icon_platforms("logo"), character(0))
})

test_that("package.json and main.js name the icon file the build copies", {
  # The platforms whose build config should name the icon.
  cases <- list(
    logo.png = c("win", "mac", "linux"),
    logo.icns = c("win", "mac", "linux"),
    logo.ico = "win",
    Logo.PNG = c("win", "mac", "linux")
  )
  for (name in names(cases)) {
    icon <- fs::path(withr::local_tempdir(), name)
    writeBin(as.raw(1:16), icon)
    out <- withr::local_tempdir()
    setup_electron_project(out, "Icon App", "r-shiny", verbose = FALSE)
    # Without tray.icon the tray loads the app icon. Electron cannot read an
    # .icns file there, which process_templates() warns about.
    suppressWarnings(
      process_templates(out, "Icon App", "r-shiny", runtime_strategy = "system",
                        icon = icon,
                        config = list(app = list(version = "1.0.0"),
                                      tray = list(enabled = TRUE)),
                        platform = "win", verbose = FALSE),
      classes = "shinyelectron_tray_icon_unsupported"
    )

    # Compare with the listing, which keeps the case of the file name even
    # on a case-insensitive file system.
    copied <- list.files(fs::path(out, "assets"))

    pkg <- jsonlite::fromJSON(fs::path(out, "package.json"),
                              simplifyVector = FALSE)
    icons <- unlist(lapply(pkg$build[c("win", "mac", "linux")],
                           function(p) p$icon))
    expect_setequal(names(icons), cases[[name]])
    expect_contains(paste0("assets/", copied), unname(icons))

    # The files that main.js loads from assets/ for the BrowserWindow icon
    # and for the tray
    main <- readLines(fs::path(out, "main.js"))
    loaded <- function(call) {
      pattern <- paste0(call, "\\(__dirname, 'assets', '([^']+)'\\)")
      matches <- regmatches(main, regexec(pattern, main))
      vapply(Filter(length, matches), `[`, character(1), 2)
    }
    window_icon <- loaded("icon: path\\.join")
    expect_length(window_icon, 1)
    expect_contains(copied, window_icon)
    tray_icon <- loaded("createFromPath\\(path\\.join")
    expect_length(tray_icon, 1)
    expect_contains(copied, tray_icon)
  }
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

test_that("the Linux desktop entry names the slug as the window class", {
  parsed <- jsonlite::fromJSON(
    generate_package_json("my-app", "1.0.0", "native-r", list(), app_name = "My App"),
    simplifyVector = FALSE
  )
  expect_equal(parsed$build$linux$target, "AppImage")
  expect_equal(parsed$build$linux$desktop$entry$StartupWMClass, "my-app")
})

test_that("productName stays under build, so the user data folder follows the slug", {
  # Electron names the app, and with it the user data folder, after a
  # top-level productName when package.json has one, else after name.
  # electron-builder drops the build block from the packaged package.json
  # and adds only what build.extraMetadata holds.
  parsed <- jsonlite::fromJSON(
    generate_package_json("my-app", "1.0.0", "native-r", list(), app_name = "My App"),
    simplifyVector = FALSE
  )
  expect_false("productName" %in% names(parsed))
  expect_false("extraMetadata" %in% names(parsed$build))
  expect_equal(parsed$name, "my-app")
  expect_equal(parsed$build$productName, "My App")
})
