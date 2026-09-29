test_that("validate_runtime_strategy accepts valid strategies", {
  expect_silent(validate_runtime_strategy("shinylive"))
  expect_silent(validate_runtime_strategy("bundled"))
  expect_silent(validate_runtime_strategy("system"))
  expect_silent(validate_runtime_strategy("auto-download"))
  expect_silent(validate_runtime_strategy("container"))
})

test_that("validate_runtime_strategy rejects invalid strategies", {
  expect_error(validate_runtime_strategy("invalid"), "Invalid runtime strategy")
  expect_error(validate_runtime_strategy("docker"), "Invalid runtime strategy")
})

test_that("validate_python_app_structure checks for app.py", {
  tmpdir <- tempfile()
  dir.create(tmpdir)
  on.exit(unlink(tmpdir, recursive = TRUE))

  expect_error(validate_python_app_structure(tmpdir), "app.py")

  writeLines("from shiny import App", file.path(tmpdir, "app.py"))
  expect_silent(validate_python_app_structure(tmpdir))
})

test_that("validate_r_available succeeds when Rscript is found", {
  # R CMD check's R_check_bin/Rscript shim does not always round-trip cleanly
  # through processx, causing this test to fail in the sandbox even though
  # Rscript is obviously present. Skip on CRAN and in R CMD check.
  skip_on_cran()
  skip_if(nzchar(Sys.getenv("_R_CHECK_PACKAGE_NAME_", "")))
  expect_silent(validate_r_available())
})

test_that("validate_r_available returns the Rscript path invisibly", {
  skip_on_cran()
  skip_if(nzchar(Sys.getenv("_R_CHECK_PACKAGE_NAME_", "")))
  result <- validate_r_available()
  expect_true(nzchar(result))
})

# Isolated tests that exercise the resolution logic without depending on the
# live Rscript shim, so they run in the standard CRAN / R CMD check pipeline.
test_that("validate_r_available errors when Rscript is not on PATH", {
  mockery::stub(validate_r_available, "Sys.getenv", function(...) "")
  mockery::stub(validate_r_available, "Sys.which", function(...) "")
  expect_error(validate_r_available(), "Rscript is required")
})

test_that("validate_r_available returns the resolved Rscript path", {
  mockery::stub(validate_r_available, "Sys.getenv", function(...) "checkmode")
  mockery::stub(validate_r_available, "Sys.which", function(...) "/usr/local/bin/Rscript")
  expect_equal(validate_r_available(), "/usr/local/bin/Rscript")
})

test_that("assert_safe_to_overwrite refuses protected dirs", {
  expect_error(assert_safe_to_overwrite("/"), "protected")
  expect_error(assert_safe_to_overwrite(normalizePath("~", mustWork = FALSE)), "protected")
  expect_true(assert_safe_to_overwrite(withr::local_tempdir()))
})

# 4D-1: wizard platform validation
test_that("wizard aborts for an invalid platform token", {
  tmp <- withr::local_tempdir()
  responses <- c("", "", "1", "1", "badplatform")
  idx <- 0L
  mockery::stub(wizard, "interactive", function() TRUE)
  mockery::stub(wizard, "readline", function(...) {
    idx <<- idx + 1L
    if (idx <= length(responses)) responses[[idx]] else ""
  })
  expect_error(
    capture.output(suppressMessages(wizard(tmp)), type = "output"),
    "Invalid platform"
  )
})

# 4D-2: enable_auto_updates rejects unsupported providers with a clear message
test_that("enable_auto_updates rejects s3 provider with clear error", {
  tmp <- withr::local_tempdir()
  writeLines(
    "app:\n  name: test\nbuild:\n  type: r-shiny\n  runtime_strategy: shinylive\n",
    file.path(tmp, "_shinyelectron.yml")
  )
  expect_error(
    enable_auto_updates(tmp, provider = "s3", owner = "x", repo = "y"),
    "not yet supported"
  )
})

test_that("enable_auto_updates rejects generic provider with clear error", {
  tmp <- withr::local_tempdir()
  writeLines(
    "app:\n  name: test\nbuild:\n  type: r-shiny\n  runtime_strategy: shinylive\n",
    file.path(tmp, "_shinyelectron.yml")
  )
  expect_error(
    enable_auto_updates(tmp, provider = "generic", owner = "x", repo = "y"),
    "not yet supported"
  )
})

# 4D-3: scalar guards in validate_config
test_that("validate_config warns clearly for a length-2 window width", {
  cfg <- list(window = list(width = c(1200, 800)))
  expect_warning(validated <- validate_config(cfg), "window.width")
  expect_equal(validated$window$width, SHINYELECTRON_DEFAULTS$window_width)
})

test_that("validate_config warns clearly for a list window height", {
  cfg <- list(window = list(height = list(800, 600)))
  expect_warning(validated <- validate_config(cfg), "window.height")
  expect_equal(validated$window$height, SHINYELECTRON_DEFAULTS$window_height)
})

test_that("validate_config warns clearly for a length-2 server port", {
  cfg <- list(server = list(port = c(3838, 3839)))
  expect_warning(validated <- validate_config(cfg), "server.port")
  expect_equal(validated$server$port, SHINYELECTRON_DEFAULTS$server_port)
})

# --- validate_config: dependencies version-string checks ---

test_that("validate_config warns and drops non-character electron version", {
  cfg <- list(dependencies = list(electron = list(version = 123)))
  expect_warning(
    out <- validate_config(cfg),
    regexp = "dependencies.electron.version"
  )
  expect_null(out$dependencies$electron$version)
})

test_that("validate_config warns and drops non-character r version", {
  cfg <- list(dependencies = list(r = list(version = TRUE)))
  expect_warning(
    out <- validate_config(cfg),
    regexp = "dependencies.r.version"
  )
  expect_null(out$dependencies$r$version)
})

test_that("validate_config warns and drops length > 1 python version", {
  cfg <- list(dependencies = list(python = list(version = c("3.11.0", "3.12.0"))))
  expect_warning(
    out <- validate_config(cfg),
    regexp = "dependencies.python.version"
  )
  expect_null(out$dependencies$python$version)
})

test_that("validate_config accepts valid single-string version values", {
  cfg <- list(dependencies = list(
    r        = list(version = "4.5.1"),
    python   = list(version = "3.12.0"),
    electron = list(version = "latest")
  ))
  expect_no_warning(out <- validate_config(cfg))
  expect_equal(out$dependencies$r$version, "4.5.1")
  expect_equal(out$dependencies$python$version, "3.12.0")
  expect_equal(out$dependencies$electron$version, "latest")
})

# --- validate_config: dependencies system_packages checks ---

test_that("validate_config warns and drops list-shaped system_packages", {
  cfg <- list(dependencies = list(system_packages = list("a", "b")))
  expect_warning(
    out <- validate_config(cfg),
    regexp = "dependencies.system_packages"
  )
  expect_null(out$dependencies$system_packages)
})

test_that("validate_config accepts a character vector for system_packages", {
  cfg <- list(dependencies = list(system_packages = c("libfoo-dev", "libbar-dev")))
  expect_no_warning(out <- validate_config(cfg))
  expect_equal(out$dependencies$system_packages, c("libfoo-dev", "libbar-dev"))
})

# --- validate_config: Windows installer flags ---

test_that("validate_config accepts unset and logical installer flags", {
  expect_no_warning(out <- validate_config(default_config()))
  expect_equal(out$installer, default_config()$installer)

  cfg <- list(installer = list(
    one_click = FALSE,
    allow_to_change_installation_directory = TRUE,
    per_machine = TRUE
  ))
  expect_no_warning(out <- validate_config(cfg))
  expect_equal(out$installer, cfg$installer)
})

test_that("validate_config rejects non-logical installer flags", {
  keys <- c("one_click", "allow_to_change_installation_directory", "per_machine")
  bad_values <- list("true", "false", 1L, NA, c(TRUE, FALSE))
  for (key in keys) {
    for (bad in bad_values) {
      cfg <- list(installer = list(one_click = FALSE))
      cfg$installer[key] <- list(bad)
      expect_error(validate_config(cfg), paste0("installer.", key), fixed = TRUE)
    }
  }
})

test_that("validate_config requires the wizard for a directory page", {
  cfg <- list(installer = list(
    one_click = TRUE,
    allow_to_change_installation_directory = TRUE
  ))
  expect_error(validate_config(cfg), "requires\\s+installer\\.one_click")

  # An unset one_click falls back to electron-builder's one-click default.
  cfg$installer$one_click <- NULL
  expect_error(validate_config(cfg), "requires\\s+installer\\.one_click")
})

test_that("read_config aborts on installer settings electron-builder would reject", {
  tmp <- withr::local_tempdir()
  config_path <- file.path(tmp, "_shinyelectron.yml")

  writeLines(c("installer:", "  allow_to_change_installation_directory: true"),
             config_path)
  expect_error(read_config(tmp), "requires\\s+installer\\.one_click")

  writeLines(c("installer:", "  one_click: \"false\""), config_path)
  expect_error(read_config(tmp), "installer.one_click", fixed = TRUE)

  writeLines(c("installer:", "  one_click: false",
               "  allow_to_change_installation_directory: true"),
             config_path)
  cfg <- read_config(tmp)
  expect_false(cfg$installer$one_click)
  expect_true(cfg$installer$allow_to_change_installation_directory)
})

# --- Windows installer license ---

test_that("resolve_installer_license resolves the path against the app directory", {
  appdir <- withr::local_tempdir()
  writeLines("Terms of use", file.path(appdir, "LICENSE.txt"))

  cfg <- resolve_installer_license(
    list(installer = list(license_file = "LICENSE.txt")), appdir
  )
  expect_equal(cfg$installer$license_file,
               as.character(fs::path_abs(fs::path(appdir, "LICENSE.txt"))))

  # An absolute path is kept as is, and an unset license is left alone.
  again <- resolve_installer_license(cfg, withr::local_tempdir())
  expect_equal(again$installer$license_file, cfg$installer$license_file)
  expect_equal(resolve_installer_license(default_config(), appdir),
               default_config())
})

test_that("resolve_installer_license aborts on a missing or invalid license", {
  appdir <- withr::local_tempdir()
  resolve <- function(license_file) {
    resolve_installer_license(
      list(installer = list(license_file = license_file)), appdir
    )
  }
  expect_error(resolve("LICENSE.txt"), "License file not found")
  expect_error(resolve("."), "License file not found")
  expect_error(resolve(TRUE), "installer.license_file", fixed = TRUE)
  expect_error(resolve(""), "installer.license_file", fixed = TRUE)
})

test_that("export stops on a missing license file before building anything", {
  appdir <- withr::local_tempdir()
  writeLines("library(shiny)", file.path(appdir, "app.R"))
  writeLines(c("installer:", "  license_file: LICENSE.txt"),
             file.path(appdir, "_shinyelectron.yml"))
  destdir <- file.path(withr::local_tempdir(), "out")

  expect_error(
    export(appdir, destdir, build = FALSE, verbose = FALSE),
    "License file not found"
  )
  expect_false(dir.exists(destdir))
})
