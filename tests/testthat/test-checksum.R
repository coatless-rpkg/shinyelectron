# Runtime download integrity: SHA-256 fetch + verification wiring.
# All network access is mocked so these run under R CMD check.

test_that("fetch_published_sha256 reads a per-asset sidecar", {
  skip_if_not_installed("mockery")
  h <- strrep("a", 64)
  mockery::stub(fetch_published_sha256, "readLines",
                function(...) paste0(h, "  portable-r-4.6.1-macos-arm64.tar.gz"))
  expect_equal(fetch_published_sha256("https://example/x.tar.gz.sha256"), h)
})

test_that("fetch_published_sha256 matches a filename within SHA256SUMS", {
  skip_if_not_installed("mockery")
  ha <- strrep("a", 64)
  hb <- strrep("b", 64)
  lines <- c(
    paste0(ha, "  cpython-3.10.20+20260623-aarch64-apple-darwin-install_only.tar.gz"),
    paste0(hb, "  cpython-3.14.6+20260623-aarch64-apple-darwin-install_only.tar.gz")
  )
  mockery::stub(fetch_published_sha256, "readLines", function(...) lines)
  expect_equal(
    fetch_published_sha256("https://example/SHA256SUMS",
                           "cpython-3.14.6+20260623-aarch64-apple-darwin-install_only.tar.gz"),
    hb
  )
  expect_null(fetch_published_sha256("https://example/SHA256SUMS", "no-such-file.tar.gz"))
})

test_that("fetch_published_sha256 strips a binary marker and ignores non-hash lines", {
  skip_if_not_installed("mockery")
  h <- strrep("c", 64)
  lines <- c("# a comment", paste0(h, " *portable-r-4.6.1-macos-arm64.tar.gz"))
  mockery::stub(fetch_published_sha256, "readLines", function(...) lines)
  expect_equal(
    fetch_published_sha256("https://example/SHA256SUMS", "portable-r-4.6.1-macos-arm64.tar.gz"),
    h
  )
})

test_that("fetch_published_sha256 returns NULL on fetch error or empty file", {
  skip_if_not_installed("mockery")
  mockery::stub(fetch_published_sha256, "readLines", function(...) stop("network down"))
  expect_null(fetch_published_sha256("https://example/x.sha256"))

  mockery::stub(fetch_published_sha256, "readLines", function(...) character(0))
  expect_null(fetch_published_sha256("https://example/x.sha256"))
})

test_that("r_expected_sha256 queries the .sha256 sidecar of the archive URL", {
  skip_if_not_installed("mockery")
  captured <- NULL
  mockery::stub(r_expected_sha256, "r_download_url",
                function(...) "https://example/portable-r-4.4.1-macos-arm64.tar.gz")
  mockery::stub(r_expected_sha256, "fetch_published_sha256",
                function(checksum_url, asset_filename = NULL) {
                  captured <<- list(url = checksum_url, file = asset_filename)
                  strrep("a", 64)
                })
  expect_equal(r_expected_sha256("4.4.1", "mac", "arm64"), strrep("a", 64))
  expect_equal(captured$url, "https://example/portable-r-4.4.1-macos-arm64.tar.gz.sha256")
  expect_null(captured$file)
})

test_that("python_expected_sha256 queries SHA256SUMS with the asset filename", {
  skip_if_not_installed("mockery")
  captured <- NULL
  mockery::stub(python_expected_sha256, "fetch_published_sha256",
                function(checksum_url, asset_filename = NULL) {
                  captured <<- list(url = checksum_url, file = asset_filename)
                  strrep("b", 64)
                })
  expect_equal(python_expected_sha256("3.14.6", "mac", "arm64", "20260623"), strrep("b", 64))
  expect_match(captured$url,
               "python-build-standalone/releases/download/20260623/SHA256SUMS",
               fixed = TRUE)
  expect_equal(captured$file,
               "cpython-3.14.6+20260623-aarch64-apple-darwin-install_only.tar.gz")
})

test_that("install_r_portable passes the published checksum to the download helper", {
  skip_if_not_installed("mockery")
  captured <- NULL
  mockery::stub(install_r_portable, "r_expected_sha256", function(...) strrep("a", 64))
  mockery::stub(install_r_portable, "r_install_path", function(...) "/tmp/r")
  mockery::stub(install_r_portable, "r_download_url", function(...) "https://example/r.tar.gz")
  mockery::stub(install_r_portable, "r_executable", function(...) "/tmp/r/bin/Rscript")
  mockery::stub(install_r_portable, "r_is_installed", function(...) FALSE)
  mockery::stub(install_r_portable, "download_and_extract_portable_tool",
                function(..., expected_sha256 = NULL) {
                  captured <<- expected_sha256
                  invisible("/tmp/r")
                })
  install_r_portable(version = "4.4.1", platform = "mac", arch = "arm64", verbose = FALSE)
  expect_equal(captured, strrep("a", 64))
})

test_that("install_r_portable warns and continues when no checksum is available", {
  skip_if_not_installed("mockery")
  mockery::stub(install_r_portable, "r_expected_sha256", function(...) NULL)
  mockery::stub(install_r_portable, "r_install_path", function(...) "/tmp/r")
  mockery::stub(install_r_portable, "r_download_url", function(...) "https://example/r.tar.gz")
  mockery::stub(install_r_portable, "r_executable", function(...) "/tmp/r/bin/Rscript")
  mockery::stub(install_r_portable, "r_is_installed", function(...) FALSE)
  mockery::stub(install_r_portable, "download_and_extract_portable_tool",
                function(..., expected_sha256 = NULL) {
                  expect_null(expected_sha256)
                  invisible("/tmp/r")
                })
  expect_warning(
    install_r_portable(version = "4.4.1", platform = "mac", arch = "arm64", verbose = TRUE),
    "Could not fetch the published SHA-256"
  )
})

test_that("generate_runtime_manifest embeds sha256 when available and omits it otherwise", {
  skip_if_not_installed("mockery")
  mockery::stub(generate_runtime_manifest, "r_download_url",
                function(...) "https://example/r.tar.gz")

  mockery::stub(generate_runtime_manifest, "r_expected_sha256", function(...) strrep("a", 64))
  m <- jsonlite::fromJSON(generate_runtime_manifest("4.4.1", "mac", "arm64"))
  expect_equal(m$sha256, strrep("a", 64))

  mockery::stub(generate_runtime_manifest, "r_expected_sha256", function(...) NULL)
  m2 <- jsonlite::fromJSON(generate_runtime_manifest("4.4.1", "mac", "arm64"))
  expect_null(m2$sha256)
})
