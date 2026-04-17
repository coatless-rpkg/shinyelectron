#' Interactive Configuration Wizard
#'
#' Walks through setup questions and generates a _shinyelectron.yml
#' configuration file for your Shiny app.
#'
#' @param appdir Character string. Path to the app directory. Default ".".
#' @return Invisible path to the generated config file.
#'
#' @examples
#' \dontrun{
#' wizard("path/to/my/app")
#' }
#'
#' @export
wizard <- function(appdir = ".") {
  if (!interactive()) {
    cli::cli_abort("wizard() must be run interactively")
  }

  cli::cli_h1("shinyelectron Configuration Wizard")
  cli::cli_alert_info("This will create a {.file _shinyelectron.yml} in {.path {appdir}}")
  cat("\n")

  # App name
  default_name <- basename(normalizePath(appdir, mustWork = FALSE))
  app_name <- readline(paste0("App name [", default_name, "]: "))
  if (!nzchar(app_name)) app_name <- default_name

  # App version
  app_version <- readline("App version [1.0.0]: ")
  if (!nzchar(app_version)) app_version <- "1.0.0"

  # App type
  cat("\nApp types:\n")
  cat("  1. r-shinylive  -- R Shiny in browser (recommended, no runtime needed)\n")
  cat("  2. r-shiny      -- Native R Shiny (requires R on user's machine)\n")
  cat("  3. py-shinylive -- Python Shiny in browser\n")
  cat("  4. py-shiny     -- Native Python Shiny\n")
  type_choice <- readline("Choose app type [1]: ")
  app_type <- switch(type_choice,
    "2" = "r-shiny", "3" = "py-shinylive", "4" = "py-shiny",
    "r-shinylive"
  )

  # Runtime strategy (only for native types)
  runtime_strategy <- NULL
  if (app_type %in% NATIVE_TYPES) {
    cat("\nRuntime strategies:\n")
    cat("  1. auto-download -- Download runtime on first launch (recommended)\n")
    cat("  2. system        -- Use R/Python already installed on user's machine\n")
    cat("  3. bundled       -- Embed runtime in app (large but self-contained)\n")
    cat("  4. container     -- Run in Docker/Podman container\n")
    strategy_choice <- readline("Choose runtime strategy [1]: ")
    runtime_strategy <- switch(strategy_choice,
      "2" = "system", "3" = "bundled", "4" = "container",
      "auto-download"
    )
  }

  # Platforms
  cat("\nTarget platforms (comma-separated):\n")
  cat("  mac, win, linux\n")
  platform_input <- readline("Platforms [mac]: ")
  if (!nzchar(platform_input)) platform_input <- "mac"
  platforms <- trimws(strsplit(platform_input, ",")[[1]])

  # Window dimensions
  width <- readline("Window width [1200]: ")
  if (!nzchar(width)) width <- "1200"
  height <- readline("Window height [800]: ")
  if (!nzchar(height)) height <- "800"

  # Port
  port <- readline("Server port [3838]: ")
  if (!nzchar(port)) port <- "3838"

  # --- Advanced options ---
  cat("\n")
  advanced <- readline("Configure advanced options (signing, tray, updates)? [y/N]: ")
  do_advanced <- tolower(advanced) %in% c("y", "yes")

  # Code signing
  sign_enabled <- FALSE
  signing_config <- NULL
  if (do_advanced) {
    cat("\n")
    cli::cli_h2("Code Signing")
    sign_input <- readline("Enable code signing for distribution? [y/N]: ")
    sign_enabled <- tolower(sign_input) %in% c("y", "yes")
    if (sign_enabled) {
      signing_config <- list(sign = TRUE)
      if ("mac" %in% platforms) {
        notarize <- readline("  Enable macOS notarization? [y/N]: ")
        signing_config$mac <- list(notarize = tolower(notarize) %in% c("y", "yes"))
      }
    }
  }

  # System tray
  tray_config <- NULL
  if (do_advanced) {
    cat("\n")
    cli::cli_h2("System Tray")
    tray_input <- readline("Enable system tray icon? [y/N]: ")
    if (tolower(tray_input) %in% c("y", "yes")) {
      close_to_tray <- readline("  Close to tray instead of quitting? [y/N]: ")
      tray_config <- list(
        enabled = TRUE,
        close_to_tray = tolower(close_to_tray) %in% c("y", "yes")
      )
    }
  }

  # Auto-updates
  updates_config <- NULL
  if (do_advanced) {
    cat("\n")
    cli::cli_h2("Auto-Updates")
    updates_input <- readline("Enable auto-updates? [y/N]: ")
    if (tolower(updates_input) %in% c("y", "yes")) {
      cat("  Update providers:\n")
      cat("    1. GitHub Releases (recommended for open source)\n")
      cat("    2. S3 bucket\n")
      cat("    3. Generic HTTP server\n")
      provider_choice <- readline("  Choose provider [1]: ")
      provider <- switch(provider_choice,
        "2" = "s3", "3" = "generic", "github"
      )
      updates_config <- list(enabled = TRUE, provider = provider)
      if (provider == "github") {
        owner <- readline("  GitHub owner/org: ")
        repo <- readline("  GitHub repo name: ")
        if (nzchar(owner) && nzchar(repo)) {
          updates_config$github <- list(owner = owner, repo = repo)
        }
      }
    }
  }

  # Dependency management (native types only)
  deps_config <- NULL
  if (app_type %in% NATIVE_TYPES && do_advanced) {
    cat("\n")
    cli::cli_h2("Dependencies")
    prompt_install <- readline("Prompt user before installing packages? [y/N]: ")
    prompt_runtime <- readline("Let user pick runtime version? [y/N]: ")
    if (tolower(prompt_install) %in% c("y", "yes") ||
        tolower(prompt_runtime) %in% c("y", "yes")) {
      deps_config <- list(
        prompt_before_install = tolower(prompt_install) %in% c("y", "yes"),
        prompt_runtime_version = tolower(prompt_runtime) %in% c("y", "yes")
      )
    }
  }

  # Build the YAML content
  config <- list(
    app = list(name = app_name, version = app_version),
    build = list(type = app_type, platforms = platforms)
  )

  if (!is.null(runtime_strategy)) {
    config$build$runtime_strategy <- runtime_strategy
  }

  config$window <- list(width = as.integer(width), height = as.integer(height))
  config$server <- list(port = as.integer(port))

  if (!is.null(signing_config)) config$signing <- signing_config
  if (!is.null(tray_config)) config$tray <- tray_config
  if (!is.null(updates_config)) config$updates <- updates_config
  if (!is.null(deps_config)) config$lifecycle <- deps_config

  # Write the config
  config_path <- file.path(appdir, "_shinyelectron.yml")

  if (file.exists(config_path)) {
    overwrite <- readline("Config file already exists. Overwrite? [y/N]: ")
    if (!tolower(overwrite) %in% c("y", "yes")) {
      cli::cli_alert_info("Aborted. Existing config unchanged.")
      return(invisible(NULL))
    }
  }

  yaml::write_yaml(config, config_path)

  cli::cli_alert_success("Created {.file {config_path}}")
  cat("\n")
  cli::cli_alert_info("Next steps:")
  cli::cli_alert_info("  1. Review and edit {.file _shinyelectron.yml}")
  cli::cli_alert_info("  2. Run {.code app_check(\"{appdir}\")} to validate")
  cli::cli_alert_info("  3. Run {.code export(\"{appdir}\", \"output\")} to build")

  invisible(config_path)
}
