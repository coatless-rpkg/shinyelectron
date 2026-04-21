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

#' Select the appropriate container image for an app type
#'
#' @param app_type Character string. The app type.
#' @param image Character string or NULL. Custom image override.
#' @param tag Character string. Image tag (default: "latest").
#' @return Character string. Full image reference.
#' @keywords internal
select_container_image <- function(app_type, image = NULL, tag = "latest") {
  if (!is.null(image)) {
    return(paste0(image, ":", tag))
  }

  base_image <- switch(app_type,
    "r-shiny" = "shinyelectron/r-shiny",
    "py-shiny" = "shinyelectron/py-shiny",
    "shinyelectron/r-py-shiny"
  )

  paste0(base_image, ":", tag)
}

#' Generate container configuration JSON
#'
#' Creates the backend config JSON that container.js reads at runtime.
#'
#' @param app_type Character string. The app type.
#' @param engine Character string. Container engine.
#' @param config List. Full app configuration.
#' @param app_slug Character string. Slugified app name.
#' @return Character string. JSON content.
#' @keywords internal
generate_container_config <- function(app_type, engine, config,
                                      app_slug = NULL) {
  container_cfg <- config$container %||% SHINYELECTRON_DEFAULTS$container

  result <- list(
    container_engine = engine,
    container_image = container_cfg$image,
    container_tag = container_cfg$tag %||% "latest",
    pull_on_start = container_cfg$pull_on_start %||% TRUE,
    container_volumes = container_cfg$volumes %||% list(),
    container_env = container_cfg$env %||% list(),
    app_type = app_type,
    app_slug = app_slug
  )

  jsonlite::toJSON(result, pretty = TRUE, auto_unbox = TRUE)
}
