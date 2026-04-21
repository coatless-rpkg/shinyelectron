# Registry of bundled examples
SHINYELECTRON_EXAMPLES <- list(
  r = list(
    dir = "demos/demo-single",
    language = "r",
    description = "R Shiny dashboard with runtime detection and interactive plot (works in all strategies including shinylive)"
  ),
  python = list(
    dir = "demos/demo-py-single",
    language = "python",
    description = "Python Shiny dashboard with runtime detection and interactive plot (works in all strategies including shinylive)"
  ),
  suite = list(
    dir = "demos/multi-app-suite",
    language = "r",
    description = "Multi-app launcher with 3 bslib-themed R Shiny apps"
  )
)

#' List Available Examples
#'
#' Shows all bundled example applications with their descriptions.
#'
#' @return A data frame with columns: \code{name} (character ID),
#'   \code{language} (R or Python), \code{type} (app type),
#'   and \code{description} (human-readable summary).
#'
#' @examples
#' available_examples()
#'
#' @export
available_examples <- function() {
  cli::cli_h2("Available shinyelectron examples")
  cat("\n")

  for (name in names(SHINYELECTRON_EXAMPLES)) {
    ex <- SHINYELECTRON_EXAMPLES[[name]]
    lang_label <- if (ex$language == "r") "R" else "Python"
    cli::cli_text("  {.strong {name}} ({lang_label})")
    cli::cli_text("    {.emph {ex$description}}")
    cat("\n")
  }

  cli::cli_h2("Usage")
  cli::cli_text('  {.code path <- example_app("r")}')
  cli::cli_text('  {.code export(path, "my-output", app_type = "r-shiny", runtime_strategy = "system")}')

  df <- data.frame(
    name = names(SHINYELECTRON_EXAMPLES),
    language = vapply(SHINYELECTRON_EXAMPLES, `[[`, character(1), "language"),
    description = vapply(SHINYELECTRON_EXAMPLES, `[[`, character(1), "description"),
    stringsAsFactors = FALSE,
    row.names = NULL
  )
  invisible(df)
}

#' Get Path to an Example Application
#'
#' Returns the path to a bundled example application directory. Use this
#' path as the `appdir` argument to [export()].
#'
#' @param name Character string. Name of the example (see [available_examples()]).
#' @return Character string. Path to the example app directory.
#'
#' @examples
#' # Get the path to a bundled example
#' example_app("r")
#' example_app("python")
#'
#' \dontrun{
#' # Pass the path to export() to build a desktop app
#' path <- example_app("r")
#' export(path, "output", app_type = "r-shiny", runtime_strategy = "system")
#' }
#'
#' @export
example_app <- function(name) {
  if (!name %in% names(SHINYELECTRON_EXAMPLES)) {
    cli::cli_abort(c(
      "Unknown example: {.val {name}}",
      "i" = "Run {.code available_examples()} to see available examples"
    ))
  }

  ex <- SHINYELECTRON_EXAMPLES[[name]]
  ex_path <- system.file(ex$dir, package = "shinyelectron")

  if (!nzchar(ex_path) || !dir.exists(ex_path)) {
    cli::cli_abort("Example {.val {name}} not found in installed package")
  }

  ex_path
}
