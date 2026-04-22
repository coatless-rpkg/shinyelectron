#' Determine the backend module filename for an app type and runtime strategy
#'
#' @param app_type Character string. The app type.
#' @param runtime_strategy Character string. The resolved runtime strategy.
#' @return Character string. The backend module filename (e.g., "shinylive.js").
#' @keywords internal
resolve_backend_module <- function(app_type, runtime_strategy) {
  switch(runtime_strategy,
    "shinylive" = "shinylive.js",
    "system" = , "bundled" = , "auto-download" = {
      if (grepl("^r-", app_type)) "native-r.js" else "native-py.js"
    },
    "container" = "container.js",
    cli::cli_abort(c(
      "Unknown runtime strategy: {.val {runtime_strategy}}",
      "i" = "Valid strategies: {.val {c('system', 'bundled', 'auto-download', 'container', 'shinylive')}}",
      "i" = "Set in {.arg runtime_strategy} or {.field build.runtime_strategy} in {.file _shinyelectron.yml}"
    ))
  )
}

#' Check if a backend requires Express dependencies
#'
#' @param backend_module Character string. The backend module filename.
#' @return Logical.
#' @keywords internal
backend_needs_express <- function(backend_module) {
  backend_module == "shinylive.js"
}
