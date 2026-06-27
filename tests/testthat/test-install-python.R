test_that("python_resolve_pbs maps a version to a release", {
  skip_if_not_installed("mockery")
  fake <- list(list(tag_name = "20251007",
                    assets = list(list(name = "cpython-3.14.6+20251007-aarch64-apple-darwin-install_only.tar.gz"))))
  mockery::stub(python_resolve_pbs, "pbs_list_releases", function() fake)
  res <- python_resolve_pbs("3.14.6")
  expect_equal(res$version, "3.14.6")
  expect_equal(res$release, "20251007")
})

test_that("python_resolve_pbs picks the newest release for a version", {
  skip_if_not_installed("mockery")
  # releases ordered newest first; resolver must return the first match
  fake <- list(
    list(tag_name = "20251101",
         assets = list(
           list(name = "cpython-3.14.6+20251101-x86_64-pc-windows-msvc-install_only.tar.gz")
         )),
    list(tag_name = "20251007",
         assets = list(
           list(name = "cpython-3.14.6+20251007-aarch64-apple-darwin-install_only.tar.gz")
         ))
  )
  mockery::stub(python_resolve_pbs, "pbs_list_releases", function() fake)
  res <- python_resolve_pbs("3.14.6")
  expect_equal(res$release, "20251101")
})

test_that("python_resolve_pbs latest returns newest release CPython", {
  skip_if_not_installed("mockery")
  fake <- list(
    list(tag_name = "20260101",
         assets = list(
           list(name = "cpython-3.14.6+20260101-aarch64-apple-darwin-install_only.tar.gz"),
           list(name = "cpython-3.13.2+20260101-aarch64-apple-darwin-install_only.tar.gz")
         )),
    list(tag_name = "20251007",
         assets = list(
           list(name = "cpython-3.12.10+20251007-aarch64-apple-darwin-install_only.tar.gz")
         ))
  )
  mockery::stub(python_resolve_pbs, "pbs_list_releases", function() fake)
  res <- python_resolve_pbs("latest")
  expect_equal(res$release, "20260101")
  expect_type(res$version, "character")
  expect_match(res$version, "^\\d+\\.\\d+\\.\\d+$")
})

test_that("python_resolve_pbs aborts when version not found", {
  skip_if_not_installed("mockery")
  fake <- list(list(tag_name = "20251007",
                    assets = list(list(name = "cpython-3.12.10+20251007-aarch64-apple-darwin-install_only.tar.gz"))))
  mockery::stub(python_resolve_pbs, "pbs_list_releases", function() fake)
  expect_error(python_resolve_pbs("9.9.9"), class = "rlang_error")
})

test_that("python_resolve_pbs aborts when latest has no assets", {
  skip_if_not_installed("mockery")
  fake <- list(list(tag_name = "20251007", assets = list()))
  mockery::stub(python_resolve_pbs, "pbs_list_releases", function() fake)
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
