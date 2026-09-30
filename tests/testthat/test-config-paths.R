# Paths in _shinyelectron.yml resolve against the directory that holds it,
# never against the working directory.

write_png <- function(path, marker = "") {
  fs::dir_create(fs::path_dir(path))
  sig <- as.raw(c(0x89, 0x50, 0x4e, 0x47, 0x0d, 0x0a, 0x1a, 0x0a))
  writeBin(c(sig, charToRaw(marker)), path)
  invisible(path)
}

local_config_app <- function(config = NULL, env = parent.frame()) {
  appdir <- withr::local_tempdir(.local_envir = env)
  writeLines("library(shiny)\nshinyApp(fluidPage(), function(input, output) {})",
             fs::path(appdir, "app.R"))
  if (!is.null(config)) {
    yaml::write_yaml(config, fs::path(appdir, "_shinyelectron.yml"))
  }
  appdir
}

# Run the real export pipeline without shinylive, npm or electron-builder.
local_fake_build <- function(env = parent.frame()) {
  local_mocked_bindings(
    convert_app_to_shinylive = function(appdir, destdir, ...) {
      out <- fs::path(destdir, "shinylive-app")
      fs::dir_create(out)
      writeLines("<html></html>", fs::path(out, "index.html"))
      out
    },
    resolve_app_dependencies = function(...) NULL,
    validate_node_npm = function(...) invisible(NULL),
    install_npm_dependencies = function(...) invisible(NULL),
    build_for_platforms = function(...) invisible(NULL),
    validate_build_output = function(...) invisible(NULL),
    .env = env
  )
}

# --- resolve_config_path() / resolve_config_paths() ---

test_that("resolve_config_path() resolves relative paths against the base", {
  base <- withr::local_tempdir()
  expect_equal(resolve_config_path("branding/icon.png", base),
               as.character(fs::path(base, "branding", "icon.png")))
  expect_equal(resolve_config_path("../shared/icon.png", fs::path(base, "app")),
               as.character(fs::path(base, "shared", "icon.png")))
})

test_that("resolve_config_path() takes a relative base from the working directory", {
  withr::local_dir(withr::local_tempdir())
  expect_equal(resolve_config_path("icon.png", "my-app"),
               as.character(fs::path(getwd(), "my-app", "icon.png")))
})

test_that("resolve_config_path() keeps absolute paths and expands ~", {
  base <- withr::local_tempdir()
  elsewhere <- withr::local_tempdir()
  abs_icon <- as.character(fs::path(elsewhere, "icon.png"))
  expect_equal(resolve_config_path(abs_icon, base), abs_icon)
  expect_equal(resolve_config_path("~/icons/icon.png", base),
               as.character(fs::path_abs(path.expand("~/icons/icon.png"))))
})

test_that("resolve_config_paths() resolves every build-machine path", {
  base <- withr::local_tempdir()
  elsewhere <- withr::local_tempdir()
  abs_splash <- as.character(fs::path(elsewhere, "logo.png"))
  config <- list(
    icon = "icon.png",
    icons = list(mac = "icons/icon.icns", win = "icons/icon.ico",
                 linux = "icons/icon.png"),
    splash = list(image = abs_splash, text = "Loading..."),
    tray = list(enabled = TRUE, icon = "tray.png"),
    signing = list(win = list(certificate_file = "certs/signing.pfx")),
    apps = list(
      list(id = "a", name = "A", path = "apps/a", icon = "icons/a.png"),
      list(id = "b", name = "B", path = "apps/b")
    )
  )
  resolved <- resolve_config_paths(config, base)
  at <- function(...) as.character(fs::path(base, ...))

  expect_equal(resolved$icon, at("icon.png"))
  expect_equal(resolved$icons$mac, at("icons", "icon.icns"))
  expect_equal(resolved$icons$win, at("icons", "icon.ico"))
  expect_equal(resolved$icons$linux, at("icons", "icon.png"))
  expect_equal(resolved$splash$image, abs_splash)
  expect_equal(resolved$splash$text, "Loading...")
  expect_equal(resolved$tray$icon, at("tray.png"))
  expect_equal(resolved$signing$win$certificate_file, at("certs", "signing.pfx"))
  expect_equal(resolved$apps[[1]]$path, at("apps", "a"))
  expect_equal(resolved$apps[[1]]$icon, at("icons", "a.png"))
  expect_equal(resolved$apps[[2]]$path, at("apps", "b"))
  expect_null(resolved$apps[[2]]$icon)

  # Resolving again changes nothing.
  expect_identical(resolve_config_paths(resolved, withr::local_tempdir()), resolved)
})

test_that("resolve_config_paths() leaves end-user paths and other values alone", {
  base <- withr::local_tempdir()
  config <- list(
    app = list(name = "App", log_dir = "logs"),
    dependencies = list(r = list(lib_path = "library")),
    container = list(volumes = list(data = "/app/data")),
    splash = list(image = NULL),
    tray = list(icon = 42)
  )
  expect_identical(resolve_config_paths(config, base), config)

  # An empty path counts as unset.
  resolved <- resolve_config_paths(list(icon = "", splash = list(image = "")), base)
  expect_null(resolved$icon)
  expect_null(resolved$splash$image)
})

# --- export(): single app ---

test_that("export() resolves config paths against the app directory", {
  elsewhere <- withr::local_tempdir()
  cert_dir <- withr::local_tempdir()
  write_png(fs::path(elsewhere, "logo.png"), "absolute splash")
  file.create(fs::path(cert_dir, "signing.pfx"))

  appdir <- local_config_app(list(
    icons = list(win = "branding/icon.ico"),
    splash = list(image = as.character(fs::path(elsewhere, "logo.png"))),
    tray = list(enabled = TRUE, icon = "branding/tray.png"),
    signing = list(win = list(
      certificate_file = as.character(fs::path(cert_dir, "signing.pfx"))
    ))
  ))
  write_png(fs::path(appdir, "branding", "icon.ico"), "icon")
  write_png(fs::path(appdir, "branding", "tray.png"), "tray")

  # The working directory has files with the same relative names; they must
  # not be picked up.
  wd <- withr::local_tempdir()
  write_png(fs::path(wd, "branding", "icon.ico"), "wrong icon")
  write_png(fs::path(wd, "branding", "tray.png"), "wrong tray")
  withr::local_dir(wd)

  local_fake_build()
  withr::local_envvar(WIN_CSC_LINK = NA, WIN_CSC_KEY_PASSWORD = NA,
                      CSC_LINK = NA, CSC_KEY_PASSWORD = "secret")
  destdir <- fs::path(withr::local_tempdir(), "out")
  result <- export(appdir, destdir, platform = "win", sign = TRUE,
                   verbose = FALSE)

  assets <- fs::path(result$electron_app, "assets")
  expect_identical(readBin(fs::path(assets, "icon.ico"), "raw", 100),
                   readBin(fs::path(appdir, "branding", "icon.ico"), "raw", 100))
  expect_identical(readBin(fs::path(assets, "tray.png"), "raw", 100),
                   readBin(fs::path(appdir, "branding", "tray.png"), "raw", 100))
  expect_identical(readBin(fs::path(assets, "splash-image.png"), "raw", 100),
                   readBin(fs::path(elsewhere, "logo.png"), "raw", 100))

  pkg <- jsonlite::fromJSON(fs::path(result$electron_app, "package.json"))
  expect_equal(pkg$build$win$signtoolOptions$certificateFile,
               as.character(fs::path(cert_dir, "signing.pfx")))
})

test_that("export() resolves a relative certificate path against the app directory", {
  appdir <- local_config_app(list(
    signing = list(sign = TRUE,
                   win = list(certificate_file = "certs/signing.pfx"))
  ))
  fs::dir_create(fs::path(appdir, "certs"))
  file.create(fs::path(appdir, "certs", "signing.pfx"))
  withr::local_dir(withr::local_tempdir())

  local_fake_build()
  withr::local_envvar(WIN_CSC_LINK = NA, WIN_CSC_KEY_PASSWORD = NA,
                      CSC_LINK = NA, CSC_KEY_PASSWORD = "secret")
  destdir <- fs::path(withr::local_tempdir(), "out")
  expect_no_warning(
    result <- export(appdir, destdir, platform = "win", verbose = FALSE)
  )

  pkg <- jsonlite::fromJSON(fs::path(result$electron_app, "package.json"))
  expect_equal(pkg$build$win$signtoolOptions$certificateFile,
               as.character(fs::path(appdir, "certs", "signing.pfx")))
})

test_that("the icon argument stays relative to the working directory", {
  appdir <- local_config_app()
  write_png(fs::path(appdir, "icon.png"), "app directory")
  wd <- withr::local_tempdir()
  write_png(fs::path(wd, "icon.png"), "working directory")
  withr::local_dir(wd)

  local_fake_build()
  destdir <- fs::path(withr::local_tempdir(), "out")
  result <- export(appdir, destdir, icon = "icon.png", platform = "linux",
                   verbose = FALSE)

  expect_identical(
    readBin(fs::path(result$electron_app, "assets", "icon.png"), "raw", 100),
    readBin(fs::path(wd, "icon.png"), "raw", 100)
  )
})

test_that("export() picks the icons entry for the target platform", {
  appdir <- local_config_app(list(
    icons = list(mac = "icons/icon.icns", linux = "icons/icon.png")
  ))
  write_png(fs::path(appdir, "icons", "icon.png"), "linux")
  withr::local_dir(withr::local_tempdir())

  local_fake_build()
  destdir <- fs::path(withr::local_tempdir(), "out")
  result <- export(appdir, destdir, platform = "linux", verbose = FALSE)
  expect_true(fs::file_exists(fs::path(result$electron_app, "assets", "icon.png")))
})

test_that("export() stops when the configured icon does not exist", {
  appdir <- local_config_app(list(icons = list(linux = "icons/missing.png")))
  wd <- withr::local_tempdir()
  write_png(fs::path(wd, "icons", "missing.png"))
  withr::local_dir(wd)

  local_fake_build()
  destdir <- fs::path(withr::local_tempdir(), "out")
  err <- expect_error(
    export(appdir, destdir, platform = "linux", verbose = FALSE),
    class = "shinyelectron_config_file_not_found"
  )
  msg <- cli::ansi_strip(conditionMessage(err))
  expect_match(msg, "icons.linux", fixed = TRUE)
  expect_match(msg, basename(appdir), fixed = TRUE)
  expect_false(fs::dir_exists(destdir))
})

test_that("export() warns about a missing splash image or tray icon and builds without it", {
  appdir <- local_config_app(list(
    splash = list(image = "assets/logo.png"),
    tray = list(enabled = TRUE, icon = "assets/tray.png")
  ))
  # Present in the working directory only: the old behaviour picked these up.
  wd <- withr::local_tempdir()
  write_png(fs::path(wd, "assets", "logo.png"))
  write_png(fs::path(wd, "assets", "tray.png"))
  withr::local_dir(wd)

  local_fake_build()
  destdir <- fs::path(withr::local_tempdir(), "out")
  # Record only the missing-file warnings; any other warning still propagates.
  rec <- mockery::mock()
  result <- withCallingHandlers(
    export(appdir, destdir, platform = "linux", verbose = FALSE),
    shinyelectron_config_file_not_found = function(w) {
      rec(cli::ansi_strip(conditionMessage(w)))
      invokeRestart("muffleWarning")
    }
  )
  warnings <- lapply(mockery::mock_args(rec), `[[`, 1L)

  expect_length(warnings, 2)
  expect_match(warnings[[1]], "splash.image", fixed = TRUE)
  expect_match(warnings[[1]], fs::path("assets", "logo.png"), fixed = TRUE)
  expect_match(warnings[[1]], basename(appdir), fixed = TRUE)
  expect_match(warnings[[2]], "tray.icon", fixed = TRUE)

  electron_app <- result$electron_app
  expect_length(fs::dir_ls(fs::path(electron_app, "assets")), 0)
  lifecycle <- readLines(fs::path(electron_app, "lifecycle.html"))
  expect_false(any(grepl("assets/splash-image.png", lifecycle, fixed = TRUE)))
  main_js <- readLines(fs::path(electron_app, "main.js"))
  expect_false(any(grepl("tray.png", main_js, fixed = TRUE)))
})

test_that("export() checks the tray's app icon for the target platform", {
  # The check must follow the target platform, not the build machine.
  local_mocked_bindings(detect_current_platform = function() "linux")
  appdir <- local_config_app(list(
    icons = list(win = "branding/icon.ico", mac = "branding/icon.icns"),
    tray = list(enabled = TRUE)
  ))
  write_png(fs::path(appdir, "branding", "icon.ico"))
  write_png(fs::path(appdir, "branding", "icon.icns"))
  withr::local_dir(withr::local_tempdir())
  local_fake_build()

  # Windows reads the .ico app icon, so the tray loads it.
  expect_no_warning(
    win <- export(appdir, fs::path(withr::local_tempdir(), "out"),
                  platform = "win", verbose = FALSE)
  )
  main_js <- readLines(fs::path(win$electron_app, "main.js"))
  expect_true(any(grepl("createFromPath(path.join(__dirname, 'assets', 'icon.ico'))",
                        main_js, fixed = TRUE)))

  # No platform reads an .icns file. A macOS target builds only on a Mac.
  local_mocked_bindings(detect_current_platform = function() "mac")
  expect_warning(
    export(appdir, fs::path(withr::local_tempdir(), "out"), platform = "mac",
           verbose = FALSE),
    "app icon",
    class = "shinyelectron_tray_icon_unsupported"
  )
})

test_that("export() gives no icon to a target platform it is too small for", {
  # A macOS target builds only on a Mac.
  local_mocked_bindings(detect_current_platform = function() "mac")
  appdir <- local_config_app(list(icon = "branding/icon.png"))
  fs::dir_create(fs::path(appdir, "branding"))
  fs::file_copy(local_png_icon(300), fs::path(appdir, "branding", "icon.png"))
  withr::local_dir(withr::local_tempdir())
  local_fake_build()

  # A 300x300 PNG is large enough for Linux but not for macOS.
  w <- expect_warning(
    result <- export(appdir, fs::path(withr::local_tempdir(), "out"),
                     platform = c("mac", "linux"), verbose = FALSE),
    class = "shinyelectron_icon_too_small"
  )
  expect_match(gsub("[[:space:]]+", " ", cli::ansi_strip(conditionMessage(w))),
               "too small for \"mac\".", fixed = TRUE)
  pkg <- jsonlite::fromJSON(fs::path(result$electron_app, "package.json"),
                            simplifyVector = FALSE)
  expect_null(pkg$build$mac$icon)
  expect_equal(pkg$build$linux$icon, "assets/icon.png")
})

test_that("export() warns about a missing certificate only when signing Windows builds", {
  appdir <- local_config_app(list(
    signing = list(win = list(certificate_file = "certs/missing.pfx"))
  ))
  withr::local_dir(withr::local_tempdir())
  withr::local_envvar(WIN_CSC_LINK = NA, WIN_CSC_KEY_PASSWORD = NA,
                      CSC_LINK = NA, CSC_KEY_PASSWORD = "secret")
  local_fake_build()

  expect_no_warning(
    export(appdir, fs::path(withr::local_tempdir(), "out"), platform = "win",
           verbose = FALSE)
  )

  # The sign argument turns signing on without signing.sign in the config.
  expect_warning(
    export(appdir, fs::path(withr::local_tempdir(), "out"), platform = "win",
           sign = TRUE, verbose = FALSE),
    "signing.win.certificate_file",
    class = "shinyelectron_config_file_not_found"
  )
})

# --- export(): multi-app suite ---

test_that("export() resolves suite paths against the suite root", {
  suite <- withr::local_tempdir()
  for (id in c("dash", "admin")) {
    fs::dir_create(fs::path(suite, "apps", id))
    writeLines("library(shiny)\nshinyApp(fluidPage(), function(input, output) {})",
               fs::path(suite, "apps", id, "app.R"))
  }
  # A third app lives outside the suite root and is referenced by absolute path.
  outside <- withr::local_tempdir()
  writeLines("library(shiny)\nshinyApp(fluidPage(), function(input, output) {})",
             fs::path(outside, "app.R"))
  write_png(fs::path(suite, "branding", "icon.png"), "suite icon")
  write_png(fs::path(suite, "branding", "logo.png"), "suite splash")
  write_png(fs::path(suite, "branding", "dash.png"), "dash icon")
  yaml::write_yaml(list(
    app = list(name = "Suite"),
    build = list(type = "r-shiny", runtime_strategy = "system"),
    icon = "branding/icon.png",
    splash = list(image = "branding/logo.png"),
    apps = list(
      list(id = "dash", name = "Dash", path = "apps/dash",
           icon = "branding/dash.png"),
      list(id = "admin", name = "Admin", path = "./apps/admin",
           icon = "branding/missing.png"),
      list(id = "extra", name = "Extra", path = as.character(outside))
    )
  ), fs::path(suite, "_shinyelectron.yml"))
  withr::local_dir(withr::local_tempdir())

  local_fake_build()
  destdir <- fs::path(withr::local_tempdir(), "out")
  expect_warning(
    result <- export(suite, destdir, platform = "linux", verbose = FALSE),
    "admin",
    class = "shinyelectron_config_file_not_found"
  )

  electron_app <- result$electron_app
  assets <- fs::path(electron_app, "assets")
  expect_identical(readBin(fs::path(assets, "icon.png"), "raw", 100),
                   readBin(fs::path(suite, "branding", "icon.png"), "raw", 100))
  expect_identical(readBin(fs::path(assets, "splash-image.png"), "raw", 100),
                   readBin(fs::path(suite, "branding", "logo.png"), "raw", 100))
  expect_identical(readBin(fs::path(assets, "apps", "dash.png"), "raw", 100),
                   readBin(fs::path(suite, "branding", "dash.png"), "raw", 100))
  expect_true(fs::file_exists(fs::path(electron_app, "src", "apps", "extra", "app.R")))

  manifest <- jsonlite::fromJSON(fs::path(electron_app, "apps-manifest.json"),
                                 simplifyVector = FALSE)
  icons <- lapply(manifest$apps, function(a) a$icon)
  expect_equal(icons[[1]], "assets/apps/dash.png")
  expect_null(icons[[2]])
  expect_null(icons[[3]])
})

# --- build_electron_app() ---

test_that("a config passed to build_electron_app() uses the working directory", {
  app_dir <- withr::local_tempdir()
  writeLines("<html></html>", fs::path(app_dir, "index.html"))
  wd <- withr::local_tempdir()
  write_png(fs::path(wd, "logo.png"), "working directory")
  withr::local_dir(wd)

  local_fake_build()
  output_dir <- fs::path(withr::local_tempdir(), "electron-app")
  expect_warning(
    build_electron_app(
      app_dir, output_dir, app_name = "Direct", platform = "linux",
      config = list(splash = list(image = "logo.png"),
                    tray = list(enabled = TRUE, icon = "missing.png")),
      verbose = FALSE
    ),
    "tray.icon",
    class = "shinyelectron_config_file_not_found"
  )
  expect_identical(
    readBin(fs::path(output_dir, "assets", "splash-image.png"), "raw", 100),
    readBin(fs::path(wd, "logo.png"), "raw", 100)
  )
  expect_false(fs::file_exists(fs::path(output_dir, "assets", "missing.png")))
})

# --- app_check() ---

test_that("app_check() looks up configured files in the app directory", {
  appdir <- local_config_app(list(
    icon = "branding/icon.png",
    splash = list(image = "branding/logo.png"),
    tray = list(icon = "branding/missing.png")
  ))
  write_png(fs::path(appdir, "branding", "icon.png"))
  write_png(fs::path(appdir, "branding", "logo.png"))
  wd <- withr::local_tempdir()
  write_png(fs::path(wd, "branding", "missing.png"))
  withr::local_dir(wd)

  result <- app_check(appdir, verbose = FALSE)
  expect_false(any(grepl("icon file not found", result$errors, fixed = TRUE)))
  expect_false(any(grepl("splash.image", result$warnings, fixed = TRUE)))
  expect_true(any(grepl("tray.icon file not found", result$warnings, fixed = TRUE)))
  expect_true(any(grepl(basename(appdir), result$warnings, fixed = TRUE)))
})

test_that("app_check() fails when the configured icon does not exist", {
  appdir <- local_config_app(list(icons = list(linux = "icons/missing.png")))
  wd <- withr::local_tempdir()
  write_png(fs::path(wd, "icons", "missing.png"))
  withr::local_dir(wd)

  result <- app_check(appdir, platform = "linux", verbose = FALSE)
  expect_false(result$pass)
  expect_true(any(grepl("icons.linux file not found", result$errors, fixed = TRUE)))
})

test_that("app_check() warns about the platforms the icon is too small for", {
  appdir <- local_config_app(list(icon = "branding/icon.png"))
  fs::dir_create(fs::path(appdir, "branding"))
  fs::file_copy(local_png_icon(128), fs::path(appdir, "branding", "icon.png"))
  withr::local_dir(withr::local_tempdir())

  # Windows needs 256x256 pixels; Linux uses the PNG as it is.
  result <- app_check(appdir, platform = c("win", "linux"), verbose = FALSE)
  expect_true(result$pass)
  too_small <- grepl("too small for", result$warnings, fixed = TRUE)
  expect_equal(sum(too_small), 1)
  msg <- gsub("[[:space:]]+", " ", cli::ansi_strip(result$warnings[too_small]))
  expect_match(msg, "too small for \"win\".", fixed = TRUE)
  expect_match(msg, basename(appdir), fixed = TRUE)

  expect_false(any(grepl("too small for",
                         app_check(appdir, platform = "linux", verbose = FALSE)$warnings,
                         fixed = TRUE)))
})

test_that("app_check() reports a missing certificate when signing Windows builds", {
  appdir <- local_config_app(list(
    signing = list(win = list(certificate_file = "certs/missing.pfx"))
  ))
  withr::local_envvar(WIN_CSC_LINK = NA, WIN_CSC_KEY_PASSWORD = NA,
                      CSC_LINK = NA, CSC_KEY_PASSWORD = "secret")

  unsigned <- app_check(appdir, platform = "win", verbose = FALSE)
  expect_false(any(grepl("certificate_file", unsigned$warnings, fixed = TRUE)))

  signed <- app_check(appdir, platform = "win", sign = TRUE, verbose = FALSE)
  expect_true(any(grepl("signing.win.certificate_file file not found",
                        signed$warnings, fixed = TRUE)))
})
