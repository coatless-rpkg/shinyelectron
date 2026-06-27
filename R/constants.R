# Schema version for R to JS manifest files (dependencies.json,
# runtime-manifest.json, apps-manifest.json). Bump when the shape of
# any manifest changes in a backwards-incompatible way. The JS side
# warns on mismatch; see inst/electron/backends/utils.js.
MANIFEST_SCHEMA_VERSION <- "1"

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
#'   \item{valid_runtime_strategies}{Valid runtime strategies}
#'   \item{valid_container_engines}{Valid container engines}
#'   \item{splash}{Default splash screen settings}
#'   \item{tray}{Default system tray settings}
#'   \item{menu}{Default application menu settings}
#'   \item{updates}{Default auto-update settings}
#'   \item{preloader}{Default preloader settings}
#'   \item{container}{Default container strategy settings}
#'   \item{dependencies}{Default dependency detection and runtime settings}
#'   \item{logging}{Default logging settings}
#'   \item{signing}{Default code-signing settings}
#'   \item{lifecycle}{Default lifecycle and prompt settings}
#'   \item{installer}{Default installer branding settings}
#'   \item{runtime_versions}{Maintained "latest known" runtime version pins (r, python, electron)}
#'   \item{electron_toolchain}{Pinned versions for electron-builder, electron-updater, electron-log (not config-settable)}
#'   \item{dependencies$electron}{Default Electron dependency settings; \code{version} is NULL (use pin) or a version string}
#'   \item{dependencies$system_packages}{Default system package list (NULL)}
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
    "r-shiny",
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

  # Runtime strategy options
  valid_runtime_strategies = c(
    "shinylive",
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
    enabled = TRUE,
    duration = 1500L,    # minimum display time in ms before transitioning out
    background = NULL,   # null falls back to brand_background
    image = NULL,
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
    template = "default",  # "default" or "minimal"
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
    style = "spinner",  # "spinner", "bar", "dots"
    message = "Loading application...",
    background = NULL   # null falls back to brand_background
  ),

  # Container defaults
  container = list(
    engine = "docker",
    image = NULL,
    tag = NULL,
    pull_on_start = TRUE,
    volumes = list(),
    env = list()
  ),

  # Dependency defaults
  dependencies = list(
    auto_detect = TRUE,
    extra_packages = list(),
    r = list(
      version = NULL,   # NULL = latest R; pin to embed a specific version
      packages = list(),
      repos = list("https://cloud.r-project.org"),
      lib_path = NULL
    ),
    python = list(
      version = NULL,   # NULL = default Python; pin to embed a specific version
      packages = list(),
      index_urls = list("https://pypi.org/simple")
    ),
    electron = list(version = NULL),
    system_packages = NULL
  ),

  # Maintained "latest known" runtime pins. SINGLE SOURCE OF TRUTH.
  # To bump: set these to the values returned by r_portable_latest_version(),
  # python_resolve_pbs("latest"), and electron_latest_version(), then rebuild.
  runtime_versions = list(
    r        = "4.6.1",
    python   = list(version = "3.14.6", release = "20260623"),
    electron = "41.0.0"
  ),

  # Pinned versions for the Electron support toolchain. These are NOT
  # config-settable; bump here when upgrading the build toolchain.
  electron_toolchain = list(
    builder = "26.8.0",   # electron-builder (current "^26.8.0")
    updater = "6.8.0",    # electron-updater (current "^6.8.0")
    log     = "5.4.0"     # electron-log    (current "^5.4.0")
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
    show_phase_details = TRUE,
    error_show_logs = TRUE,
    shutdown_timeout = 10000L,
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
