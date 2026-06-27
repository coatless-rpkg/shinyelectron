#' Resolve the runtime version to use for a build
#'
#' Precedence: an explicit `dependencies.<runtime>.version` in config wins;
#' the literal `"latest"` calls the live resolver; otherwise the maintained
#' pin in `SHINYELECTRON_DEFAULTS$runtime_versions` is used.
#'
#' @param runtime One of `"r"`, `"python"`, `"electron"`.
#' @param config Full app configuration list.
#' @return Character version string.
#' @keywords internal
resolve_runtime_version <- function(runtime, config) {
  runtime <- match.arg(runtime, c("r", "python", "electron"))
  pins <- SHINYELECTRON_DEFAULTS$runtime_versions
  configured <- config$dependencies[[runtime]]$version

  if (!is.null(configured) && !identical(configured, "latest")) {
    return(configured)
  }
  if (identical(configured, "latest")) {
    return(switch(runtime,
      r        = r_portable_latest_version(),
      python   = python_resolve_pbs("latest")$version,
      electron = electron_latest_version()
    ))
  }
  switch(runtime,
    r        = pins$r,
    python   = pins$python$version,
    electron = pins$electron
  )
}

#' Fetch the latest published Electron version from the npm registry
#'
#' Queries `https://registry.npmjs.org/electron/latest` and returns the
#' `version` field as a character string. Used when
#' `dependencies$electron$version` is set to `"latest"`.
#'
#' @return Character version string (e.g. `"41.0.0"`).
#' @keywords internal
electron_latest_version <- function() {
  url <- "https://registry.npmjs.org/electron/latest"
  tmp <- tempfile(fileext = ".json")
  on.exit(unlink(tmp), add = TRUE)
  status <- tryCatch(
    utils::download.file(url, tmp, quiet = TRUE),
    error = function(e) {
      cli::cli_abort(c(
        "Failed to fetch latest Electron version from npm registry",
        "x" = "{conditionMessage(e)}",
        "i" = "Check your internet connection or set {.field dependencies$electron$version} to a specific version"
      ))
    }
  )
  if (!identical(status, 0L)) {
    cli::cli_abort(c(
      "Failed to fetch latest Electron version from npm registry",
      "x" = "HTTP request returned status {status}",
      "i" = "Check your internet connection or set {.field dependencies$electron$version} to a specific version"
    ))
  }
  meta <- jsonlite::fromJSON(tmp)
  as.character(meta$version)
}
