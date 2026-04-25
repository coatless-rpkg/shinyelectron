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

#' Validate the Python shinylive package CLI is usable
#'
#' Mirrors the command preference used by `convert_py_to_shinylive()`: first
#' the `shinylive` console script on PATH, then `python -m shinylive` as a
#' fallback. Runs `--version` to confirm the CLI actually executes (an import
#' check is not enough — shinylive ships no `__main__.py`, so a package that
#' imports fine can still fail at export time).
#'
#' @return Invisible character string with the detected shinylive version.
#' @keywords internal
validate_python_shinylive_installed <- function() {
  shinylive_cmd <- Sys.which("shinylive")
  if (nzchar(shinylive_cmd)) {
    result <- processx::run(
      "shinylive", c("--version"),
      error_on_status = FALSE, timeout = 30
    )
    cmd_label <- "shinylive"
  } else {
    python_cmd <- find_python_command()
    if (is.null(python_cmd)) {
      cli::cli_abort("Python is required but was not found")
    }
    result <- processx::run(
      python_cmd, c("-m", "shinylive", "--version"),
      error_on_status = FALSE, timeout = 30
    )
    cmd_label <- paste(python_cmd, "-m shinylive")
  }

  if (result$status != 0) {
    stderr <- trimws(result$stderr %||% "")
    main_missing <- grepl("cannot be directly executed|No module named shinylive\\.__main__", stderr)
    hints <- c(
      "Install the CLI with: {.code pip install shinylive}"
    )
    if (main_missing) {
      hints <- c(
        "Your Python has shinylive as a module but the {.code shinylive} command is not on PATH.",
        "On Windows, pip installs scripts into {.path %APPDATA%\\\\Python\\\\Python3XX\\\\Scripts}; add that directory to PATH.",
        "Or (re)install with: {.code pip install --upgrade --force-reinstall shinylive}"
      )
    }
    cli::cli_abort(c(
      "The {.pkg shinylive} Python package CLI is required for the shinylive strategy with Python apps",
      stats::setNames(hints, rep("i", length(hints))),
      "x" = "Command: {.code {cmd_label} --version}",
      "x" = "Error: {stderr}"
    ))
  }

  invisible(trimws(paste0(result$stdout, result$stderr)))
}

#' Validate the Python shiny package is installed
#'
#' Used by the native `py-shiny` app type. Only checks importability — the
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
