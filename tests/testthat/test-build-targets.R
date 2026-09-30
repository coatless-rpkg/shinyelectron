# export() builds for its platform and arch arguments, else for
# build.platforms and build.architectures in _shinyelectron.yml, else for the
# build machine, and stops before any work on targets it cannot build.

local_targets_app <- function(config = NULL, env = parent.frame()) {
  appdir <- withr::local_tempdir(.local_envir = env)
  writeLines("library(shiny)\nshinyApp(fluidPage(), function(input, output) {})",
             fs::path(appdir, "app.R"))
  if (!is.null(config)) {
    yaml::write_yaml(config, fs::path(appdir, "_shinyelectron.yml"))
  }
  appdir
}

# A suite of two R apps with the given build settings.
local_targets_suite <- function(build, env = parent.frame()) {
  suite <- withr::local_tempdir(.local_envir = env)
  for (id in c("one", "two")) {
    fs::dir_create(fs::path(suite, "apps", id))
    writeLines("library(shiny)\nshinyApp(fluidPage(), function(input, output) {})",
               fs::path(suite, "apps", id, "app.R"))
  }
  yaml::write_yaml(list(
    build = c(list(type = "r-shiny"), build),
    apps = list(
      list(id = "one", name = "One", path = "apps/one"),
      list(id = "two", name = "Two", path = "apps/two")
    )
  ), fs::path(suite, "_shinyelectron.yml"))
  suite
}

# Skip the conversion and record the arguments export() passes to
# build_electron_app().
local_recorded_build <- function(env = parent.frame()) {
  build_rec <- mockery::mock(tempdir(), cycle = TRUE)
  local_mocked_bindings(
    convert_app_to_shinylive = function(appdir, destdir, ...) {
      fs::path(destdir, "shinylive-app")
    },
    build_electron_app = build_rec,
    .env = env
  )
  build_rec
}

# --- resolve_build_targets() ---

test_that("resolve_build_targets() takes the arguments, then the config, then the machine", {
  local_mocked_bindings(
    detect_current_platform = function() "linux",
    detect_current_arch = function() "x64"
  )
  config <- list(build = list(platforms = c("mac", "win"), architectures = "arm64"))

  # from_config names the settings that supplied the targets.
  expect_equal(resolve_build_targets(NULL, NULL, config),
               list(platform = c("mac", "win"), arch = "arm64",
                    from_config = c("build.platforms", "build.architectures")))
  expect_equal(resolve_build_targets("win", NULL, config),
               list(platform = "win", arch = "arm64",
                    from_config = "build.architectures"))
  expect_equal(resolve_build_targets(NULL, "x64", config),
               list(platform = c("mac", "win"), arch = "x64",
                    from_config = "build.platforms"))
  expect_equal(resolve_build_targets(NULL, NULL, list()),
               list(platform = "linux", arch = "x64", from_config = character(0)))

  # A target named twice is built once.
  targets <- resolve_build_targets(c("win", "linux", "win"), c("x64", "x64"), list())
  expect_equal(targets$platform, c("win", "linux"))
  expect_equal(targets$arch, "x64")

  # Configured values are checked like the arguments, for a config that did
  # not come through read_config().
  expect_error(
    resolve_build_targets(NULL, NULL, list(build = list(platforms = "windows"))),
    "Invalid platform"
  )
  expect_error(
    resolve_build_targets(NULL, NULL, list(build = list(architectures = "x86"))),
    "Invalid architecture"
  )
})

# --- read_config() ---

test_that("read_config() keeps the valid targets once each, as a character vector", {
  appdir <- local_targets_app()
  # A sequence that mixes strings and numbers parses to a list.
  writeLines(c("build:", "  platforms: [mac, windows, 1, mac]",
               "  architectures: [x64, x64]"),
             fs::path(appdir, "_shinyelectron.yml"))

  expect_warning(config <- read_config(appdir), "windows")
  expect_identical(config$build$platforms, "mac")
  expect_identical(config$build$architectures, "x64")
})

test_that("a target list with nothing valid in it counts as unset", {
  local_mocked_bindings(
    detect_current_platform = function() "linux",
    detect_current_arch = function() "x64"
  )
  appdir <- local_targets_app()
  writeLines(c("build:", "  platforms: []", "  architectures: [x86]"),
             fs::path(appdir, "_shinyelectron.yml"))

  expect_warning(config <- read_config(appdir),
                 "Falling back to the current architecture")
  expect_null(config$build$platforms)
  expect_null(config$build$architectures)

  # So export() builds for the build machine instead of for nothing.
  build_rec <- local_recorded_build()
  expect_warning(
    export(appdir, withr::local_tempdir(), overwrite = TRUE, verbose = FALSE),
    "Falling back to the current architecture"
  )
  args <- mockery::mock_args(build_rec)[[1]]
  expect_equal(args$platform, "linux")
  expect_equal(args$arch, "x64")
})

# --- export(): single app ---

test_that("export() builds for build.platforms and build.architectures", {
  # A Mac can build all three platforms.
  local_mocked_bindings(detect_current_platform = function() "mac")
  appdir <- local_targets_app(list(build = list(
    platforms = c("linux", "win"), architectures = c("x64", "arm64")
  )))
  build_rec <- local_recorded_build()

  export(appdir, withr::local_tempdir(), overwrite = TRUE, verbose = FALSE)
  # Each argument overrides its own list.
  export(appdir, withr::local_tempdir(), platform = "mac",
         overwrite = TRUE, verbose = FALSE)
  export(appdir, withr::local_tempdir(), arch = "x64",
         overwrite = TRUE, verbose = FALSE)

  targets <- lapply(mockery::mock_args(build_rec), `[`, c("platform", "arch"))
  expect_equal(targets, list(
    list(platform = c("linux", "win"), arch = c("x64", "arm64")),
    list(platform = "mac", arch = c("x64", "arm64")),
    list(platform = c("linux", "win"), arch = "x64")
  ))
})

test_that("export() picks the icons entry for the first platform in build.platforms", {
  local_mocked_bindings(detect_current_platform = function() "linux")
  appdir <- local_targets_app(list(
    build = list(platforms = "win"),
    icons = list(win = "icons/icon.ico", linux = "icons/icon.png")
  ))
  fs::dir_create(fs::path(appdir, "icons"))
  file.create(fs::path(appdir, "icons", c("icon.ico", "icon.png")))
  build_rec <- local_recorded_build()

  export(appdir, withr::local_tempdir(), overwrite = TRUE, verbose = FALSE)
  expect_equal(basename(mockery::mock_args(build_rec)[[1]]$icon), "icon.ico")
})

test_that("the $ check for the Windows installer follows build.platforms", {
  # A Windows target stops the export on any build machine.
  local_mocked_bindings(detect_current_platform = function() "linux")
  build_rec <- local_recorded_build()
  appdir <- local_targets_app(list(
    app = list(name = "Price$Tracker"), build = list(platforms = "win")
  ))
  expect_error(
    export(appdir, withr::local_tempdir(), overwrite = TRUE, verbose = FALSE),
    class = "shinyelectron_installer_dollar"
  )
  mockery::expect_called(build_rec, 0)

  # Other targets only warn, even on Windows.
  local_mocked_bindings(detect_current_platform = function() "win")
  appdir <- local_targets_app(list(
    app = list(name = "Price$Tracker"), build = list(platforms = "linux")
  ))
  expect_warning(
    export(appdir, withr::local_tempdir(), overwrite = TRUE, verbose = FALSE),
    class = "shinyelectron_installer_dollar"
  )
  mockery::expect_called(build_rec, 1)
})

test_that("export() checks signing for each platform in build.platforms", {
  # On a Linux machine, a win target still gets the Windows checks.
  local_mocked_bindings(detect_current_platform = function() "linux")
  local_recorded_build()

  appdir <- local_targets_app(list(
    build = list(platforms = "win"), signing = list(sign = TRUE)
  ))
  withr::local_envvar(WIN_CSC_LINK = NA, CSC_LINK = NA)
  expect_warning(
    export(appdir, withr::local_tempdir(), overwrite = TRUE, verbose = FALSE),
    "Windows: no signing certificate"
  )

  appdir <- local_targets_app(list(
    build = list(platforms = "win"),
    signing = list(sign = TRUE, win = list(certificate_file = "certs/missing.pfx"))
  ))
  withr::local_envvar(WIN_CSC_KEY_PASSWORD = NA, CSC_KEY_PASSWORD = "secret")
  expect_warning(
    export(appdir, withr::local_tempdir(), overwrite = TRUE, verbose = FALSE),
    "signing.win.certificate_file",
    class = "shinyelectron_config_file_not_found"
  )
})

test_that("the auto-download runtime manifest is for build.platforms and build.architectures", {
  local_mocked_bindings(
    detect_current_platform = function() "mac",
    detect_current_arch = function() "arm64"
  )
  appdir <- local_targets_app(list(build = list(
    runtime_strategy = "auto-download", platforms = "win", architectures = "x64"
  )))
  manifest_rec <- mockery::mock()
  local_mocked_bindings(
    resolve_app_dependencies = function(...) NULL,
    write_runtime_manifest = manifest_rec
  )

  export(appdir, withr::local_tempdir(), build = FALSE,
         overwrite = TRUE, verbose = FALSE)
  # write_runtime_manifest(app_dir, app_type, platform, arch, config, ...)
  args <- mockery::mock_args(manifest_rec)[[1]]
  expect_equal(args[[3]], "win")
  expect_equal(args[[4]], "x64")
})

test_that("export() stops on a macOS target before converting anything, except on a Mac", {
  # What wizard() wrote by default before it suggested the current platform.
  appdir <- local_targets_app(list(build = list(platforms = "mac")))
  convert_rec <- mockery::mock(tempdir(), cycle = TRUE)
  build_rec <- mockery::mock(tempdir(), cycle = TRUE)
  local_mocked_bindings(
    detect_current_platform = function() "win",
    convert_app_to_shinylive = convert_rec,
    build_electron_app = build_rec
  )

  expect_error(
    export(appdir, withr::local_tempdir(), overwrite = TRUE, verbose = FALSE),
    "build.platforms",
    class = "shinyelectron_mac_host"
  )
  # The argument is checked the same way; the setting it overrides is not
  # named.
  err <- expect_error(
    export(appdir, withr::local_tempdir(), platform = c("win", "mac"),
           overwrite = TRUE, verbose = FALSE),
    class = "shinyelectron_mac_host"
  )
  expect_no_match(conditionMessage(err), "build.platforms", fixed = TRUE)
  mockery::expect_called(convert_rec, 0)

  # Without a build, electron-builder never runs.
  export(appdir, withr::local_tempdir(), build = FALSE,
         overwrite = TRUE, verbose = FALSE)
  mockery::expect_called(convert_rec, 1)
  mockery::expect_called(build_rec, 0)

  local_mocked_bindings(detect_current_platform = function() "mac")
  export(appdir, withr::local_tempdir(), overwrite = TRUE, verbose = FALSE)
  expect_equal(mockery::mock_args(build_rec)[[1]]$platform, "mac")
})

test_that("a bundled or auto-download build for several targets stops before copying", {
  local_mocked_bindings(
    detect_current_platform = function() "mac",
    detect_current_arch = function() "arm64"
  )
  prep_rec <- mockery::mock()
  local_mocked_bindings(prepare_native_app_files = prep_rec)

  appdir <- local_targets_app(list(build = list(
    runtime_strategy = "bundled", platforms = c("mac", "win")
  )))
  destdir <- fs::path(withr::local_tempdir(), "out")
  err <- expect_error(
    export(appdir, destdir, verbose = FALSE),
    "build.platforms",
    class = "shinyelectron_single_target"
  )
  expect_no_match(conditionMessage(err), "build.architectures", fixed = TRUE)

  appdir <- local_targets_app(list(build = list(
    runtime_strategy = "auto-download", architectures = c("x64", "arm64")
  )))
  err <- expect_error(
    export(appdir, destdir, verbose = FALSE),
    "build.architectures",
    class = "shinyelectron_single_target"
  )
  expect_no_match(conditionMessage(err), "build.platforms", fixed = TRUE)

  # Targets from the arguments stop the same way.
  expect_error(
    export(appdir, destdir, arch = "x64", platform = c("mac", "win"),
           verbose = FALSE),
    class = "shinyelectron_single_target"
  )

  mockery::expect_called(prep_rec, 0)
  expect_false(fs::dir_exists(destdir))
})

test_that("export() checks the targets before converting anything", {
  appdir <- local_targets_app()
  convert_rec <- mockery::mock()
  local_mocked_bindings(
    convert_app_to_shinylive = convert_rec,
    build_electron_app = function(...) tempdir()
  )

  expect_error(
    export(appdir, withr::local_tempdir(), platform = "windows",
           overwrite = TRUE, verbose = FALSE),
    "Invalid platform"
  )
  expect_error(
    export(appdir, withr::local_tempdir(), arch = "x86",
           overwrite = TRUE, verbose = FALSE),
    "Invalid architecture"
  )
  mockery::expect_called(convert_rec, 0)
})

# --- export(): multi-app suite ---

test_that("a suite builds for build.platforms and build.architectures", {
  suite <- local_targets_suite(list(
    runtime_strategy = "system",
    platforms = c("linux", "win"), architectures = c("x64", "arm64")
  ))

  build_rec <- mockery::mock()
  local_mocked_bindings(
    resolve_app_dependencies = function(...) NULL,
    validate_node_npm = function(...) invisible(TRUE),
    install_npm_dependencies = function(...) invisible(TRUE),
    build_for_platforms = function(output_dir, platform, arch, ...) {
      build_rec(platform = platform, arch = arch)
    },
    validate_build_output = function(...) invisible(TRUE)
  )

  export(suite, withr::local_tempdir(), overwrite = TRUE, verbose = FALSE)
  # export_multi_app() reads the lists as well when handed the config.
  export_multi_app(suite, withr::local_tempdir(), read_config(suite),
                   overwrite = TRUE, verbose = FALSE)

  mockery::expect_called(build_rec, 2)
  for (args in mockery::mock_args(build_rec)) {
    expect_equal(args, list(platform = c("linux", "win"), arch = c("x64", "arm64")))
  }
})

test_that("a suite with a bundled app stops on several targets before staging", {
  local_mocked_bindings(detect_current_platform = function() "linux")
  suite <- local_targets_suite(list(
    runtime_strategy = "bundled", platforms = c("linux", "win")
  ))
  copy_rec <- mockery::mock()
  local_mocked_bindings(copy_dir_contents = copy_rec)

  destdir <- fs::path(withr::local_tempdir(), "out")
  err <- expect_error(
    export(suite, destdir, verbose = FALSE),
    "build.platforms",
    class = "shinyelectron_single_target"
  )
  expect_match(conditionMessage(err), "\"one\"", fixed = TRUE)
  mockery::expect_called(copy_rec, 0)
  expect_false(fs::dir_exists(destdir))
})
