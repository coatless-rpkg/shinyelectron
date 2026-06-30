# extract_tar_program() chooses the tar implementation used to unpack a
# portable runtime archive. The Windows choice matters: R's internal tar cannot
# parse the PAX / long-name records in python-build-standalone archives (it
# fails with "embedded nul in string"), so we prefer the native bsdtar shipped
# at System32\tar.exe.

test_that("extract_tar_program prefers Windows bsdtar when present", {
  root <- tempfile("winroot-")
  dir.create(file.path(root, "System32"), recursive = TRUE)
  on.exit(unlink(root, recursive = TRUE), add = TRUE)
  file.create(file.path(root, "System32", "tar.exe"))

  expect_equal(
    extract_tar_program(os_type = "windows", system_root = root),
    file.path(root, "System32", "tar.exe")
  )
})

test_that("extract_tar_program falls back to internal tar on Windows without bsdtar", {
  root <- tempfile("winroot-")
  dir.create(root)
  on.exit(unlink(root, recursive = TRUE), add = TRUE)

  expect_equal(
    extract_tar_program(os_type = "windows", system_root = root),
    "internal"
  )
})

test_that("extract_tar_program uses system tar on unix", {
  expect_equal(
    extract_tar_program(os_type = "unix"),
    Sys.which("tar")
  )
})
