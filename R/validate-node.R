#' Validate Node.js and npm availability
#'
#' Checks for Node.js and npm, preferring locally installed versions
#' managed by shinyelectron over system installations.
#'
#' @return Invisibly returns a list with node and npm paths and versions.
#' @keywords internal
validate_node_npm <- function() {
  node_cmd <- get_node_command(prefer_local = TRUE)
  npm_cmd <- get_npm_command(prefer_local = TRUE)
  using_local <- nodejs_is_installed()

  node_result <- run_command_safe(node_cmd, "--version")

  if (node_result$status != 0) {
    cli::cli_abort(c(
      "Node.js is required but not found",
      "i" = "Install locally with: {.code shinyelectron::install_nodejs()}",
      "i" = "Or install system-wide from https://nodejs.org/"
    ))
  }

  npm_result <- run_command_safe(npm_cmd, "--version")

  if (npm_result$status != 0) {
    cli::cli_abort(c(
      "npm is required but not found",
      "i" = "npm should be installed with Node.js",
      "i" = "Try: {.code shinyelectron::install_nodejs()}"
    ))
  }

  invisible(list(
    node_path = node_cmd,
    node_version = trimws(gsub("^v", "", node_result$stdout)),
    npm_path = npm_cmd,
    npm_version = trimws(npm_result$stdout),
    using_local = using_local
  ))
}
