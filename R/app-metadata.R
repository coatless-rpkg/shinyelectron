#' Normalize the app author
#'
#' `app.author` takes either form npm uses for a person: a string
#' `"Name <email> (url)"`, where each part is optional, or a map with `name`,
#' `email`, and `url` entries. Both become the same list, which fills the
#' `author` field of `package.json` and the About dialog. The string is split
#' the way npm and electron-builder split it.
#'
#' @param x The `app.author` setting.
#' @return A list with `name`, `email`, and `url` entries, each a string or
#'   `NULL`, or `NULL` when `x` is unset or blank. Any other shape warns and
#'   returns `NULL`.
#' @keywords internal
normalize_app_author <- function(x) {
  field <- function(value) {
    if (is_nonempty_string(value) && nzchar(trimws(value))) trimws(value) else NULL
  }
  single_string <- function(value) is.character(value) && length(value) == 1L

  if (is.null(x) || (single_string(x) && is.null(field(x)))) {
    return(NULL)
  }
  if (single_string(x)) {
    group <- function(pattern) regmatches(x, regexec(pattern, x))[[1]][2]
    person <- list(
      name = field(regmatches(x, regexpr("^[^(<]+", x))),
      email = field(group("<([^>]+)>")),
      url = field(group("\\(([^)]+)\\)"))
    )
  } else if (is.list(x) && length(x) > 0 && !is.null(names(x)) &&
             all(names(x) %in% c("name", "email", "url")) &&
             all(vapply(x, function(v) is.null(v) || single_string(v), logical(1)))) {
    person <- list(name = field(x$name), email = field(x$email), url = field(x$url))
  } else {
    cli::cli_warn(c(
      "Ignoring {.field app.author}: it must be a string or a map.",
      "i" = "Write it as {.val Jane Doe <jane@example.org> (https://example.org)}, or as a map with {.field name}, {.field email}, and {.field url} entries."
    ))
    return(NULL)
  }

  if (all(vapply(person, is.null, logical(1)))) NULL else person
}
