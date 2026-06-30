#' Validate Python is available on the system
#'
#' @return Invisible character string with the Python command name.
#' @keywords internal
validate_python_available <- function() {
  validate_command_available(
    command_resolver = find_python_command,
    not_found = c(
      "Python is required for this operation but was not found",
      "i" = "Install Python from {.url https://www.python.org/downloads/}",
      "i" = "Ensure {.code python3} or {.code python} is on your PATH"
    ),
    label = "Python"
  )
}

#' Resolve a working shinylive Python CLI invocation
#'
#' Prefers the `shinylive` console script, but if that script is on PATH yet
#' backed by a Python without the module (a PATH / version skew that CI
#' environments hit), falls back to `python -m shinylive`. Runs `--version` on
#' each candidate to confirm it actually executes -- an import check is not
#' enough, since shinylive ships no `__main__.py`. Aborts with installation
#' hints if neither candidate works.
#'
#' @return A list with `program` (character), `prefix` (character vector of
#'   leading arguments), `label` (human-readable command), and `version`.
#'   `c(prefix, <cli args>)` are the arguments to pass to `program`.
#' @keywords internal
resolve_python_shinylive_cmd <- function() {
  candidates <- list()
  if (nzchar(Sys.which("shinylive"))) {
    candidates <- c(candidates, list(
      list(program = "shinylive", prefix = character(0), label = "shinylive")
    ))
  }
  python_cmd <- find_python_command()
  if (!is.null(python_cmd)) {
    candidates <- c(candidates, list(
      list(program = python_cmd, prefix = c("-m", "shinylive"),
           label = paste(python_cmd, "-m shinylive"))
    ))
  }

  last_stderr <- ""
  for (cand in candidates) {
    result <- processx::run(
      cand$program, c(cand$prefix, "--version"),
      error_on_status = FALSE, timeout = 30
    )
    if (result$status == 0) {
      cand$version <- trimws(paste0(result$stdout, result$stderr))
      return(cand)
    }
    last_stderr <- trimws(result$stderr %||% "")
  }

  module_present <- grepl("cannot be directly executed|No module named shinylive\\.__main__", last_stderr)
  hints <- "Install the CLI with: {.code pip install shinylive}"
  if (module_present) {
    hints <- c(
      "Your Python has shinylive as a module but the {.code shinylive} command is not usable.",
      "On Windows, pip installs scripts into {.path %APPDATA%\\\\Python\\\\Python3XX\\\\Scripts}; add that directory to PATH.",
      "Or (re)install with: {.code pip install --upgrade --force-reinstall shinylive}"
    )
  }
  cli::cli_abort(c(
    "The {.pkg shinylive} Python package CLI is required for the shinylive strategy with Python apps",
    stats::setNames(hints, rep("i", length(hints))),
    "x" = "Error: {last_stderr}"
  ))
}

#' Validate the Python shinylive package CLI is usable
#'
#' Thin wrapper over [resolve_python_shinylive_cmd()] for callers that only
#' need to confirm the CLI works (pre-flight checks, sitrep).
#'
#' @return Invisible character string with the detected shinylive version.
#' @keywords internal
validate_python_shinylive_installed <- function() {
  invisible(resolve_python_shinylive_cmd()$version)
}

#' Validate the Python shiny package is installed
#'
#' Used by the native `py-shiny` app type. Only checks importability -- the
#' export pipeline spawns `python -m shiny run` at runtime on the user's
#' machine, not at build time.
#'
#' @return Invisible character string with the detected shiny version.
#' @keywords internal
validate_python_shiny_installed <- function() {
  python_cmd <- find_python_command()

  if (is.null(python_cmd)) {
    cli::cli_abort("Python is required but was not found")
  }

  result <- processx::run(
    python_cmd,
    c("-c", "import shiny; print(shiny.__version__)"),
    error_on_status = FALSE,
    timeout = 30
  )

  if (result$status != 0) {
    cli::cli_abort(c(
      "The {.pkg shiny} Python package is required for py-shiny apps",
      "i" = "Install with: {.code pip install shiny}",
      "x" = "Error: {trimws(result$stderr %||% '')}"
    ))
  }

  invisible(trimws(result$stdout))
}
