# tests/testthat/test-demo-matrix.R

test_that("ext_for maps platforms to installer extensions", {
  expect_equal(ext_for("mac"), "dmg")
  expect_equal(ext_for("win"), "exe")
  expect_equal(ext_for("linux"), "AppImage")
  expect_equal(ext_for(c("mac", "linux")), c("dmg", "AppImage"))
})

test_that("demo_release_matrix has the expected shape and count", {
  m <- demo_release_matrix()
  expect_s3_class(m, "data.frame")
  expect_equal(
    names(m),
    c("demo", "name", "language", "strategy",
      "platform", "arch", "runner", "asset_name", "requirement")
  )
  # 4 demos x 5 strategies x 4 targets = 80, minus 4 (R x {bundled,auto-download}
  # x linux).
  expect_equal(nrow(m), 76)
})

test_that("demo_release_matrix excludes bundled/auto-download R on Linux", {
  m <- demo_release_matrix()
  r_linux_native <- m[m$language == "r" & m$platform == "linux" &
                        m$strategy %in% c("bundled", "auto-download"), ]
  expect_equal(nrow(r_linux_native), 0)
  # Python bundled on Linux IS valid.
  expect_true(any(m$demo == "demo-py-app-suite" & m$platform == "linux" &
                    m$strategy == "bundled"))
  # shinylive R on Linux IS valid.
  expect_true(any(m$demo == "demo-r-app-suite" & m$platform == "linux" &
                    m$strategy == "shinylive"))
})

test_that("demo_release_matrix builds version-free asset names and requirements", {
  m <- demo_release_matrix()
  row <- m[m$demo == "demo-r-app-suite" & m$strategy == "shinylive" &
             m$platform == "win" & m$arch == "x64", ]
  expect_equal(nrow(row), 1)
  expect_equal(row$asset_name, "demo-r-app-suite-shinylive-win-x64.exe")
  expect_equal(row$requirement, "none")

  mac <- m[m$platform == "mac", ]
  expect_true(all(grepl("\\.dmg$", mac$asset_name)))
  linux <- m[m$platform == "linux", ]
  expect_true(all(grepl("\\.AppImage$", linux$asset_name)))

  reqs <- unique(m[, c("strategy", "requirement")])
  expect_equal(reqs$requirement[reqs$strategy == "system"], "R or Python installed")
  expect_equal(reqs$requirement[reqs$strategy == "container"], "Docker or Podman")
  expect_equal(reqs$requirement[reqs$strategy == "auto-download"],
               "internet on first launch")
})
