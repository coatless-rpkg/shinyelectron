# Skip guards for tests that exercise the shinylive conversion pipelines.

r_shinylive_available <- function() {
  requireNamespace("shinylive", quietly = TRUE) &&
    !nzchar(Sys.getenv("_R_CHECK_PACKAGE_NAME_", ""))
}

py_shinylive_available <- function() {
  if (nzchar(Sys.getenv("_R_CHECK_PACKAGE_NAME_", ""))) return(FALSE)
  tryCatch({
    validate_python_available()
    validate_python_shinylive_installed()
    TRUE
  }, error = function(e) FALSE)
}
