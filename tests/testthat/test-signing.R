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

test_that("generate_package_json ad-hoc signs macOS when sign is FALSE", {
  result <- generate_package_json(
    app_slug = "my-app",
    app_version = "1.0.0",
    backend = "shinylive",
    config = list(signing = list(sign = FALSE)),
    sign = FALSE
  )
  parsed <- jsonlite::fromJSON(result, simplifyVector = FALSE)
  # Ad-hoc identity ("-") so Apple Silicon accepts the bundle instead of
  # rejecting an unsealed one as damaged.
  expect_equal(parsed$build$mac$identity, "-")
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
  expect_true(parsed$build$mac$notarize)
})

test_that("generate_package_json notarizes from env credentials when sign is TRUE", {
  withr::local_envvar(
    APPLE_ID = "dev@example.com",
    APPLE_APP_SPECIFIC_PASSWORD = "abcd-efgh-ijkl-mnop",
    APPLE_TEAM_ID = "ENVTEAM123"
  )
  parsed <- jsonlite::fromJSON(
    generate_package_json("my-app", "1.0.0", "shinylive",
      list(signing = list(sign = TRUE)), sign = TRUE),
    simplifyVector = FALSE
  )
  # Notarization is enabled from the environment; the team id and credentials
  # are read from the APPLE_* env vars by electron-builder at build time.
  expect_true(parsed$build$mac$notarize)
})

test_that("generate_package_json skips notarization without credentials", {
  withr::local_envvar(
    APPLE_ID = "", APPLE_APP_SPECIFIC_PASSWORD = "", APPLE_TEAM_ID = ""
  )
  parsed <- jsonlite::fromJSON(
    generate_package_json("my-app", "1.0.0", "shinylive",
      list(signing = list(sign = TRUE)), sign = TRUE),
    simplifyVector = FALSE
  )
  expect_null(parsed$build$mac$notarize)
})

# Keys electron-builder 26 accepts only under win.signtoolOptions. Its schema
# rejects them directly under win, which stops the build on every platform.
signtool_only_keys <- c(
  "sign", "signingHashAlgorithms", "certificateFile", "certificatePassword",
  "certificateSubjectName", "certificateSha1", "additionalCertificateFile",
  "rfc3161TimeStampServer", "timeStampServer", "publisherName"
)

win_build_config <- function(config, sign) {
  result <- generate_package_json("my-app", "1.0.0", "shinylive", config,
                                  has_icon = TRUE, sign = sign)
  jsonlite::fromJSON(result, simplifyVector = FALSE)$build$win
}

test_that("generate_package_json puts the Windows certificate under signtoolOptions", {
  win <- win_build_config(
    list(signing = list(
      sign = TRUE,
      win = list(certificate_file = "certs/signing.pfx")
    )),
    sign = TRUE
  )

  expect_equal(
    win$signtoolOptions,
    list(
      certificateFile = "certs/signing.pfx",
      signingHashAlgorithms = list("sha256")
    )
  )
  # Keys that electron-builder 26 still accepts under win stay there
  expect_equal(win$target, "nsis")
  expect_equal(win$icon, "assets/icon.ico")
})

test_that("generate_package_json writes signtoolOptions only for a signed build with a certificate", {
  cert <- list(certificate_file = "certs/signing.pfx")

  # Unsigned builds ignore the configured certificate
  unsigned <- win_build_config(
    list(signing = list(sign = FALSE, win = cert)),
    sign = FALSE
  )
  expect_null(unsigned$signtoolOptions)

  # Without certificate_file, electron-builder falls back to WIN_CSC_LINK or
  # CSC_LINK, so there is nothing to write
  env_cert <- win_build_config(list(signing = list(sign = TRUE)), sign = TRUE)
  expect_null(env_cert$signtoolOptions)
})

test_that("generate_package_json never writes signtool keys directly under win", {
  cert <- list(certificate_file = "certs/signing.pfx")
  mac <- list(
    identity = "Developer ID Application: Test (TEAMID)",
    team_id = "TEAMID",
    notarize = TRUE
  )

  stray_keys <- function(signing, sign) {
    win <- win_build_config(list(signing = signing), sign)
    intersect(names(win), signtool_only_keys)
  }

  expect_equal(stray_keys(list(sign = FALSE, win = cert), FALSE), character())
  expect_equal(stray_keys(list(sign = TRUE), TRUE), character())
  expect_equal(stray_keys(list(sign = TRUE, win = cert), TRUE), character())
  expect_equal(
    stray_keys(list(sign = TRUE, mac = mac, win = cert), TRUE),
    character()
  )
})

test_that("generate_package_json keeps the certificate password out of package.json", {
  withr::local_envvar(
    CSC_KEY_PASSWORD = "csc-password-sentinel",
    WIN_CSC_KEY_PASSWORD = "win-password-sentinel"
  )
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

  # electron-builder reads the password from these variables at build time
  expect_null(parsed$build$win$signtoolOptions$certificatePassword)
  expect_false(grepl("password-sentinel", result, fixed = TRUE))
})

test_that("signing.win.certificate_file in _shinyelectron.yml reaches signtoolOptions", {
  appdir <- withr::local_tempdir()
  cert <- "/secure/certs/signing.pfx"
  yaml::write_yaml(
    list(signing = list(sign = TRUE, win = list(certificate_file = cert))),
    file.path(appdir, "_shinyelectron.yml")
  )
  config <- read_config(appdir)

  win <- win_build_config(config, sign = isTRUE(config$signing$sign))
  expect_equal(win$signtoolOptions$certificateFile, cert)
  expect_null(win$certificateFile)
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

  # Multiple warnings fire (team_id, notarize creds, identity) -- check for the first
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
    # Also fires identity warning -- suppress it
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
