# App type group constants — use these instead of inline c("r-shinylive", ...)
SHINYLIVE_TYPES <- c("r-shinylive", "py-shinylive")
NATIVE_TYPES    <- c("r-shiny", "py-shiny")
R_TYPES         <- c("r-shinylive", "r-shiny")
PY_TYPES        <- c("py-shinylive", "py-shiny")
ALL_APP_TYPES   <- c(SHINYLIVE_TYPES, NATIVE_TYPES)

#' Default configuration values for shinyelectron
#'
#' A list containing all default values used when no configuration file
#' exists or when specific values are not provided.
#'
#' @format A named list with the following elements:
#' \describe{
#'   \item{window_width}{Default window width in pixels (1200)}
#'   \item{window_height}{Default window height in pixels (800)}
#'   \item{server_port}{Default local server port (3838)}
#'   \item{app_version}{Default application version ("1.0.0")}
#'   \item{valid_app_types}{Valid application types}
#'   \item{valid_platforms}{Valid target platforms}
#'   \item{valid_architectures}{Valid CPU architectures}
#'   \item{splash}{Default splash screen settings}
#'   \item{tray}{Default system tray settings}
#'   \item{menu}{Default application menu settings}
#'   \item{updates}{Default auto-update settings}
#'   \item{preloader}{Default preloader settings}
#'   \item{installer}{Default installer branding settings}
#' }
#' @keywords internal
SHINYELECTRON_DEFAULTS <- list(
  # Window dimensions
  window_width = 1200L,

  window_height = 800L,

  # Server settings
  server_port = 3838L,

  # App metadata
  app_version = "1.0.0",

  # Valid options for validation

valid_app_types = c(
    "r-shinylive",
    "r-shiny",
    "py-shinylive",
    "py-shiny"
  ),

  valid_platforms = c(
    "win",
    "mac",
    "linux"
  ),

  valid_architectures = c(
    "x64",
    "arm64"
  ),

  # Runtime strategy options (for native app types)
  valid_runtime_strategies = c(
    "bundled",
    "system",
    "auto-download",
    "container"
  ),

  # Container engine options
  valid_container_engines = c(
    "docker",
    "podman"
  ),

  # Splash screen defaults
  splash = list(
    enabled = FALSE,
    duration = 3000L,
    background = "#ffffff",
    image = NULL,
    width = 400L,
    height = 300L,
    text = "Loading...",
    text_color = "#333333"
  ),

  # System tray defaults
  tray = list(
    enabled = FALSE,
    minimize_to_tray = TRUE,
    close_to_tray = FALSE,
    tooltip = NULL,  # Uses app_name if NULL
    icon = NULL      # Uses app icon if NULL
  ),

  # Application menu defaults
  menu = list(
    enabled = TRUE,
    template = "default",  # "default", "minimal", or "custom"
    show_dev_tools = FALSE,
    help_url = NULL
  ),

  # Auto-update defaults
  updates = list(
    enabled = FALSE,
    provider = "github",  # "github", "s3", "generic"
    check_on_startup = TRUE,
    auto_download = FALSE,
    auto_install = FALSE,
    github = list(
      owner = NULL,
      repo = NULL,
      private = FALSE
    ),
    s3 = list(
      bucket = NULL,
      region = "us-east-1",
      path = "/"
    ),
    generic = list(
      url = NULL
    )
  ),

  # Preloader defaults
  preloader = list(
    enabled = TRUE,
    style = "spinner",  # "spinner", "bar", "dots"
    message = "Loading application...",
    background = "#f8f9fa"
  ),

  # Container defaults
  container = list(
    engine = "docker",
    image = NULL,
    tag = "latest",
    pull_on_start = TRUE,
    volumes = list(),
    env = list()
  ),

  # Dependency defaults
  dependencies = list(
    auto_detect = TRUE,
    extra_packages = list(),
    r = list(
      packages = list(),
      repos = list("https://cloud.r-project.org"),
      lib_path = NULL
    ),
    python = list(
      packages = list(),
      index_urls = list("https://pypi.org/simple"),
      lib_path = NULL
    )
  ),

  # Logging defaults
  logging = list(
    log_dir = NULL,
    log_level = "info"
  ),

  # Code signing defaults
  signing = list(
    sign = FALSE,
    mac = list(
      identity = NULL,
      team_id = NULL,
      notarize = FALSE
    ),
    win = list(
      certificate_file = NULL
    ),
    linux = list(
      gpg_sign = FALSE
    )
  ),

  lifecycle = list(
    splash_min_duration = 1500L,
    show_phase_details = TRUE,
    error_show_logs = TRUE,
    shutdown_timeout = 10000L,
    port_retry_count = 10L,
    custom_splash_html = NULL,
    custom_error_html = NULL,
    prompt_before_install = FALSE,
    prompt_runtime_version = FALSE
  ),

  installer = list(
    app_id = NULL,
    license_file = NULL,
    one_click = TRUE
  )
)

#' Get a default value
#'
#' Retrieves a default value from SHINYELECTRON_DEFAULTS.
#'
#' @param key Character name of the default to retrieve
#' @param default Value to return if key not found
#' @return The default value
#' @keywords internal
get_default <- function(key, default = NULL) {
  if (key %in% names(SHINYELECTRON_DEFAULTS)) {
    SHINYELECTRON_DEFAULTS[[key]]
  } else {
    default
  }
}
