# python_resolve_pbs tries the lightweight `releases/latest` endpoint first
# (pbs_latest_release) and only falls back to the full release list
# (pbs_list_releases) for a version absent from the latest release. All network
# access is mocked.

test_that("python_resolve_pbs maps a version to a release via the latest release", {
  skip_if_not_installed("mockery")
  latest <- list(tag_name = "20251007",
                 assets = list(list(name = "cpython-3.14.6+20251007-aarch64-apple-darwin-install_only.tar.gz")))
  mockery::stub(python_resolve_pbs, "pbs_latest_release", function() latest)
  res <- python_resolve_pbs("3.14.6")
  expect_equal(res$version, "3.14.6")
  expect_equal(res$release, "20251007")
})

test_that("python_resolve_pbs resolves a current version without querying the full list", {
  skip_if_not_installed("mockery")
  latest <- list(tag_name = "20260623",
                 assets = list(list(name = "cpython-3.13.14+20260623-aarch64-apple-darwin-install_only.tar.gz")))
  mockery::stub(python_resolve_pbs, "pbs_latest_release", function() latest)
  mockery::stub(python_resolve_pbs, "pbs_list_releases",
                function() stop("the full release list must not be queried when the latest release has the version"))
  res <- python_resolve_pbs("3.13.14")
  expect_equal(res$version, "3.13.14")
  expect_equal(res$release, "20260623")
})

test_that("python_resolve_pbs falls back to the full list for a patch absent from latest", {
  skip_if_not_installed("mockery")
  latest <- list(tag_name = "20260623",
                 assets = list(list(name = "cpython-3.13.14+20260623-aarch64-apple-darwin-install_only.tar.gz")))
  fallback <- list(list(tag_name = "20250101",
                        assets = list(list(name = "cpython-3.13.2+20250101-aarch64-apple-darwin-install_only.tar.gz"))))
  mockery::stub(python_resolve_pbs, "pbs_latest_release", function() latest)
  mockery::stub(python_resolve_pbs, "pbs_list_releases", function() fallback)
  res <- python_resolve_pbs("3.13.2")
  expect_equal(res$version, "3.13.2")
  expect_equal(res$release, "20250101")
})

test_that("python_resolve_pbs returns the newest match in the fallback scan", {
  skip_if_not_installed("mockery")
  # Version absent from the latest release, so fall back to the full list, which
  # is newest first; the resolver must return the first (newest) match.
  empty_latest <- list(tag_name = "20260623", assets = list())
  fallback <- list(
    list(tag_name = "20251101",
         assets = list(list(name = "cpython-3.12.7+20251101-x86_64-pc-windows-msvc-install_only.tar.gz"))),
    list(tag_name = "20251007",
         assets = list(list(name = "cpython-3.12.7+20251007-aarch64-apple-darwin-install_only.tar.gz")))
  )
  mockery::stub(python_resolve_pbs, "pbs_latest_release", function() empty_latest)
  mockery::stub(python_resolve_pbs, "pbs_list_releases", function() fallback)
  res <- python_resolve_pbs("3.12.7")
  expect_equal(res$release, "20251101")
})

test_that("python_resolve_pbs latest returns a CPython version from the latest release", {
  skip_if_not_installed("mockery")
  latest <- list(tag_name = "20260101",
                 assets = list(
                   list(name = "cpython-3.14.6+20260101-aarch64-apple-darwin-install_only.tar.gz"),
                   list(name = "cpython-3.13.2+20260101-aarch64-apple-darwin-install_only.tar.gz")
                 ))
  mockery::stub(python_resolve_pbs, "pbs_latest_release", function() latest)
  res <- python_resolve_pbs("latest")
  expect_equal(res$release, "20260101")
  expect_match(res$version, "^\\d+\\.\\d+\\.\\d+$")
})

test_that("python_resolve_pbs aborts when a version is found nowhere", {
  skip_if_not_installed("mockery")
  latest <- list(tag_name = "20260101",
                 assets = list(list(name = "cpython-3.14.6+20260101-aarch64-apple-darwin-install_only.tar.gz")))
  mockery::stub(python_resolve_pbs, "pbs_latest_release", function() latest)
  mockery::stub(python_resolve_pbs, "pbs_list_releases",
                function() list(list(tag_name = "20251007",
                  assets = list(list(name = "cpython-3.12.10+20251007-aarch64-apple-darwin-install_only.tar.gz")))))
  expect_error(python_resolve_pbs("9.9.9"), class = "rlang_error")
})

test_that("python_resolve_pbs aborts for latest when no install_only asset exists", {
  skip_if_not_installed("mockery")
  mockery::stub(python_resolve_pbs, "pbs_latest_release",
                function() list(tag_name = "20251007", assets = list()))
  mockery::stub(python_resolve_pbs, "pbs_list_releases",
                function() list(list(tag_name = "20251007", assets = list())))
  expect_error(python_resolve_pbs("latest"), class = "rlang_error")
})

# --- resolve_python_pbs offline-default tests ---

test_that("the default Python pin resolves its release offline (no network)", {
  skip_if_not_installed("mockery")
  pin <- SHINYELECTRON_DEFAULTS$runtime_versions$python
  mockery::stub(resolve_python_pbs, "python_resolve_pbs",
                function(...) stop("network must not be called for the default pin"))
  res <- resolve_python_pbs(pin$version)
  expect_equal(res$release, pin$release)
  expect_equal(res$version, pin$version)
})

test_that("a custom Python version goes through python_resolve_pbs", {
  skip_if_not_installed("mockery")
  mockery::stub(resolve_python_pbs, "python_resolve_pbs",
                function(version) list(version = version, release = "29990101"))
  res <- resolve_python_pbs("3.13.2")
  expect_equal(res$release, "29990101")
})
