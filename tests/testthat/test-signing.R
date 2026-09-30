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

# Unset every variable electron-builder reads for notarization, then set the
# given ones, so the checks do not depend on the machine's environment.
local_notarization_env <- function(..., .local_envir = parent.frame()) {
  vars <- c("APPLE_ID", "APPLE_APP_SPECIFIC_PASSWORD", "APPLE_TEAM_ID",
            "APPLE_API_KEY", "APPLE_API_KEY_ID", "APPLE_API_ISSUER",
            "APPLE_KEYCHAIN", "APPLE_KEYCHAIN_PROFILE")
  unset <- as.list(stats::setNames(rep(NA_character_, length(vars)), vars))
  withr::local_envvar(utils::modifyList(unset, list(...)),
                      .local_envir = .local_envir)
}

# A signed macOS config with an identity, so only notarization can warn.
mac_signing_config <- function(...) {
  list(signing = list(
    sign = TRUE,
    mac = list(identity = "Developer ID Application: Test", ...)
  ))
}

test_that("validate_signing_config warns that an Apple ID without a team ID fails notarization", {
  local_notarization_env(APPLE_ID = "dev@example.com",
                         APPLE_APP_SPECIFIC_PASSWORD = "not-a-password")

  w <- expect_warning(
    validate_signing_config(mac_signing_config(), platform = "mac"),
    "no Apple team ID, so notarization will fail"
  )
  expect_match(conditionMessage(w), "signing.mac.team_id", fixed = TRUE)
  expect_match(conditionMessage(w), "APPLE_TEAM_ID", fixed = TRUE)
})

test_that("validate_signing_config takes the team ID from the config or APPLE_TEAM_ID", {
  local_notarization_env(APPLE_ID = "dev@example.com",
                         APPLE_APP_SPECIFIC_PASSWORD = "not-a-password")
  expect_silent(validate_signing_config(
    mac_signing_config(team_id = "TEAM123456"), platform = "mac"
  ))

  withr::local_envvar(APPLE_TEAM_ID = "ENVTEAM123")
  expect_silent(validate_signing_config(mac_signing_config(), platform = "mac"))
})

test_that("validate_signing_config names a missing Apple ID credential", {
  local_notarization_env(APPLE_ID = "dev@example.com",
                         APPLE_TEAM_ID = "ENVTEAM123")

  expect_warning(
    validate_signing_config(mac_signing_config(), platform = "mac"),
    "APPLE_APP_SPECIFIC_PASSWORD`? is not set, so notarization"
  )
})

test_that("validate_signing_config accepts an API key or keychain profile without a team ID", {
  local_notarization_env(APPLE_API_KEY = "/keys/AuthKey_KEYID12345.p8",
                         APPLE_API_KEY_ID = "KEYID12345",
                         APPLE_API_ISSUER = "issuer-id")
  expect_silent(validate_signing_config(mac_signing_config(), platform = "mac"))

  local_notarization_env(APPLE_KEYCHAIN_PROFILE = "notary-profile")
  expect_silent(validate_signing_config(mac_signing_config(), platform = "mac"))
})

test_that("validate_signing_config names missing API key variables", {
  local_notarization_env(APPLE_API_KEY = "/keys/AuthKey_KEYID12345.p8")

  expect_warning(
    validate_signing_config(mac_signing_config(), platform = "mac"),
    "APPLE_API_KEY_ID`? and `?APPLE_API_ISSUER`? are not set, so notarization"
  )
})

test_that("validate_signing_config warns that notarization is skipped without credentials", {
  local_notarization_env()

  w <- expect_warning(
    validate_signing_config(
      mac_signing_config(team_id = "TEAM123456", notarize = TRUE),
      platform = "mac"
    ),
    "no notarization credentials, so notarization will be skipped"
  )
  expect_match(conditionMessage(w), "APPLE_ID", fixed = TRUE)
  expect_match(conditionMessage(w), "APPLE_API_KEY", fixed = TRUE)
})

test_that("validate_signing_config follows its sign argument over signing.sign", {
  local_notarization_env()

  # export(sign = TRUE) signs even when the config leaves signing.sign off
  config <- list(signing = list(
    mac = list(identity = "Developer ID Application: Test")
  ))
  expect_warning(
    validate_signing_config(config, platform = "mac", sign = TRUE),
    "no notarization credentials"
  )
  expect_silent(
    validate_signing_config(mac_signing_config(), platform = "mac", sign = FALSE)
  )
})

test_that("validate_signing_config warns about missing Windows cert", {
  config <- list(signing = list(
    sign = TRUE,
    win = list(certificate_file = NULL)
  ))

  withr::with_envvar(c(CSC_LINK = NA, WIN_CSC_LINK = NA), {
    w <- expect_warning(
      validate_signing_config(config, platform = "win"),
      "unsigned"
    )
  })
  expect_match(conditionMessage(w), "WIN_CSC_LINK")
  expect_match(conditionMessage(w), "(^|[^_])CSC_LINK")
  expect_match(conditionMessage(w), "certificate_file")
})

test_that("validate_signing_config accepts WIN_CSC_LINK or CSC_LINK for Windows", {
  config <- list(signing = list(sign = TRUE))

  withr::local_envvar(
    WIN_CSC_LINK = "/ci/win.pfx", WIN_CSC_KEY_PASSWORD = "secret",
    CSC_LINK = NA, CSC_KEY_PASSWORD = NA
  )
  expect_silent(validate_signing_config(config, platform = "win"))

  withr::local_envvar(
    WIN_CSC_LINK = NA, WIN_CSC_KEY_PASSWORD = NA,
    CSC_LINK = "/ci/win.pfx", CSC_KEY_PASSWORD = "secret"
  )
  expect_silent(validate_signing_config(config, platform = "win"))

  # electron-builder falls back to CSC_KEY_PASSWORD for a WIN_CSC_LINK cert
  withr::local_envvar(
    WIN_CSC_LINK = "/ci/win.pfx", WIN_CSC_KEY_PASSWORD = NA,
    CSC_LINK = NA, CSC_KEY_PASSWORD = "secret"
  )
  expect_silent(validate_signing_config(config, platform = "win"))
})

test_that("validate_signing_config reads the certificate_file password from either variable", {
  config <- list(signing = list(
    sign = TRUE,
    win = list(certificate_file = "certs/signing.pfx")
  ))
  withr::local_envvar(WIN_CSC_LINK = NA, CSC_LINK = NA)

  withr::local_envvar(WIN_CSC_KEY_PASSWORD = "secret", CSC_KEY_PASSWORD = NA)
  expect_silent(validate_signing_config(config, platform = "win"))

  withr::local_envvar(WIN_CSC_KEY_PASSWORD = NA, CSC_KEY_PASSWORD = "secret")
  expect_silent(validate_signing_config(config, platform = "win"))

  withr::local_envvar(WIN_CSC_KEY_PASSWORD = NA, CSC_KEY_PASSWORD = NA)
  w <- expect_warning(
    validate_signing_config(config, platform = "win"),
    "signing may fail"
  )
  expect_match(conditionMessage(w), "WIN_CSC_KEY_PASSWORD")
  expect_match(conditionMessage(w), "(^|[^_])CSC_KEY_PASSWORD")
})

test_that("validate_signing_config stops at an empty Windows variable like electron-builder", {
  # Windows cannot hold an empty environment variable: Sys.setenv(X = "")
  # unsets it there
  skip_on_os("windows")
  config <- list(signing = list(sign = TRUE))

  # An empty WIN_CSC_LINK hides CSC_LINK, so the build is unsigned
  withr::local_envvar(
    WIN_CSC_LINK = "", CSC_LINK = "/ci/win.pfx",
    WIN_CSC_KEY_PASSWORD = NA, CSC_KEY_PASSWORD = "secret"
  )
  w <- expect_warning(
    validate_signing_config(config, platform = "win"),
    "set but empty"
  )
  expect_match(conditionMessage(w), "WIN_CSC_LINK")

  # An empty WIN_CSC_KEY_PASSWORD hides CSC_KEY_PASSWORD
  withr::local_envvar(WIN_CSC_LINK = "/ci/win.pfx", WIN_CSC_KEY_PASSWORD = "")
  w <- expect_warning(
    validate_signing_config(config, platform = "win"),
    "set but empty"
  )
  expect_match(conditionMessage(w), "WIN_CSC_KEY_PASSWORD")
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

  local_notarization_env(APPLE_ID = "test@example.com",
                         APPLE_APP_SPECIFIC_PASSWORD = "xxxx")
  expect_silent(validate_signing_config(config, platform = "mac"))
})

# --- signing through export() and app_check() ---

local_signing_app <- function(config = NULL, env = parent.frame()) {
  appdir <- withr::local_tempdir(.local_envir = env)
  writeLines("library(shiny)\nshinyApp(fluidPage(), function(input, output) {})",
             fs::path(appdir, "app.R"))
  if (!is.null(config)) {
    yaml::write_yaml(config, fs::path(appdir, "_shinyelectron.yml"))
  }
  appdir
}

# Run export() without shinylive, npm or electron-builder. build_for_platforms()
# still runs; a recorder stands in for processx::run(), so the test sees the
# environment electron-builder would get.
local_recorded_build <- function(env = parent.frame()) {
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
    nodejs_subprocess_env = function() NULL,
    validate_build_output = function(...) invisible(NULL),
    .env = env
  )
  run_rec <- mockery::mock(list(status = 0L, stdout = "", stderr = ""),
                           cycle = TRUE)
  local_mocked_bindings(run = run_rec, .package = "processx", .env = env)
  run_rec
}

test_that("export() passes signing.mac.team_id to electron-builder as APPLE_TEAM_ID", {
  appdir <- local_signing_app(mac_signing_config(team_id = "TEAM123456"))
  local_notarization_env(APPLE_ID = "dev@example.com",
                         APPLE_APP_SPECIFIC_PASSWORD = "not-a-password")
  run_rec <- local_recorded_build()

  export(appdir, fs::path(withr::local_tempdir(), "out"),
         platform = "mac", arch = "arm64", verbose = FALSE)

  # electron-builder 26 reads the notarization team ID only from APPLE_TEAM_ID
  mockery::expect_called(run_rec, 1)
  env <- mockery::mock_args(run_rec)[[1]]$env
  expect_equal(env[names(env) == "APPLE_TEAM_ID"],
               c(APPLE_TEAM_ID = "TEAM123456"))
})

test_that("export(sign = TRUE) checks credentials without signing.sign in the config", {
  appdir <- local_signing_app(list(signing = list(
    mac = list(identity = "Developer ID Application: Test")
  )))
  local_notarization_env()
  local_recorded_build()

  expect_no_warning(
    export(appdir, fs::path(withr::local_tempdir(), "out"),
           platform = "mac", arch = "arm64", verbose = FALSE)
  )
  expect_warning(
    export(appdir, fs::path(withr::local_tempdir(), "out"),
           platform = "mac", arch = "arm64", sign = TRUE, verbose = FALSE),
    "no notarization credentials"
  )
})

test_that("app_check(sign = TRUE) checks credentials without signing.sign in the config", {
  appdir <- local_signing_app(list(signing = list(
    mac = list(identity = "Developer ID Application: Test")
  )))
  local_notarization_env()

  expect_no_warning(app_check(appdir, platform = "mac", verbose = FALSE))
  expect_warning(
    app_check(appdir, platform = "mac", sign = TRUE, verbose = FALSE),
    "no notarization credentials"
  )
})
