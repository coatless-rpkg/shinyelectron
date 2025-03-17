#' Get or create cache directory path
#'
#' Determines the path to the cache directory for shinyelectron assets and
#' optionally creates the directory if it doesn't exist.
#'
#' @param create Logical. Whether to create the directory if it doesn't exist.
#'        Default is TRUE.
#'
#' @return Character string. The absolute path to the cache directory.
#'
#' @section Details:
#' The cache directory is located at \code{rappdirs::user_cache_dir("shinyelectron")/assets}.
#' This function centralizes path management for all cached assets used by the package.
#'
#' @section Cache Structure:
#' The cache directory structure (typically at ~/.shinyelectron/cache/assets/):
#' \preformatted{
#' assets/
#' |-- r/
#' |   |-- win/
#' |   |   |-- x64/
#' |   |   |-- arm64/
#' |   |-- mac/
#' |   |   |-- x64/
#' |   |   |-- arm64/
#' |   |-- linux/
#' |       |-- x64/
#' |       |-- arm64/
#' |-- npm/
#' }
#'
#' @keywords internal
cache_dir <- function(create = TRUE) {
  cache_dir <- fs::path(rappdirs::user_cache_dir("shinyelectron"), "assets")
  if (create && !fs::dir_exists(cache_dir)) {
    fs::dir_create(cache_dir, recurse = TRUE)
  }
  cache_dir
}

#' Get path to cached R installation
#'
#' Creates the path to a specific R installation in the cache based on version, 
#' platform, and architecture.
#'
#' @param version Character string. R version (e.g., "4.1.0").
#' @param platform Character string. Target platform ("win", "mac", or "linux").
#' @param arch Character string. Target architecture ("x64" or "arm64").
#'
#' @return Character string. The path to the cached R installation for the 
#'         specified version, platform, and architecture.
#'
#' @section Details:
#' The path is structured as \code{cache_dir()/r/[platform]/[arch]/[version]}.
#' This function does not check if the installation exists at that location.
#'
#' @keywords internal
cache_r_path <- function(version, platform, arch) {
  fs::path(cache_dir(), "r", platform, arch, version)
}

#' Get path to npm packages cache
#'
#' Determines the path to the cache directory for npm packages used by shinyelectron.
#'
#' @return Character string. The path to the npm packages cache.
#'
#' @section Details:
#' The npm packages are cached at \code{cache_dir()/npm}. This allows for reuse
#' of downloaded npm dependencies across multiple builds.
#'
#' @keywords internal
cache_npm_path <- function() {
  fs::path(cache_dir(), "npm")
}

#' Clear the asset cache
#'
#' Removes cached R installations and/or npm packages from the cache directory.
#'
#' @param what Character string. What to clear: "all" (default), "r", or "npm".
#'
#' @return Invisibly returns NULL.
#'
#' @section Details:
#' Use this function to free disk space or force re-downloading of assets:
#' \itemize{
#'   \item \code{"r"}: Removes only cached R installations
#'   \item \code{"npm"}: Removes only cached npm packages
#'   \item \code{"all"}: Removes both R installations and npm packages
#' }
#' If the cache directory doesn't exist, a message is shown and nothing is done.
#'
#' @examples
#' \dontrun{
#' # Clear everything in the cache
#' cache_clear()
#'
#' # Clear only R installations
#' cache_clear("r")
#'
#' # Clear only npm packages
#' cache_clear("npm")
#' }
#'
#' @export
cache_clear <- function(what = c("all", "r", "npm")) {
  what <- match.arg(what)
  dir <- cache_dir(create = FALSE)
  
  if (!fs::dir_exists(dir)) {
    cli::cli_alert_info("Cache directory doesn't exist: nothing to clear")
    return(invisible(NULL))
  }
  
  if (what %in% c("all", "r")) {
    r_path <- fs::path(dir, "r")
    if (fs::dir_exists(r_path)) {
      fs::dir_delete(r_path)
      cli::cli_alert_success("Cleared R installation cache")
    }
  }
  
  if (what %in% c("all", "npm")) {
    npm_path <- fs::path(dir, "npm")
    if (fs::dir_exists(npm_path)) {
      fs::dir_delete(npm_path)
      cli::cli_alert_success("Cleared npm packages cache")
    }
  }
  
  invisible(NULL)
}
