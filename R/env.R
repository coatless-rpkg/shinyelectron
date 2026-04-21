#' Get Node.js command
#'
#' Returns the path to the Node.js executable, preferring locally installed
#' versions managed by shinyelectron.
#'
#' @param prefer_local Logical. Whether to prefer the local shinyelectron-managed
#'   installation over the system installation. Default TRUE.
#' @return Character string path to node executable
#' @keywords internal
get_node_command <- function(prefer_local = TRUE) {
  if (prefer_local) {
    local_node <- nodejs_executable()
    if (!is.null(local_node) && fs::file_exists(local_node)) {
      return(local_node)
    }
  }

  # Fall back to system node
  if (Sys.info()[["sysname"]] == "Windows") {
    "node.exe"
  } else {
    "node"
  }
}

#' Get npm command
#'
#' Returns the path to the npm executable, preferring locally installed
#' versions managed by shinyelectron.
#'
#' @param prefer_local Logical. Whether to prefer the local shinyelectron-managed
#'   installation over the system installation. Default TRUE.
#' @return Character string path to npm executable
#' @keywords internal
get_npm_command <- function(prefer_local = TRUE) {
  if (prefer_local) {
    local_npm <- npm_executable()
    if (!is.null(local_npm) && fs::file_exists(local_npm)) {
      return(local_npm)
    }
  }

  # Fall back to system npm
  if (Sys.info()[["sysname"]] == "Windows") {
    "npm.cmd"
  } else {
    "npm"
  }
}

#' Set development environment variables
#'
#' @param port Integer port number
#' @param open_devtools Logical whether to open dev tools
#' @return Named list of old environment variables
#' @keywords internal
set_dev_environment <- function(port, open_devtools) {
  old_env <- list(
    ELECTRON_DEV_PORT = Sys.getenv("ELECTRON_DEV_PORT", NA),
    ELECTRON_DEV_TOOLS = Sys.getenv("ELECTRON_DEV_TOOLS", NA)
  )

  Sys.setenv(
    ELECTRON_DEV_PORT = as.character(port),
    ELECTRON_DEV_TOOLS = if (open_devtools) "true" else "false"
  )

  old_env
}

#' Restore environment variables
#'
#' @param old_env Named list of environment variables to restore
#' @keywords internal
restore_environment <- function(old_env) {
  for (var_name in names(old_env)) {
    old_value <- old_env[[var_name]]
    if (is.na(old_value)) {
      Sys.unsetenv(var_name)
    } else {
      do.call(Sys.setenv, stats::setNames(list(old_value), var_name))
    }
  }
}
