test_that("package code does not use <<-", {
  ns <- asNamespace("shinyelectron")
  fns <- Filter(is.function, mget(ls(ns, all.names = TRUE), envir = ns))
  uses_superassignment <- vapply(
    fns,
    function(f) any(grepl("<<-", deparse(f), fixed = TRUE)),
    logical(1)
  )
  expect_equal(names(fns)[uses_superassignment], character(0))
})

test_that("tests do not use <<- or ->>", {
  # Parse tokens rather than text, so strings and comments that mention the
  # operators do not count.
  files <- list.files(test_path(), pattern = "[.][Rr]$", full.names = TRUE)
  uses_superassignment <- vapply(files, function(file) {
    tokens <- utils::getParseData(parse(file, keep.source = TRUE))
    any(tokens$token %in% c("LEFT_ASSIGN", "RIGHT_ASSIGN") &
          tokens$text %in% c("<<-", "->>"))
  }, logical(1))
  expect_equal(basename(files)[uses_superassignment], character(0))
})
