# export() builds for its platform and arch arguments, else for
# build.platforms and build.architectures in _shinyelectron.yml, else for the
# build machine.

local_targets_app <- function(config = NULL, env = parent.frame()) {
  appdir <- withr::local_tempdir(.local_envir = env)
  writeLines("library(shiny)\nshinyApp(fluidPage(), function(input, output) {})",
             fs::path(appdir, "app.R"))
  if (!is.null(config)) {
    yaml::write_yaml(config, fs::path(appdir, "_shinyelectron.yml"))
  }
  appdir
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

  expect_equal(resolve_build_targets(NULL, NULL, config),
               list(platform = c("mac", "win"), arch = "arm64"))
  expect_equal(resolve_build_targets("win", NULL, config),
               list(platform = "win", arch = "arm64"))
  expect_equal(resolve_build_targets(NULL, "x64", config),
               list(platform = c("mac", "win"), arch = "x64"))
  expect_equal(resolve_build_targets(NULL, NULL, list()),
               list(platform = "linux", arch = "x64"))

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

test_that("read_config() keeps the valid targets as a character vector", {
  appdir <- local_targets_app()
  # A sequence that mixes strings and numbers parses to a list.
  writeLines(c("build:", "  platforms: [mac, windows, 1]", "  architectures: [x64]"),
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

test_that("export() checks Windows signing when build.platforms includes win", {
  local_mocked_bindings(detect_current_platform = function() "linux")
  appdir <- local_targets_app(list(
    build = list(platforms = "win"),
    signing = list(sign = TRUE, win = list(certificate_file = "certs/missing.pfx"))
  ))
  withr::local_envvar(WIN_CSC_LINK = NA, WIN_CSC_KEY_PASSWORD = NA,
                      CSC_LINK = NA, CSC_KEY_PASSWORD = "secret")
  local_recorded_build()

  expect_warning(
    export(appdir, withr::local_tempdir(), overwrite = TRUE, verbose = FALSE),
    "signing.win.certificate_file",
    class = "shinyelectron_config_file_not_found"
  )
})

test_that("a bundled build stops when build.platforms lists two platforms", {
  appdir <- local_targets_app(list(build = list(
    runtime_strategy = "bundled", platforms = c("mac", "win")
  )))
  local_mocked_bindings(
    resolve_app_dependencies = function(...) NULL,
    validate_node_npm = function(...) invisible(TRUE),
    embed_r_runtime = function(...) stop("embedded a runtime")
  )

  expect_error(
    export(appdir, withr::local_tempdir(), overwrite = TRUE, verbose = FALSE),
    "one platform and architecture"
  )
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
  suite <- withr::local_tempdir()
  for (id in c("one", "two")) {
    fs::dir_create(fs::path(suite, "apps", id))
    writeLines("library(shiny)\nshinyApp(fluidPage(), function(input, output) {})",
               fs::path(suite, "apps", id, "app.R"))
  }
  yaml::write_yaml(list(
    build = list(type = "r-shiny", runtime_strategy = "system",
                 platforms = c("linux", "win"),
                 architectures = c("x64", "arm64")),
    apps = list(
      list(id = "one", name = "One", path = "apps/one"),
      list(id = "two", name = "Two", path = "apps/two")
    )
  ), fs::path(suite, "_shinyelectron.yml"))

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
