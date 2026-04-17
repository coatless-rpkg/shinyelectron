# tests/testthat/test-signing.R

test_that("SHINYELECTRON_DEFAULTS contains signing defaults", {
  expect_true("signing" %in% names(SHINYELECTRON_DEFAULTS))
  expect_false(SHINYELECTRON_DEFAULTS$signing$sign)
  expect_null(SHINYELECTRON_DEFAULTS$signing$mac$identity)
  expect_null(SHINYELECTRON_DEFAULTS$signing$mac$team_id)
  expect_false(SHINYELECTRON_DEFAULTS$signing$mac$notarize)
  expect_null(SHINYELECTRON_DEFAULTS$signing$win$certificate_file)
  expect_false(SHINYELECTRON_DEFAULTS$signing$linux$gpg_sign)
})

test_that("default_config includes signing section", {
  cfg <- default_config()
  expect_true("signing" %in% names(cfg))
  expect_false(cfg$signing$sign)
})

test_that("generate_package_json sets identity null when sign is FALSE", {
  result <- generate_package_json(
    app_slug = "my-app",
    app_version = "1.0.0",
    backend = "shinylive",
    config = list(signing = list(sign = FALSE)),
    sign = FALSE
  )
  parsed <- jsonlite::fromJSON(result, simplifyVector = FALSE)
  expect_null(parsed$build$mac$identity)
})

test_that("generate_package_json includes signing identity when sign is TRUE", {
  result <- generate_package_json(
    app_slug = "my-app",
    app_version = "1.0.0",
    backend = "shinylive",
    config = list(signing = list(
      sign = TRUE,
      mac = list(
        identity = "Developer ID Application: Test (TEAMID)",
        team_id = "TEAMID",
        notarize = TRUE
      )
    )),
    sign = TRUE
  )
  parsed <- jsonlite::fromJSON(result, simplifyVector = FALSE)
  expect_equal(parsed$build$mac$identity, "Developer ID Application: Test (TEAMID)")
  expect_equal(parsed$build$mac$notarize$teamId, "TEAMID")
})

test_that("generate_package_json includes Windows cert when sign is TRUE", {
  result <- generate_package_json(
    app_slug = "my-app",
    app_version = "1.0.0",
    backend = "shinylive",
    config = list(signing = list(
      sign = TRUE,
      win = list(certificate_file = "certs/signing.pfx")
    )),
    sign = TRUE
  )
  parsed <- jsonlite::fromJSON(result, simplifyVector = FALSE)
  expect_equal(parsed$build$win$certificateFile, "certs/signing.pfx")
})

test_that("generate_package_json omits notarize when notarize is FALSE", {
  result <- generate_package_json(
    app_slug = "my-app",
    app_version = "1.0.0",
    backend = "shinylive",
    config = list(signing = list(
      sign = TRUE,
      mac = list(identity = "Dev ID", notarize = FALSE)
    )),
    sign = TRUE
  )
  parsed <- jsonlite::fromJSON(result, simplifyVector = FALSE)
  expect_null(parsed$build$mac$notarize)
})

# --- validate_signing_config tests ---

test_that("validate_signing_config warns about missing macOS team_id", {
  config <- list(signing = list(
    sign = TRUE,
    mac = list(identity = NULL, team_id = NULL, notarize = TRUE)
  ))

  # Multiple warnings fire (team_id, notarize creds, identity) — check for the first
  suppressWarnings(
    expect_warning(
      validate_signing_config(config, platform = "mac"),
      "APPLE_TEAM_ID"
    )
  )
})

test_that("validate_signing_config warns about missing notarization credentials", {
  config <- list(signing = list(
    sign = TRUE,
    mac = list(notarize = TRUE, team_id = "TEAM123")
  ))

  withr::with_envvar(c(APPLE_ID = NA, APPLE_APP_SPECIFIC_PASSWORD = NA), {
    # Also fires identity warning — suppress it
    suppressWarnings(
      expect_warning(
        validate_signing_config(config, platform = "mac"),
        "APPLE_ID"
      )
    )
  })
})

test_that("validate_signing_config warns about missing Windows cert", {
  config <- list(signing = list(
    sign = TRUE,
    win = list(certificate_file = NULL)
  ))

  withr::with_envvar(c(CSC_LINK = NA), {
    expect_warning(
      validate_signing_config(config, platform = "win"),
      "CSC_LINK"
    )
  })
})

test_that("validate_signing_config is silent when sign is FALSE", {
  config <- list(signing = list(sign = FALSE))
  expect_silent(validate_signing_config(config, platform = "mac"))
})

test_that("validate_signing_config is silent with complete macOS config", {
  config <- list(signing = list(
    sign = TRUE,
    mac = list(
      identity = "Developer ID Application: Test",
      team_id = "TEAM123",
      notarize = TRUE
    )
  ))

  withr::with_envvar(c(APPLE_ID = "test@example.com",
                       APPLE_APP_SPECIFIC_PASSWORD = "xxxx"), {
    expect_silent(validate_signing_config(config, platform = "mac"))
  })
})
