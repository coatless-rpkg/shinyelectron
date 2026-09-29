#' Collect the app metadata settings
#'
#' Reads `app.description`, `app.author`, `app.homepage`, and `app.copyright`
#' for `package.json` and the About dialog, keeping only usable values: text
#' is reduced to one line with [metadata_text()], so blank text counts as
#' unset, the author is normalized with [normalize_app_author()], and a
#' homepage must be an http or https URL (`validate_config()` rejects any
#' other homepage).
#'
#' @param config List. The effective configuration.
#' @return A list with `description`, `author`, `homepage`, and `copyright`
#'   entries, each `NULL` when unset.
#' @keywords internal
app_metadata <- function(config) {
  homepage <- config$app$homepage
  list(
    description = metadata_text(config$app$description),
    author = normalize_app_author(config$app$author),
    homepage = if (is_http_url(homepage)) homepage,
    copyright = metadata_text(config$app$copyright)
  )
}

#' Reduce a metadata setting to one line of text
#'
#' electron-builder writes the description, copyright, and author name into
#' single-line fields such as the Windows file properties, so line breaks
#' become spaces and surrounding whitespace is dropped.
#'
#' @param x Value to clean.
#' @return A single string, or `NULL` when `x` is not a string or holds only
#'   whitespace.
#' @keywords internal
metadata_text <- function(x) {
  if (!is_nonempty_string(x)) return(NULL)
  x <- trimws(gsub("[\r\n]+", " ", x))
  if (nzchar(x)) x else NULL
}

#' Replace straight double quotes with typographic ones
#'
#' electron-builder writes the product name, the copyright, and the author's
#' name into double-quoted strings of the Windows installer (NSIS) script
#' without escaping them, so a straight double quote ends the string and the
#' installer build fails. electron-builder already turns the quotes in the
#' description into typographic ones; this applies the same rule to the other
#' values `generate_package_json()` writes.
#'
#' @param x A string, or `NULL`.
#' @return `x` with each `"` replaced by an opening or closing typographic
#'   quote, or `NULL` when `x` is `NULL`.
#' @keywords internal
smart_quotes <- function(x) {
  if (is.null(x)) return(NULL)
  x <- gsub("(^|[-\u2014/[(\u2018[:space:]])\"", "\\1\u201c", x, perl = TRUE)
  gsub("\"", "\u201d", x, fixed = TRUE)
}

#' Stop or warn when app text contains `$`
#'
#' electron-builder passes the app name, description, author's name, and
#' copyright to NSIS, which builds the Windows installer, without escaping
#' `$`. NSIS reads `$` as the start of a variable: the build fails on an
#' unknown one (electron-builder treats NSIS warnings as errors), and a known
#' one silently changes the text. So a `$` stops an export that builds a
#' Windows installer, before any conversion, and warns for any other.
#'
#' @param app_name Character string. The display name.
#' @param config List. The effective configuration.
#' @param windows Logical. Whether the export builds a Windows installer.
#' @return Invisible `TRUE`; aborts or warns when a value contains `$`.
#' @keywords internal
check_installer_text <- function(app_name, config, windows) {
  metadata <- app_metadata(config)
  values <- list(
    "app name" = app_name,
    app.description = metadata$description,
    app.author = metadata$author$name,
    app.copyright = metadata$copyright
  )
  has_dollar <- vapply(values, function(value) {
    is_nonempty_string(value) && grepl("$", value, fixed = TRUE)
  }, logical(1))
  if (!any(has_dollar)) return(invisible(TRUE))

  fields <- names(values)[has_dollar]
  problem <- c(
    "{.field {fields}} {?contains/contain} {.code $}, which a Windows installer cannot hold.",
    "i" = "electron-builder passes {cli::qty(fields)}{?this value/these values} to NSIS without escaping, and NSIS reads {.code $} as the start of a variable, so the installer build fails or the text changes."
  )
  if (windows) {
    cli::cli_abort(
      c(problem, "i" = "Remove the {.code $} and export again."),
      class = "shinyelectron_installer_dollar"
    )
  }
  cli::cli_warn(
    c(problem, "i" = "Remove the {.code $} before you build for Windows."),
    class = "shinyelectron_installer_dollar"
  )
  invisible(TRUE)
}

#' Test for an http or https URL
#'
#' @param x Value to test.
#' @return `TRUE` when `x` is a single string that starts with `http://` or
#'   `https://` (in any case) followed by more text, otherwise `FALSE`.
#' @keywords internal
is_http_url <- function(x) {
  is_nonempty_string(x) && grepl("^https?://[^[:space:]]", x, ignore.case = TRUE)
}

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
  single_string <- function(value) is.character(value) && length(value) == 1L

  if (is.null(x) || (single_string(x) && is.null(metadata_text(x)))) {
    return(NULL)
  }
  if (single_string(x)) {
    group <- function(pattern) regmatches(x, regexec(pattern, x))[[1]][2]
    person <- list(
      name = metadata_text(regmatches(x, regexpr("^[^(<]+", x))),
      email = metadata_text(group("<([^>]+)>")),
      url = metadata_text(group("\\(([^)]+)\\)"))
    )
  } else if (is.list(x) && length(x) > 0 && !is.null(names(x)) &&
             all(names(x) %in% c("name", "email", "url")) &&
             all(vapply(x, function(v) is.null(v) || single_string(v), logical(1)))) {
    person <- list(
      name = metadata_text(x$name),
      email = metadata_text(x$email),
      url = metadata_text(x$url)
    )
  } else {
    cli::cli_warn(c(
      "Ignoring {.field app.author}: it must be a string or a map.",
      "i" = "Write it as {.val Jane Doe <jane@example.org> (https://example.org)}, or as a map with {.field name}, {.field email}, and {.field url} entries."
    ))
    return(NULL)
  }

  if (all(vapply(person, is.null, logical(1)))) NULL else person
}
