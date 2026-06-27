#' Detect available container engine
#'
#' Searches for Docker or Podman on the system.
#'
#' @param preference Character string or NULL. Preferred engine ("docker" or "podman").
#' @return Character string ("docker" or "podman") or NULL if none found.
#' @keywords internal
detect_container_engine <- function(preference = NULL) {
  engines <- SHINYELECTRON_DEFAULTS$valid_container_engines

  if (!is.null(preference) && preference %in% engines) {
    path <- Sys.which(preference)
    if (nzchar(path)) return(preference)
  }

  for (engine in engines) {
    path <- Sys.which(engine)
    if (nzchar(path)) return(engine)
  }

  NULL
}

#' Build the container backend configuration
#'
#' Produces the container-specific settings that are merged into
#' `backend_config` (see [generate_template_variables()]) and consumed by
#' `inst/electron/backends/container.js` at runtime. The configured engine is
#' passed through as-is; image selection and engine auto-detection happen on
#' the end user's machine in `container.js`.
#'
#' @param config List. Full app configuration.
#' @param app_type Character or NULL. Application type (e.g. `"r-shiny"`,
#'   `"py-shiny"`). Used to resolve the runtime version for `container_tag`
#'   when no BYO image is configured. When NULL and no tag is configured,
#'   falls back to `"latest"`.
#' @return Named list of container settings.
#' @keywords internal
generate_container_config <- function(config, app_type = NULL) {
  container_cfg <- config$container %||% SHINYELECTRON_DEFAULTS$container

  container_tag <- if (!is.null(container_cfg$image)) {
    # BYO image: honour explicit tag or default to "latest"
    container_cfg$tag %||% "latest"
  } else if (!is.null(container_cfg$tag)) {
    # Our Dockerfile with an explicit tag configured
    container_cfg$tag
  } else if (!is.null(app_type)) {
    # Our Dockerfile: derive tag from the resolved runtime version
    rt <- if (grepl("^r-", app_type)) "r" else "python"
    resolve_runtime_version(rt, config)
  } else {
    "latest"
  }

  list(
    container_engine = container_cfg$engine %||%
      SHINYELECTRON_DEFAULTS$container$engine,
    container_image = container_cfg$image,
    container_tag = container_tag,
    pull_on_start = container_cfg$pull_on_start %||% TRUE,
    container_volumes = container_cfg$volumes %||% list(),
    container_env = container_cfg$env %||% list()
  )
}
