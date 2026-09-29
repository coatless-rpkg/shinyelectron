#' Read a true/false setting from the configuration
#'
#' YAML's unquoted `true` and `false` (and `yes` and `no`, which the YAML
#' parser also reads as logical) pass through. A quoted `"true"`, `"false"`,
#' `"yes"` or `"no"`, in any case, is read as the matching logical with a
#' warning, because a quoted value is easy to write by accident and earlier
#' versions passed it through. Anything else stops with an error that names
#' the key.
#'
#' @param value Value read from the configuration.
#' @param field Character. Dotted name of the key, used in messages.
#' @param default Value returned when `value` is `NULL`.
#' @return `TRUE`, `FALSE`, or `default`.
#' @keywords internal
config_flag <- function(value, field, default = NULL) {
  if (is.null(value)) {
    return(default)
  }
  if (is.logical(value) && length(value) == 1L && !is.na(value)) {
    return(value)
  }
  if (is.character(value) && length(value) == 1L && !is.na(value)) {
    flag <- switch(tolower(trimws(value)),
      "true" = , "yes" = TRUE,
      "false" = , "no" = FALSE,
      NULL
    )
    if (!is.null(flag)) {
      word <- tolower(as.character(flag))
      cli::cli_warn(c(
        "{.field {field}} is the quoted string {.val {value}}; reading it as {.code {word}}.",
        "i" = "Write {.code {word}} without quotes in {.file {CONFIG_FILENAME}}."
      ), class = "shinyelectron_quoted_flag")
      return(flag)
    }
  }
  shown <- if (is.atomic(value) && length(value) == 1L) value else class(value)[1]
  cli::cli_abort(c(
    "Invalid {.field {field}} in config: {.val {shown}}",
    "i" = "Must be {.code true} or {.code false} without quotes, or left unset."
  ), class = "shinyelectron_invalid_flag")
}
