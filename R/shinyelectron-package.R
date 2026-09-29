# cli_abort(), cli_warn() and cli_inform() call rlang, but cli only suggests
# it, so rlang is listed in Imports to guarantee it is installed. Nothing here
# calls rlang directly; this import stops R CMD check from flagging it as an
# unused Import.
#' @importFrom rlang abort
NULL
