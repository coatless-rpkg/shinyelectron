# tests/testthat/test-build-steps.R

test_that("dist_has_platform_artifact detects a finished installer", {
  tmp <- withr::local_tempdir()
  dist <- fs::dir_create(fs::path(tmp, "dist"))
  fs::file_create(fs::path(dist, "MyApp-1.0.0-arm64.dmg"))
  expect_true(dist_has_platform_artifact(tmp, "mac"))
})

test_that("dist_has_platform_artifact ignores the unpacked app directory", {
  tmp <- withr::local_tempdir()
  dist <- fs::dir_create(fs::path(tmp, "dist"))
  # electron-builder leaves the unpacked .app under mac-arm64/ even when the
  # installer step (signing, notarization, dmg packaging) failed. That must
  # not read as success, or the collect step publishes nothing.
  fs::dir_create(fs::path(dist, "mac-arm64", "MyApp.app"))
  expect_false(dist_has_platform_artifact(tmp, "mac"))
})

test_that("dist_has_platform_artifact returns FALSE when dist is absent", {
  tmp <- withr::local_tempdir()
  expect_false(dist_has_platform_artifact(tmp, "mac"))
})

# --- electron_builder_env() and build_for_platforms() ---

team_id_config <- function(team_id = "TEAM123456") {
  list(signing = list(sign = TRUE, mac = list(team_id = team_id)))
}

test_that("electron_builder_env passes signing.mac.team_id as APPLE_TEAM_ID", {
  withr::local_envvar(APPLE_TEAM_ID = NA)
  local_mocked_bindings(nodejs_subprocess_env = function() NULL)
  expect_equal(electron_builder_env(team_id_config(), sign = TRUE),
               c("current", APPLE_TEAM_ID = "TEAM123456"))

  # The PATH entry that finds a managed Node.js stays
  local_mocked_bindings(
    nodejs_subprocess_env = function() c("current", PATH = "/node/bin")
  )
  expect_equal(electron_builder_env(team_id_config(), sign = TRUE),
               c("current", PATH = "/node/bin", APPLE_TEAM_ID = "TEAM123456"))
})

test_that("electron_builder_env leaves a set APPLE_TEAM_ID alone", {
  withr::local_envvar(APPLE_TEAM_ID = "ENVTEAM123")
  local_mocked_bindings(nodejs_subprocess_env = function() NULL)
  expect_null(electron_builder_env(team_id_config(), sign = TRUE))
})

test_that("electron_builder_env fills in an empty APPLE_TEAM_ID", {
  # Windows cannot hold an empty environment variable: Sys.setenv(X = "")
  # unsets it there
  skip_on_os("windows")
  # electron-builder treats an empty APPLE_TEAM_ID as unset
  withr::local_envvar(APPLE_TEAM_ID = "")
  local_mocked_bindings(nodejs_subprocess_env = function() NULL)
  expect_equal(electron_builder_env(team_id_config(), sign = TRUE),
               c("current", APPLE_TEAM_ID = "TEAM123456"))
})

test_that("electron_builder_env adds nothing to unsigned builds or without a team ID", {
  withr::local_envvar(APPLE_TEAM_ID = NA)
  local_mocked_bindings(nodejs_subprocess_env = function() NULL)
  expect_null(electron_builder_env(team_id_config(), sign = FALSE))
  expect_null(electron_builder_env(list(signing = list(sign = TRUE)), sign = TRUE))
  expect_null(electron_builder_env(team_id_config(""), sign = TRUE))
  expect_null(electron_builder_env(NULL, sign = TRUE))
})

test_that("build_for_platforms runs every electron-builder attempt with the team ID", {
  out <- withr::local_tempdir()
  writeLines(
    generate_package_json("my-app", "1.0.0", "shinylive", team_id_config(),
                          sign = TRUE),
    fs::path(out, "package.json")
  )
  withr::local_envvar(APPLE_TEAM_ID = NA)
  local_mocked_bindings(nodejs_subprocess_env = function() NULL)
  # A failed build that leaves no installer, so the platform-only fallback
  # runs too
  run_rec <- mockery::mock(list(status = 1L, stdout = "", stderr = ""),
                           cycle = TRUE)
  local_mocked_bindings(run = run_rec, .package = "processx")

  suppressMessages(
    build_for_platforms(out, "mac", "arm64", sign = TRUE,
                        config = team_id_config(), verbose = FALSE)
  )

  mockery::expect_called(run_rec, 2)
  calls <- mockery::mock_args(run_rec)
  expect_equal(calls[[1]]$args, c("run", "build-mac-arm64"))
  expect_equal(calls[[2]]$args, c("run", "build-mac"))
  for (call in calls) {
    expect_equal(call$env, c("current", APPLE_TEAM_ID = "TEAM123456"))
  }
})
