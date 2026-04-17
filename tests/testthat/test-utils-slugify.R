test_that("slugify converts display names to path-safe slugs", {
  expect_equal(slugify("My App"), "my-app")
  expect_equal(slugify("My Amazing App!"), "my-amazing-app")
  expect_equal(slugify("app_v2.0"), "app-v2-0")
  expect_equal(slugify("  Leading Spaces  "), "leading-spaces")
  expect_equal(slugify("ALLCAPS"), "allcaps")
  expect_equal(slugify("already-slugged"), "already-slugged")
  expect_equal(slugify("special@#$chars"), "special-chars")
  expect_equal(slugify("multiple---dashes"), "multiple-dashes")
})

test_that("slugify handles edge cases", {
  expect_equal(slugify("a"), "a")
  expect_equal(slugify("123"), "123")
  expect_equal(slugify("App (v2)"), "app-v2")
})

test_that("validate_slug rejects invalid slugs", {
  expect_error(validate_slug(""), "empty")
  expect_error(validate_slug(NULL), "empty")
  expect_error(validate_slug("-my-app"), "Invalid slug")
  expect_error(validate_slug("my-app-"), "Invalid slug")
  expect_error(validate_slug("Has Spaces"), "Invalid slug")
  expect_error(validate_slug("UPPERCASE"), "Invalid slug")
  expect_error(validate_slug("special!chars"), "Invalid slug")
})

test_that("slugify errors on empty or all-special-character input", {
  expect_error(slugify(""), "empty")
  expect_error(slugify("@#$"), "empty slug")
})

test_that("validate_slug accepts valid slugs", {
  expect_silent(validate_slug("my-app"))
  expect_silent(validate_slug("app-v2"))
  expect_silent(validate_slug("simple"))
  expect_silent(validate_slug("my-app-123"))
})
