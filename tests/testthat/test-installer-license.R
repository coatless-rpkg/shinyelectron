# Writes `bytes` to a license file called `name`, copies it into a fresh
# project with copy_installer_license(), and returns the bytes of both files.
copied_license <- function(bytes, name = "LICENSE.txt") {
  root <- tempfile("license-")
  dir.create(file.path(root, "project"), recursive = TRUE)
  on.exit(unlink(root, recursive = TRUE), add = TRUE)
  src <- file.path(root, name)
  writeBin(bytes, src)
  dest <- copy_installer_license(
    file.path(root, "project"),
    list(installer = list(license_file = src))
  )
  list(
    path = basename(dest),
    copy = readBin(dest, "raw", n = file.size(dest)),
    source = readBin(src, "raw", n = file.size(src))
  )
}

bom <- as.raw(c(0xef, 0xbb, 0xbf))
utf8 <- charToRaw(enc2utf8("Copyright © 2026 “Demo”"))

test_that("copy_installer_license marks UTF-8 text with a byte order mark", {
  res <- copied_license(utf8)
  expect_equal(res$path, "installer-license.txt")
  expect_equal(res$copy, c(bom, utf8))
  # Only the copy changes; the user's file is left as it was.
  expect_equal(res$source, utf8)

  # A license without an extension is copied as plain text too.
  expect_equal(copied_license(utf8, "LICENSE")$copy, c(bom, utf8))
})

test_that("copy_installer_license leaves ASCII text unchanged", {
  ascii <- charToRaw("Copyright (c) 2026 Demo")
  expect_equal(copied_license(ascii)$copy, ascii)
})

test_that("copy_installer_license does not add a second byte order mark", {
  expect_equal(copied_license(c(bom, utf8))$copy, c(bom, utf8))
})

test_that("copy_installer_license leaves Latin-1 text unchanged", {
  latin1 <- c(charToRaw("Copyright "), as.raw(0xa9), charToRaw(" 2026 caf"),
              as.raw(0xe9))
  expect_equal(copied_license(latin1)$copy, latin1)
})

test_that("copy_installer_license leaves UTF-16 text unchanged", {
  utf16 <- c(as.raw(c(0xff, 0xfe)),
             iconv("Terms ©", "UTF-8", "UTF-16LE", toRaw = TRUE)[[1]])
  expect_equal(copied_license(utf16)$copy, utf16)
})

test_that("copy_installer_license leaves RTF licenses unchanged", {
  rtf <- c(charToRaw("{\\rtf1 "), utf8, charToRaw("}"))
  res <- copied_license(rtf, "EULA.rtf")
  expect_equal(res$path, "installer-license.rtf")
  expect_equal(res$copy, rtf)
})
