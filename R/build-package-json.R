#' Generate package.json content for Electron app
#'
#' Programmatically creates the package.json content based on the backend type
#' and configuration. This replaces the previous Whisker template approach
#' to avoid fragile JSON + Mustache comma handling.
#'
#' @param app_slug Character string. The slugified app name.
#' @param app_version Character string. The app version.
#' @param backend Character string. The backend module name without .js (e.g., "shinylive", "native-r").
#' @param config List. The effective configuration.
#' @param has_icon Logical. Whether an icon is provided.
#' @return Character string. The JSON content for package.json.
#' @keywords internal
generate_package_json <- function(app_slug, app_version, backend, config,
                                  has_icon = FALSE, sign = FALSE,
                                  is_multi_app = FALSE) {
  # Base structure
  pkg <- list(
    name = app_slug,
    version = app_version,
    description = paste0(app_slug, " - Shiny Electron App"),
    main = "main.js",
    # --publish never suppresses electron-builder's publish pipeline, which
    # 26.x crashes in ("Cannot read properties of null (reading 'channel')")
    # whenever the package.json has no publish or repository config. Local
    # builds never want publishing anyway; CI pipelines override with
    # --publish always.
    scripts = list(
      electron = "electron .",
      build = "electron-builder --publish never",
      `build-all` = "electron-builder -mwl --publish never",
      `build-win` = "electron-builder --win --publish never",
      `build-mac` = "electron-builder --mac --publish never",
      `build-linux` = "electron-builder --linux --publish never",
      `build-win-x64` = "electron-builder --win --x64 --publish never",
      `build-win-arm64` = "electron-builder --win --arm64 --publish never",
      `build-mac-x64` = "electron-builder --mac --x64 --publish never",
      `build-mac-arm64` = "electron-builder --mac --arm64 --publish never",
      `build-linux-x64` = "electron-builder --linux --x64 --publish never",
      `build-linux-arm64` = "electron-builder --linux --arm64 --publish never"
    ),
    author = "",
    license = "AGPL-3.0-or-later",
    devDependencies = list(
      electron = paste0("^", resolve_runtime_version("electron", config)),
      `electron-builder` = paste0("^", SHINYELECTRON_DEFAULTS$electron_toolchain$builder)
    )
  )

  # Dependencies vary by backend
  deps <- list()
  if (backend == "shinylive") {
    deps[["express"]] <- "^5.2.0"
    deps[["serve-static"]] <- "^2.2.0"
  }

  # Auto-update dependencies
  updates_enabled <- isTRUE(config$updates$enabled)
  if (updates_enabled) {
    deps[["electron-updater"]] <- paste0("^", SHINYELECTRON_DEFAULTS$electron_toolchain$updater)
    deps[["electron-log"]] <- paste0("^", SHINYELECTRON_DEFAULTS$electron_toolchain$log)
  }

  if (length(deps) > 0) {
    pkg$dependencies <- deps
  }

  # Build configuration
  build_config <- list(
    appId = config$installer$app_id %||% paste0("com.shinyelectron.", app_slug),
    productName = app_slug,
    directories = list(output = "dist")
  )

  # Publish config for auto-updates
  if (updates_enabled) {
    publish <- list(provider = config$updates$provider %||% "github")
    if (!is.null(config$updates$github$owner)) {
      publish$owner <- config$updates$github$owner
    }
    if (!is.null(config$updates$github$repo)) {
      publish$repo <- config$updates$github$repo
    }
    build_config$publish <- publish
  }

  # Files to include
  files <- c("main.js", "lifecycle.html", "preload.js",
             "src/**/*", "assets/**/*", "node_modules/**/*", "backends/**/*",
             "dockerfiles/**/*", "runtime/**/*")
  if (is_multi_app) {
    files <- c(files, "src/apps/**/*", "apps-manifest.json", "launcher.html")
  }
  build_config$files <- files

  # Unpack app files from ASAR so native R/Python/container backends
  # can access them on the real filesystem
  if (backend != "shinylive" || is_multi_app) {
    unpack <- list("src/app/**/*", "backends/**/*", "dockerfiles/**/*", "runtime/**/*")
    if (is_multi_app) {
      unpack <- c(unpack, "src/apps/**/*", "apps-manifest.json")
    }
    build_config$asarUnpack <- unpack
  }

  # Platform targets
  win_config <- list(target = "nsis")
  mac_config <- list(target = "dmg")
  linux_config <- list(target = "AppImage")

  if (has_icon) {
    win_config$icon <- "assets/icon.ico"
    mac_config$icon <- "assets/icon.icns"
    linux_config$icon <- "assets/icon.png"
  }

  # Code signing configuration
  if (sign) {
    signing <- config$signing %||% SHINYELECTRON_DEFAULTS$signing

    # macOS signing
    if (!is.null(signing$mac$identity)) {
      mac_config$identity <- signing$mac$identity
    }
    # Resolve the notarization team id from config, falling back to the
    # APPLE_TEAM_ID environment variable used in CI.
    team_id <- signing$mac$team_id
    if (is.null(team_id)) {
      env_team_id <- Sys.getenv("APPLE_TEAM_ID")
      if (nzchar(env_team_id)) team_id <- env_team_id
    }
    # Notarize when explicitly requested via config, or when notarization
    # credentials are present in the environment (the standard CI case).
    # electron-builder 26+ takes `notarize` as a boolean and reads the team id
    # and credentials from APPLE_TEAM_ID / APPLE_ID / APPLE_APP_SPECIFIC_PASSWORD.
    have_notarize_creds <- nzchar(Sys.getenv("APPLE_ID")) &&
      nzchar(Sys.getenv("APPLE_APP_SPECIFIC_PASSWORD"))
    if ((isTRUE(signing$mac$notarize) || have_notarize_creds) &&
        !is.null(team_id)) {
      mac_config$notarize <- TRUE
    }

    # Windows signing
    if (!is.null(signing$win$certificate_file)) {
      win_config$certificateFile <- signing$win$certificate_file
      win_config$signingHashAlgorithms <- list("sha256")
    }
  } else {
    # Without Developer ID signing, still ad-hoc sign the macOS bundle so it
    # carries a valid signature. Apple Silicon rejects an unsealed bundle as
    # "damaged"; an ad-hoc signature ("-") lets the app launch through the
    # standard unidentified-developer prompt, with no certificate or
    # notarization. Windows and Linux stay unsigned.
    mac_config$identity <- "-"
  }

  if (!is.null(config$installer$license_file)) {
    win_config$license <- config$installer$license_file
  }

  nsis_config <- build_nsis_config(config)
  if (length(nsis_config) > 0) {
    build_config$nsis <- nsis_config
  }

  build_config$win <- win_config
  build_config$mac <- mac_config
  build_config$linux <- linux_config

  pkg$build <- build_config

  jsonlite::toJSON(pkg, pretty = TRUE, auto_unbox = TRUE)
}

#' Build the electron-builder `nsis` block from installer config
#'
#' `one_click = TRUE` keeps the silent one-click install to the default
#' per-user location. `one_click = FALSE` uses the assisted wizard, where
#' `allow_to_change_installation_directory` (defaulting to TRUE in wizard
#' mode) lets the user choose where the application is installed.
#'
#' @param config List. The effective configuration.
#' @return A named list for the package.json `build.nsis` field.
#' @keywords internal
build_nsis_config <- function(config) {
  one_click <- config$installer$one_click
  nsis <- list()
  if (!is.null(one_click)) {
    nsis$oneClick <- isTRUE(one_click)
  }
  change_dir <- config$installer$allow_to_change_installation_directory
  if (is.null(change_dir)) {
    change_dir <- isFALSE(one_click)
  }
  if (is.logical(change_dir) && length(change_dir) == 1L && !is.na(change_dir)) {
    nsis$allowToChangeInstallationDirectory <- change_dir
  }
  per_machine <- config$installer$per_machine
  if (is.logical(per_machine) && length(per_machine) == 1L && !is.na(per_machine)) {
    nsis$perMachine <- per_machine
  }
  nsis
}
