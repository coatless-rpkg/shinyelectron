#' Configuration file name
#' @keywords internal
CONFIG_FILENAME <- "_shinyelectron.yml"

#' Get default configuration values
#'
#' Returns the default configuration used when no config file exists
#' or for values not specified in the config file.
#'
#' @return List of default configuration values
#' @keywords internal
default_config <- function() {
  list(
    app = list(
      name = NULL,
      slug = NULL,
      version = SHINYELECTRON_DEFAULTS$app_version,
      log_dir = SHINYELECTRON_DEFAULTS$logging$log_dir,
      log_level = SHINYELECTRON_DEFAULTS$logging$log_level
    ),
    build = list(
      type = NULL,
      runtime_strategy = NULL,
      platforms = NULL,
      architectures = NULL
    ),
    window = list(
      width = SHINYELECTRON_DEFAULTS$window_width,
      height = SHINYELECTRON_DEFAULTS$window_height
    ),
    server = list(
      port = SHINYELECTRON_DEFAULTS$server_port
    ),
    icons = list(
      mac = NULL,
      win = NULL,
      linux = NULL
    ),
    nodejs = list(
      version = NULL,
      auto_install = FALSE
    ),
    dependencies = SHINYELECTRON_DEFAULTS$dependencies,
    container = SHINYELECTRON_DEFAULTS$container,
    # New feature configurations
    splash = SHINYELECTRON_DEFAULTS$splash,
    tray = SHINYELECTRON_DEFAULTS$tray,
    menu = SHINYELECTRON_DEFAULTS$menu,
    updates = SHINYELECTRON_DEFAULTS$updates,
    preloader = SHINYELECTRON_DEFAULTS$preloader,
    signing = SHINYELECTRON_DEFAULTS$signing,
    lifecycle = SHINYELECTRON_DEFAULTS$lifecycle,
    installer = SHINYELECTRON_DEFAULTS$installer
  )
}

#' Find configuration file
#'
#' Searches for _shinyelectron.yml in the given directory.
#'
#' @param appdir Character path to app directory
#' @return Character path to config file, or NULL if not found
#' @keywords internal
find_config <- function(appdir) {
  config_path <- fs::path(appdir, CONFIG_FILENAME)

  if (fs::file_exists(config_path)) {
    return(config_path)
  }

  NULL
}

#' Read configuration file
#'
#' Reads and parses _shinyelectron.yml from the app directory.
#' If the file doesn't exist, returns default configuration.
#'
#' @param appdir Character path to app directory
#' @return List of configuration values (merged with defaults)
#' @keywords internal
read_config <- function(appdir) {
  config_path <- find_config(appdir)

  if (is.null(config_path)) {
    return(default_config())
  }

  tryCatch({
    config <- yaml::read_yaml(config_path)

    # Deep merge with defaults
    defaults <- default_config()
    merged <- merge_config_deep(defaults, config)

    # Validate
    validated <- validate_config(merged)

    return(validated)
  }, error = function(e) {
    cli::cli_warn(c(
      "Failed to parse configuration file: {.path {config_path}}",
      "i" = "Error: {e$message}",
      "i" = "Using default configuration"
    ))
    return(default_config())
  })
}

#' Deep merge two lists
#'
#' Recursively merges config into defaults, where config values override defaults.
#'
#' @param defaults List of default values
#' @param config List of config values to merge
#' @return Merged list
#' @keywords internal
merge_config_deep <- function(defaults, config) {
  if (is.null(config)) {
    return(defaults)
  }

  result <- defaults

  for (name in names(config)) {
    if (name %in% names(defaults) &&
        is.list(defaults[[name]]) &&
        is.list(config[[name]])) {
      # Recursively merge nested lists
      result[[name]] <- merge_config_deep(defaults[[name]], config[[name]])
    } else {
      # Override with config value
      result[[name]] <- config[[name]]
    }
  }

  result
}

#' Validate configuration values
#'
#' Checks configuration values and warns about invalid entries.
#'
#' @param config List of configuration values
#' @return List of validated configuration
#' @keywords internal
validate_config <- function(config) {
  # Use centralized constants
  valid_types <- SHINYELECTRON_DEFAULTS$valid_app_types
  valid_platforms <- SHINYELECTRON_DEFAULTS$valid_platforms
  valid_arch <- SHINYELECTRON_DEFAULTS$valid_architectures

  # Normalize legacy build.type values first (emits deprecation warning).
  if (!is.null(config$build$type) &&
      config$build$type %in% c("r-shinylive", "py-shinylive")) {
    legacy_normalized <- normalize_app_type_arg(
      config$build$type, config$build$runtime_strategy
    )
    config$build$type <- legacy_normalized$app_type
    config$build$runtime_strategy <- config$build$runtime_strategy %||% legacy_normalized$runtime_strategy
  }

  # Validate build type against the canonical set.
  if (!is.null(config$build$type) && !config$build$type %in% valid_types) {
    cli::cli_warn(c(
      "Invalid build type in config: {.val {config$build$type}}",
      "i" = "Valid types: {.val {valid_types}}",
      "i" = "Falling back to autodetection"
    ))
    config$build$type <- NULL
  }

  # Validate platforms
  if (!is.null(config$build$platforms)) {
    invalid <- config$build$platforms[!config$build$platforms %in% valid_platforms]
    if (length(invalid) > 0) {
      cli::cli_warn(c(
        "Invalid platform(s) in config: {.val {invalid}}",
        "i" = "Valid platforms: {.val {valid_platforms}}"
      ))
      config$build$platforms <- config$build$platforms[config$build$platforms %in% valid_platforms]
    }
  }

  # Validate architectures
  if (!is.null(config$build$architectures)) {
    invalid <- config$build$architectures[!config$build$architectures %in% valid_arch]
    if (length(invalid) > 0) {
      cli::cli_warn(c(
        "Invalid architecture(s) in config: {.val {invalid}}",
        "i" = "Valid architectures: {.val {valid_arch}}"
      ))
      config$build$architectures <- config$build$architectures[config$build$architectures %in% valid_arch]
    }
  }

  # Validate window dimensions using centralized defaults
  default_width <- SHINYELECTRON_DEFAULTS$window_width
  default_height <- SHINYELECTRON_DEFAULTS$window_height

  if (!is.null(config$window$width) && (!is.numeric(config$window$width) || config$window$width < 100)) {
    cli::cli_warn(c(
      "Invalid {.field window.width} in config: {.val {config$window$width}}",
      "i" = "Must be a number >= 100; using default: {.val {default_width}}",
      "i" = "Edit {.field window.width} in {.file _shinyelectron.yml}"
    ))
    config$window$width <- default_width
  }
  if (!is.null(config$window$height) && (!is.numeric(config$window$height) || config$window$height < 100)) {
    cli::cli_warn(c(
      "Invalid {.field window.height} in config: {.val {config$window$height}}",
      "i" = "Must be a number >= 100; using default: {.val {default_height}}",
      "i" = "Edit {.field window.height} in {.file _shinyelectron.yml}"
    ))
    config$window$height <- default_height
  }

  # Validate port using centralized default
  default_port <- SHINYELECTRON_DEFAULTS$server_port
  if (!is.null(config$server$port)) {
    if (!is.numeric(config$server$port) || config$server$port < 1 || config$server$port > 65535) {
      cli::cli_warn(c(
        "Invalid {.field server.port} in config: {.val {config$server$port}}",
        "i" = "Must be an integer between 1 and 65535; using default: {.val {default_port}}",
        "i" = "Edit {.field server.port} in {.file _shinyelectron.yml}"
      ))
      config$server$port <- default_port
    }
  }

  # Validate splash settings
  if (!is.null(config$splash)) {
    if (!is.null(config$splash$duration) && (!is.numeric(config$splash$duration) || config$splash$duration < 0)) {
      cli::cli_warn(c(
        "Invalid {.field splash.duration} in config: {.val {config$splash$duration}}",
        "i" = "Must be a non-negative number (milliseconds); using default: {.val {SHINYELECTRON_DEFAULTS$splash$duration}}"
      ))
      config$splash$duration <- SHINYELECTRON_DEFAULTS$splash$duration
    }
  }

  # Validate updates provider
  if (!is.null(config$updates) && !is.null(config$updates$provider)) {
    valid_providers <- c("github", "s3", "generic")
    if (!config$updates$provider %in% valid_providers) {
      cli::cli_warn(c(
        "Invalid updates provider: {.val {config$updates$provider}}",
        "i" = "Valid providers: {.val {valid_providers}}"
      ))
      config$updates$provider <- "github"
    }
  }

  # Validate menu template
  if (!is.null(config$menu) && !is.null(config$menu$template)) {
    valid_templates <- c("default", "minimal")
    if (!config$menu$template %in% valid_templates) {
      cli::cli_warn(c(
        "Invalid menu template: {.val {config$menu$template}}",
        "i" = "Valid templates: {.val {valid_templates}}"
      ))
      config$menu$template <- "default"
    }
  }

  # Validate preloader style
  if (!is.null(config$preloader) && !is.null(config$preloader$style)) {
    valid_styles <- c("spinner", "bar", "dots")
    if (!config$preloader$style %in% valid_styles) {
      cli::cli_warn(c(
        "Invalid preloader style: {.val {config$preloader$style}}",
        "i" = "Valid styles: {.val {valid_styles}}"
      ))
      config$preloader$style <- "spinner"
    }
  }

  config
}

#' Initialize configuration file
#'
#' Creates a template _shinyelectron.yml file in the specified directory.
#'
#' @param appdir Character path to app directory
#' @param app_name Character application name. If NULL, derived from directory name.
#' @param overwrite Logical whether to overwrite existing config. Default FALSE.
#' @param verbose Logical whether to show progress. Default TRUE.
#'
#' @return Invisibly returns the path to the created config file.
#'
#' @seealso [wizard()] for an interactive configuration generator;
#'   [show_config()] to display the merged effective configuration.
#'
#' @examples
#' \dontrun{
#' # Create config in app directory
#' init_config("path/to/my/app")
#'
#' # Create with custom name
#' init_config("path/to/app", app_name = "My Amazing App")
#' }
#'
#' @export
init_config <- function(appdir, app_name = NULL, overwrite = FALSE, verbose = TRUE) {
  validate_directory_exists(appdir, "Application directory")

  config_path <- fs::path(appdir, CONFIG_FILENAME)

  if (fs::file_exists(config_path) && !overwrite) {
    cli::cli_abort(c(
      "Configuration file already exists: {.path {config_path}}",
      "i" = "Use {.code overwrite = TRUE} to replace it"
    ))
  }

  # Derive app name from directory if not provided
  if (is.null(app_name)) {
    app_name <- basename(appdir)
  }

  # Sanitize app name for YAML
  app_name_safe <- gsub('"', '\\"', app_name)

  # Template content with all configuration sections
  template <- '# shinyelectron configuration file
# Documentation: https://r-pkg.thecoatlessprofessor.com/shinyelectron/

app:
  name: "{{{app_name}}}"
  version: "1.0.0"
  # Uncomment to set a custom URL-safe slug (default: derived from name)
  # slug: null
  # Uncomment to configure logging
  # log_dir: null            # null = default log directory
  # log_level: "info"        # "debug", "info", "warn", "error"

build:
  # type is autodetected from files in the app directory (app.R, ui.R/server.R, or app.py).
  # Uncomment to pin explicitly: "r-shiny" or "py-shiny".
  # type: "r-shiny"
  # runtime_strategy controls how R or Python reaches the end user.
  # Default is "shinylive" (in-browser WebAssembly, no runtime on disk).
  # Other options: "bundled", "system", "auto-download", "container".
  # runtime_strategy: "shinylive"
  # Uncomment to specify target platforms (default: current platform)
  # platforms:
  #   - mac
  #   - win
  #   - linux
  # architectures:
  #   - x64
  #   - arm64

window:
  width: 1200
  height: 800

server:
  port: 3838

# Uncomment to specify custom icons (platform-specific)
# icons:
#   mac: "icons/icon.icns"
#   win: "icons/icon.ico"
#   linux: "icons/icon.png"

nodejs:
  # Version to install (null = latest LTS)
  version: null
  # Set to true to auto-install Node.js if not found
  auto_install: false

# Dependency configuration
# Controls how R/Python package dependencies are handled
# dependencies:
#   auto_detect: true        # Automatically detect dependencies
#   extra_packages: []       # Additional packages to include
#   r:
#     packages: []           # Extra R packages
#     repos:
#       - "https://cloud.r-project.org"
#     lib_path: null              # null = R default, "app-local", or custom path
#   python:
#     packages: []           # Extra Python packages
#     index_urls:
#       - "https://pypi.org/simple"

# Container configuration (used when runtime_strategy is "container")
# container:
#   engine: "docker"         # "docker" or "podman"
#   image: null              # Docker image to use (null = auto-select)
#   tag: "latest"
#   pull_on_start: true      # Pull latest image when app starts
#   volumes: []              # Additional volume mounts
#   env: []                  # Additional environment variables

# Splash screen configuration
# Shown briefly while the runtime starts up
# splash:
#   enabled: true
#   duration: 1500          # Minimum display time in ms before transitioning out
#   background: null        # null = inherit from _brand.yml; or hex/CSS colour
#   image: null             # Path to a PNG logo (rendered up to 128 px square)
#   text: "Loading..."
#   text_color: "#333333"

# System tray configuration
# Enables minimize/close to tray and tray menu
# tray:
#   enabled: false
#   minimize_to_tray: true
#   close_to_tray: false
#   tooltip: null           # Uses app name if null
#   icon: null              # Uses app icon if null

# Application menu configuration
# menu:
#   enabled: true
#   template: "default"     # "default" or "minimal"
#   show_dev_tools: false
#   help_url: null

# Auto-update configuration
# Enables automatic app updates via GitHub Releases, S3, or HTTP
# updates:
#   enabled: false
#   provider: "github"      # "github", "s3", or "generic"
#   check_on_startup: true
#   auto_download: false
#   auto_install: false
#   github:
#     owner: null           # GitHub username/organization
#     repo: null            # Repository name
#     private: false

# Preloader configuration
# Shown after the splash, while the runtime emits status events
# preloader:
#   style: "spinner"        # "spinner", "bar", or "dots"
#   message: "Loading application..."
#   background: null        # null = inherit from _brand.yml; or hex/CSS colour

## Code Signing
## Set sign to true for distribution builds.
## macOS requires an Apple Developer account ($99/year) for code signing
## and notarization. Without it, Gatekeeper will block the app.
## Secrets are provided via environment variables:
##   APPLE_ID, APPLE_APP_SPECIFIC_PASSWORD, APPLE_TEAM_ID (macOS)
##   CSC_LINK, CSC_KEY_PASSWORD (macOS/Windows certificate)
##   GPG_KEY (Linux)
# signing:
#   sign: false
#   mac:
#     identity: null            # "Developer ID Application: Your Name (TEAMID)"
#     team_id: null             # Apple Team ID
#     notarize: false           # Notarize for Gatekeeper
#   win:
#     certificate_file: null    # Path to .pfx code signing certificate
#   linux:
#     gpg_sign: false           # GPG-sign AppImage

## Installer Branding
## Customize the installer appearance and behavior.
# installer:
#   app_id: null                  # null = "com.shinyelectron.<slug>"
#   license_file: null            # Path to license file (shown during install)
#   one_click: true               # Windows: true = silent install, false = wizard

## Lifecycle UI
## Controls the startup, loading, error, and shutdown experience.
# lifecycle:
#   show_phase_details: true
#   error_show_logs: true
#   shutdown_timeout: 10000
#   port_retry_count: 10
#   custom_splash_html: null
#   custom_error_html: null
#   prompt_before_install: false  # true = ask before installing packages
#   prompt_runtime_version: false # true = ask which R/Python version to use
'

  content <- whisker::whisker.render(template, list(app_name = app_name_safe))
  writeLines(content, config_path)

  if (verbose) {
    cli::cli_alert_success("Created configuration file: {.path {config_path}}")
    cli::cli_alert_info("Edit this file to customize your Electron app settings")
  }

  validate_config_file(config_path)

  invisible(config_path)
}

#' Validate a configuration file
#'
#' Checks a _shinyelectron.yml file for common issues and warns about them.
#'
#' @param config_path Character string. Path to the config file.
#' @return Invisible TRUE if valid, with warnings for issues.
#' @keywords internal
validate_config_file <- function(config_path) {
  if (!file.exists(config_path)) return(invisible(TRUE))

  config <- tryCatch(
    yaml::read_yaml(config_path),
    error = function(e) {
      cli::cli_warn(c(
        "Config file is not valid YAML",
        "x" = "Error: {e$message}",
        "i" = "Check for indentation issues or special characters"
      ))
      return(NULL)
    }
  )

  if (is.null(config)) return(invisible(FALSE))

  # Check for common mistakes. Legacy app_type values are accepted with a
  # deprecation warning; the normaliser emits its own message so we skip the
  # "unknown app type" warning for them here.
  if (!is.null(config$build$type)) {
    valid_types <- SHINYELECTRON_DEFAULTS$valid_app_types
    legacy_types <- c("r-shinylive", "py-shinylive")
    if (config$build$type %in% legacy_types) {
      normalize_app_type_arg(config$build$type, config$build$runtime_strategy)
    } else if (!config$build$type %in% valid_types) {
      cli::cli_warn("Unknown app type {.val {config$build$type}} in config. Valid types: {.val {valid_types}}")
    }
  }

  if (!is.null(config$build$runtime_strategy)) {
    valid_strategies <- SHINYELECTRON_DEFAULTS$valid_runtime_strategies
    if (!config$build$runtime_strategy %in% valid_strategies) {
      cli::cli_warn("Unknown runtime strategy {.val {config$build$runtime_strategy}}. Valid: {.val {valid_strategies}}")
    }
  }

  if (!is.null(config$server$port)) {
    port <- config$server$port
    if (!is.numeric(port) || port < 1 || port > 65535) {
      cli::cli_warn("Invalid port {.val {port}}. Must be between 1 and 65535")
    }
  }

  if (!is.null(config$container$engine)) {
    valid_engines <- SHINYELECTRON_DEFAULTS$valid_container_engines
    if (!config$container$engine %in% valid_engines) {
      cli::cli_warn("Unknown container engine {.val {config$container$engine}}. Valid: {.val {valid_engines}}")
    }
  }

  invisible(TRUE)
}

#' Show Effective Configuration
#'
#' Pretty-prints the merged effective configuration (params + config file + defaults)
#' for a shinyelectron app directory. Useful for debugging and verifying settings.
#'
#' @param appdir Character path to the app directory.
#' @return Invisibly returns the merged configuration list.
#'
#' @examples
#' \dontrun{
#' show_config("path/to/my/app")
#' }
#'
#' @export
show_config <- function(appdir = ".") {
  validate_directory_exists(appdir, "Application directory")

  config_path <- find_config(appdir)
  config <- read_config(appdir)

  cli::cli_h1("shinyelectron Configuration")

  if (!is.null(config_path)) {
    cli::cli_alert_info("Config file: {.path {config_path}}")
  } else {
    cli::cli_alert_warning("No config file found, showing defaults only")
  }

  cat("\n")

  # App section
  cli::cli_h2("Application")
  cli::cli_bullets(c(
    "*" = "Name: {.val {config$app$name %||% basename(appdir)}}",
    "*" = "Version: {.val {config$app$version %||% '1.0.0'}}",
    "*" = "Slug: {.val {config$app$slug %||% slugify(config$app$name %||% basename(appdir))}}"
  ))

  # Build section
  cli::cli_h2("Build")
  cli::cli_bullets(c(
    "*" = "Type: {.val {config$build$type %||% '(autodetect)'}}",
    "*" = "Runtime strategy: {.val {config$build$runtime_strategy %||% 'shinylive'}}",
    "*" = "Platforms: {.val {config$build$platforms %||% detect_current_platform()}}",
    "*" = "Architectures: {.val {config$build$architectures %||% detect_current_arch()}}"
  ))

  # Window section
  cli::cli_h2("Window")
  cli::cli_bullets(c(
    "*" = "Size: {config$window$width %||% 1200}x{config$window$height %||% 800}",
    "*" = "Port: {config$server$port %||% 3838}"
  ))

  # Features section
  cli::cli_h2("Features")
  cli::cli_bullets(c(
    "*" = "Tray: {.val {isTRUE(config$tray$enabled)}}",
    "*" = "Menu: {.val {config$menu$enabled %||% TRUE}}",
    "*" = "Auto-updates: {.val {isTRUE(config$updates$enabled)}}",
    "*" = "Code signing: {.val {isTRUE(config$signing$sign)}}"
  ))

  # Lifecycle section
  lifecycle <- config$lifecycle %||% SHINYELECTRON_DEFAULTS$lifecycle
  cli::cli_h2("Lifecycle")
  cli::cli_bullets(c(
    "*" = "Prompt before install: {.val {isTRUE(lifecycle$prompt_before_install)}}",
    "*" = "Prompt runtime version: {.val {isTRUE(lifecycle$prompt_runtime_version)}}",
    "*" = "Custom splash: {.val {!is.null(lifecycle$custom_splash_html)}}",
    "*" = "Port retry count: {.val {lifecycle$port_retry_count %||% 10}}"
  ))

  invisible(config)
}

#' Read _brand.yml file
#'
#' Reads a _brand.yml file from the app directory for visual customization.
#' Follows the Posit brand.yml specification.
#'
#' @param appdir Character string. Path to the app directory.
#' @return List with brand settings, or NULL if no file found.
#' @keywords internal
read_brand_yml <- function(appdir) {
  brand_file <- file.path(appdir, "_brand.yml")
  if (!file.exists(brand_file)) return(NULL)
  tryCatch(
    yaml::read_yaml(brand_file),
    error = function(e) {
      cli::cli_warn(c(
        "Failed to parse {.file {brand_file}}",
        "x" = "{e$message}",
        "i" = "Check YAML syntax and indentation",
        "i" = "Using default branding"
      ))
      NULL
    }
  )
}
