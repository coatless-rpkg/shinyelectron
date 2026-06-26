# tests/testthat/test-install-nodejs.R

# --- nodejs_download_url ---

test_that("nodejs_download_url returns correct URL for Windows x64", {
  url <- nodejs_download_url("22.0.0", "win", "x64")
  expect_match(url, "22\\.0\\.0")
  expect_match(url, "win")
  expect_match(url, "x64")
  expect_match(url, "\\.zip$")
  expect_match(url, "^https://nodejs\\.org/dist/")
})

test_that("nodejs_download_url returns correct URL for macOS x64", {
  url <- nodejs_download_url("22.0.0", "mac", "x64")
  expect_match(url, "22\\.0\\.0")
  expect_match(url, "darwin")
  expect_match(url, "x64")
  expect_match(url, "\\.tar\\.gz$")
  expect_match(url, "^https://nodejs\\.org/dist/")
})

test_that("nodejs_download_url returns correct URL for macOS arm64", {
  url <- nodejs_download_url("22.0.0", "mac", "arm64")
  expect_match(url, "darwin")
  expect_match(url, "arm64")
  expect_match(url, "\\.tar\\.gz$")
})

test_that("nodejs_download_url returns correct URL for Linux x64", {
  url <- nodejs_download_url("22.0.0", "linux", "x64")
  expect_match(url, "22\\.0\\.0")
  expect_match(url, "linux")
  expect_match(url, "x64")
  expect_match(url, "\\.tar\\.gz$")
})

test_that("nodejs_download_url returns correct URL for Linux arm64", {
  url <- nodejs_download_url("20.11.0", "linux", "arm64")
  expect_match(url, "linux")
  expect_match(url, "arm64")
  expect_match(url, "\\.tar\\.gz$")
})

test_that("nodejs_download_url errors for unsupported platform", {
  expect_error(nodejs_download_url("22.0.0", "freebsd", "x64"), "Unsupported platform")
})

# --- nodejs_install_path ---

test_that("nodejs_install_path returns path containing version and platform dirs", {
  path <- nodejs_install_path("22.0.0", "mac", "arm64")
  expect_match(path, "22\\.0\\.0")
  expect_match(path, "darwin")
  expect_match(path, "arm64")
})

test_that("nodejs_install_path maps mac to darwin in directory name", {
  path <- nodejs_install_path("22.0.0", "mac", "arm64")
  expect_match(path, "darwin-arm64")
})

test_that("nodejs_install_path includes nodejs segment", {
  path <- nodejs_install_path("22.0.0", "mac", "x64")
  expect_match(path, "nodejs")
})

test_that("nodejs_install_path returns base path when version is NULL", {
  path <- nodejs_install_path()
  expect_match(path, "nodejs")
})

# --- nodejs_is_installed ---

test_that("nodejs_is_installed returns FALSE for non-existent version", {
  expect_false(nodejs_is_installed("99.99.99"))
})

# --- nodejs_executable ---

test_that("nodejs_executable returns correct path structure for mac", {
  mockery::stub(nodejs_executable, "detect_current_platform", function() "mac")
  mockery::stub(nodejs_executable, "detect_current_arch", function() "arm64")
  mockery::stub(nodejs_executable, "fs::file_exists", function(path) TRUE)

  result <- nodejs_executable("22.0.0", "mac", "arm64")
  expect_match(result, "bin")
  expect_match(result, "node")
  expect_false(grepl("\\.exe", result))
})

test_that("nodejs_executable returns correct path structure for win", {
  mockery::stub(nodejs_executable, "detect_current_platform", function() "win")
  mockery::stub(nodejs_executable, "detect_current_arch", function() "x64")
  mockery::stub(nodejs_executable, "fs::file_exists", function(path) TRUE)

  result <- nodejs_executable("22.0.0", "win", "x64")
  expect_match(result, "node\\.exe")
})

test_that("nodejs_executable returns NULL when executable not present", {
  mockery::stub(nodejs_executable, "detect_current_platform", function() "mac")
  mockery::stub(nodejs_executable, "detect_current_arch", function() "arm64")
  mockery::stub(nodejs_executable, "fs::file_exists", function(path) FALSE)

  result <- nodejs_executable("22.0.0", "mac", "arm64")
  expect_null(result)
})

# --- nodejs_verify_checksum ---

test_that("nodejs_verify_checksum returns TRUE when expected_checksum is NA", {
  expect_true(nodejs_verify_checksum("/any/path", NA_character_))
})

test_that("nodejs_verify_checksum returns TRUE when expected_checksum is empty string", {
  expect_true(nodejs_verify_checksum("/any/path", ""))
})

test_that("nodejs_verify_checksum returns FALSE on mismatch", {
  tmp_file <- withr::local_tempfile()
  writeLines("test content for checksum mismatch", tmp_file)
  bad_hash <- paste(rep("0", 64), collapse = "")
  expect_false(nodejs_verify_checksum(tmp_file, bad_hash))
})

test_that("nodejs_verify_checksum returns TRUE on correct hash", {
  tmp_file <- withr::local_tempfile()
  writeLines("test content for checksum match", tmp_file)
  actual_hash <- unname(tools::sha256sum(tmp_file))
  expect_true(nodejs_verify_checksum(tmp_file, actual_hash))
})

test_that("nodejs_verify_checksum is case-insensitive", {
  tmp_file <- withr::local_tempfile()
  writeLines("case insensitive check", tmp_file)
  actual_hash <- unname(tools::sha256sum(tmp_file))
  expect_true(nodejs_verify_checksum(tmp_file, toupper(actual_hash)))
})

# --- nodejs_download_checksums: warns and returns empty on fetch failure ---

test_that("nodejs_download_checksums warns and returns empty vector when fetch fails", {
  mockery::stub(nodejs_download_checksums, "readLines",
                function(...) stop("connection refused"))

  expect_warning(
    result <- nodejs_download_checksums("22.0.0"),
    "Failed to download checksums"
  )
  expect_equal(result, character(0))
})

# --- install_nodejs: already-installed early return ---

test_that("install_nodejs returns early when already installed and force = FALSE", {
  tmp <- withr::local_tempdir()
  install_dir <- file.path(tmp, "nodejs", "v22.0.0", "darwin-arm64")
  dir.create(install_dir, recursive = TRUE)

  mockery::stub(install_nodejs, "nodejs_install_path",
                function(v, p, a) file.path(tmp, "nodejs", paste0("v", v), "darwin-arm64"))
  # Prove no download is attempted: any download call causes the test to fail.
  mockery::stub(install_nodejs, "utils::download.file",
                function(...) stop("download must not be called when already installed"))

  result <- install_nodejs(
    version  = "22.0.0",
    platform = "mac",
    arch     = "arm64",
    force    = FALSE,
    verbose  = FALSE
  )

  expect_equal(as.character(result), install_dir)
})

# --- install_nodejs: checksum mismatch aborts ---

test_that("install_nodejs aborts when checksum does not match downloaded file", {
  tmp <- withr::local_tempdir()

  mockery::stub(install_nodejs, "nodejs_install_path",
                function(v, p, a) file.path(tmp, "nodejs", paste0("v", v), "darwin-arm64"))
  mockery::stub(install_nodejs, "utils::download.file",
                function(url, dest, ...) writeLines("fake archive content", dest))
  # The expected checksum is all-zeros: it will never match the written file.
  mockery::stub(install_nodejs, "nodejs_download_checksums", function(v) {
    c("node-v22.0.0-darwin-arm64.tar.gz" =
        paste(rep("0", 64), collapse = ""))
  })

  expect_error(
    install_nodejs(
      version  = "22.0.0",
      platform = "mac",
      arch     = "arm64",
      verbose  = FALSE
    ),
    "Checksum verification failed"
  )
})

# --- install_nodejs: missing checksums skips verification and continues ---

test_that("install_nodejs continues when checksums cannot be fetched", {
  tmp <- withr::local_tempdir()

  mockery::stub(install_nodejs, "nodejs_install_path",
                function(v, p, a) file.path(tmp, "nodejs", paste0("v", v), "darwin-arm64"))
  mockery::stub(install_nodejs, "utils::download.file",
                function(url, dest, ...) invisible(file.create(dest)))
  # Returning character(0) mirrors the behavior of nodejs_download_checksums()
  # when the remote fetch fails after emitting a warning.
  mockery::stub(install_nodejs, "nodejs_download_checksums",
                function(v) character(0))
  # Create the expected directory structure with the node binary in staging so
  # the binary-presence check passes and the atomic swap completes.
  mockery::stub(install_nodejs, "utils::untar", function(tarfile, exdir, ...) {
    node_dir <- file.path(exdir, "node-v22.0.0-darwin-arm64")
    dir.create(file.path(node_dir, "bin"), recursive = TRUE)
    file.create(file.path(node_dir, "bin", "node"))
    invisible(NULL)
  })

  result <- install_nodejs(
    version  = "22.0.0",
    platform = "mac",
    arch     = "arm64",
    verbose  = FALSE
  )

  expect_true(dir.exists(as.character(result)))
})
