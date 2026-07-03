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

#' Environment for Node.js and npm child processes
#'
#' npm can be launched by its absolute path, but package lifecycle scripts
#' invoke `node` by name. When shinyelectron manages a Node.js install that is
#' not already on `PATH`, this makes that directory discoverable to npm and
#' every process it starts.
#'
#' The result uses processx's special `"current"` entry so the child inherits
#' the full parent environment with `PATH` extended, rather than replacing it.
#' Replacing it would drop variables that npm and electron-builder depend on
#' (for example `APPDATA` and `LOCALAPPDATA` on Windows, or `HOME` elsewhere).
#'
#' @return A character vector for the `env` argument of [processx::run()] and
#'   [run_command_safe()], or `NULL` when Node.js is already on `PATH` or cannot
#'   be resolved (the inherited environment is then used unchanged).
#' @keywords internal
nodejs_subprocess_env <- function() {
  node_cmd <- get_node_command(prefer_local = TRUE)
  # get_node_command() returns either an absolute path (a managed Node.js) or a
  # bare command name. Only treat an absolute path as a file; a bare name is
  # resolved on PATH via Sys.which() rather than matching a same-named file in
  # the working directory.
  node_path <- if (fs::is_absolute_path(node_cmd) && fs::file_exists(node_cmd)) {
    node_cmd
  } else {
    Sys.which(node_cmd)
  }

  if (!nzchar(node_path)) return(NULL)

  node_dir <- dirname(fs::path_abs(node_path))
  current_path <- Sys.getenv("PATH")
  path_entries <- strsplit(current_path, .Platform$path.sep, fixed = TRUE)[[1]]

  if (node_dir %in% path_entries) return(NULL)

  c("current", PATH = paste(node_dir, current_path, sep = .Platform$path.sep))
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
