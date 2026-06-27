#' Resolve the runtime version to use for a build
#'
#' Precedence: an explicit `dependencies.<runtime>.version` in config wins;
#' the literal `"latest"` calls the live resolver; otherwise the maintained
#' pin in `SHINYELECTRON_DEFAULTS$runtime_versions` is used.
#'
#' @param runtime One of `"r"`, `"python"`, `"node"`.
#' @param config Full app configuration list.
#' @return Character version string.
#' @keywords internal
resolve_runtime_version <- function(runtime, config) {
  runtime <- match.arg(runtime, c("r", "python", "node"))
  pins <- SHINYELECTRON_DEFAULTS$runtime_versions
  configured <- config$dependencies[[runtime]]$version

  if (!is.null(configured) && !identical(configured, "latest")) {
    return(configured)
  }
  if (identical(configured, "latest")) {
    return(switch(runtime,
      r = r_portable_latest_version(),
      python = python_resolve_pbs("latest")$version,
      node = nodejs_latest_lts()
    ))
  }
  switch(runtime,
    r = pins$r,
    python = pins$python$version,
    node = pins$node
  )
}
