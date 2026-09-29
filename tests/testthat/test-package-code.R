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
