# tests/testthat/test-wizard.R
#
# Tests for wizard(). All interactive prompts are stubbed so the suite
# runs without user input. validate_config_file is stubbed wherever the
# happy path reaches it to avoid network/filesystem side effects from the
# config validator.

# ---------------------------------------------------------------------------
# Helper: build a readline stub that plays back a sequence of responses.
# After the sequence is exhausted every call returns "" (accept default).
# ---------------------------------------------------------------------------

make_readline_responder <- function(responses) {
  idx <- 0L
  function(...) {
    idx <<- idx + 1L
    if (idx <= length(responses)) responses[[idx]] else ""
  }
}

# ---------------------------------------------------------------------------
# Non-interactive guard
# ---------------------------------------------------------------------------

test_that("wizard aborts when called non-interactively", {
  mockery::stub(wizard, "interactive", function() FALSE)
  expect_error(wizard(), "must be run interactively")
})

# ---------------------------------------------------------------------------
# Platform validation (abort path)
# ---------------------------------------------------------------------------

test_that("wizard aborts for an invalid platform token", {
  # Sequence: name, version, language, strategy, bad platform
  mockery::stub(wizard, "interactive", function() TRUE)
  mockery::stub(wizard, "readline",
                make_readline_responder(c("", "", "1", "1", "badplatform")))

  tmp <- withr::local_tempdir()
  expect_error(
    capture.output(suppressMessages(wizard(tmp)), type = "output"),
    "Invalid platform"
  )
})

test_that("wizard error for invalid platform names valid tokens", {
  mockery::stub(wizard, "interactive", function() TRUE)
  mockery::stub(wizard, "readline",
                make_readline_responder(c("", "", "1", "1", "notaplaform")))

  tmp <- withr::local_tempdir()
  expect_error(
    capture.output(suppressMessages(wizard(tmp)), type = "output"),
    "win|mac|linux"
  )
})

# ---------------------------------------------------------------------------
# Helper: run wizard silently, capturing all cat/cli output
# ---------------------------------------------------------------------------

run_wizard_quiet <- function(appdir, responses, ...) {
  mockery::stub(wizard, "interactive", function() TRUE)
  mockery::stub(wizard, "readline", make_readline_responder(responses))
  mockery::stub(wizard, "validate_config_file", function(...) invisible(TRUE))
  capture.output(suppressMessages(wizard(appdir, ...)), type = "output")
  invisible(NULL)
}

# ---------------------------------------------------------------------------
# Happy path: all defaults
# ---------------------------------------------------------------------------

test_that("wizard returns path to _shinyelectron.yml with all defaults", {
  # Sequence: name, version, language, strategy, platform,
  #           width, height, port, advanced -> 9 empty responses
  mockery::stub(wizard, "interactive", function() TRUE)
  mockery::stub(wizard, "readline", make_readline_responder(rep("", 9L)))
  mockery::stub(wizard, "validate_config_file", function(...) invisible(TRUE))

  tmp <- withr::local_tempdir()
  path_out <- NULL
  capture.output(suppressMessages({ path_out <- wizard(tmp) }), type = "output")

  expect_type(path_out, "character")
  expect_match(path_out, "_shinyelectron\\.yml$")
})

test_that("wizard creates _shinyelectron.yml on disk", {
  tmp <- withr::local_tempdir()
  run_wizard_quiet(tmp, rep("", 9L))
  expect_true(file.exists(file.path(tmp, "_shinyelectron.yml")))
})

test_that("wizard config file is valid YAML with expected keys", {
  tmp <- withr::local_tempdir()
  run_wizard_quiet(tmp, rep("", 9L))

  config <- yaml::read_yaml(file.path(tmp, "_shinyelectron.yml"))
  expect_true(all(c("app", "build", "window", "server") %in% names(config)))
})

test_that("wizard default config has r-shiny type and shinylive strategy", {
  tmp <- withr::local_tempdir()
  run_wizard_quiet(tmp, rep("", 9L))

  config <- yaml::read_yaml(file.path(tmp, "_shinyelectron.yml"))
  expect_equal(config$build$type, "r-shiny")
  expect_equal(config$build$runtime_strategy, "shinylive")
})

test_that("wizard default config targets mac platform", {
  tmp <- withr::local_tempdir()
  run_wizard_quiet(tmp, rep("", 9L))

  config <- yaml::read_yaml(file.path(tmp, "_shinyelectron.yml"))
  # yaml::read_yaml returns a single-element character vector, not a list
  expect_true("mac" %in% unlist(config$build$platforms))
})

test_that("wizard default config window dimensions and port match constants", {
  tmp <- withr::local_tempdir()
  run_wizard_quiet(tmp, rep("", 9L))

  config <- yaml::read_yaml(file.path(tmp, "_shinyelectron.yml"))
  expect_equal(config$window$width, 1200L)
  expect_equal(config$window$height, 800L)
  expect_equal(config$server$port, 3838L)
})

test_that("wizard uses basename of appdir as default app name", {
  tmp <- withr::local_tempdir()
  run_wizard_quiet(tmp, rep("", 9L))

  config <- yaml::read_yaml(file.path(tmp, "_shinyelectron.yml"))
  expect_equal(config$app$name, basename(tmp))
})

# ---------------------------------------------------------------------------
# Language / strategy choices
# ---------------------------------------------------------------------------

test_that("wizard selects py-shiny when user enters 2 for language", {
  # name, version, language=2, strategy=1 (shinylive), platform, rest defaults
  tmp <- withr::local_tempdir()
  run_wizard_quiet(tmp, c("", "", "2", "1", "", "", "", "", ""))

  config <- yaml::read_yaml(file.path(tmp, "_shinyelectron.yml"))
  expect_equal(config$build$type, "py-shiny")
})

test_that("wizard selects system runtime when user enters 3 for strategy", {
  # name, version, language=1 (r-shiny), strategy=3 (system), platform, rest defaults
  tmp <- withr::local_tempdir()
  run_wizard_quiet(tmp, c("", "", "1", "3", "", "", "", "", ""))

  config <- yaml::read_yaml(file.path(tmp, "_shinyelectron.yml"))
  expect_equal(config$build$runtime_strategy, "system")
})

# ---------------------------------------------------------------------------
# Existing config: abort on no-overwrite
# ---------------------------------------------------------------------------

test_that("wizard returns NULL invisibly when user declines overwrite", {
  tmp <- withr::local_tempdir()
  writeLines("app:\n  name: existing", file.path(tmp, "_shinyelectron.yml"))

  # Sequence runs all the way to the overwrite prompt, then says "N"
  mockery::stub(wizard, "interactive", function() TRUE)
  mockery::stub(wizard, "readline", make_readline_responder(c("", "", "1", "1", "", "", "", "", "", "N")))

  result <- NULL
  capture.output(suppressMessages({ result <- wizard(tmp) }), type = "output")
  expect_null(result)
})

# ---------------------------------------------------------------------------
# Multiple platform tokens
# ---------------------------------------------------------------------------

test_that("wizard accepts multiple valid platform tokens", {
  tmp <- withr::local_tempdir()
  run_wizard_quiet(tmp, c("", "", "1", "1", "mac,win", "", "", "", ""))

  config <- yaml::read_yaml(file.path(tmp, "_shinyelectron.yml"))
  expect_true("mac" %in% unlist(config$build$platforms))
  expect_true("win" %in% unlist(config$build$platforms))
})

# ---------------------------------------------------------------------------
# Advanced path: auto-updates with github provider
# ---------------------------------------------------------------------------

test_that("wizard advanced path records github as the update provider", {
  # Prompt order:
  #   1  name           -> "" (default)
  #   2  version        -> "" (default)
  #   3  language       -> "" (default: r-shiny)
  #   4  strategy       -> "" (default: shinylive)
  #   5  platforms      -> "" (default: mac)
  #   6  width          -> "" (default)
  #   7  height         -> "" (default)
  #   8  port           -> "" (default)
  #   9  advanced?      -> "y"
  #  10  sign?          -> "" (no)
  #  11  tray?          -> "" (no)
  #  12  updates?       -> "y"
  #  13  GitHub owner   -> "myowner"
  #  14  GitHub repo    -> "myrepo"
  # (deps block skipped because runtime_strategy == "shinylive")
  tmp <- withr::local_tempdir()
  run_wizard_quiet(tmp, c("", "", "", "", "", "", "", "",
                           "y", "", "", "y", "myowner", "myrepo"))

  config <- yaml::read_yaml(file.path(tmp, "_shinyelectron.yml"))
  expect_equal(config$updates$provider, "github")
  expect_true(isTRUE(config$updates$enabled))
})
