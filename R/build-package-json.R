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
    scripts = list(
      electron = "electron .",
      build = "electron-builder",
      `build-all` = "electron-builder -mwl",
      `build-win` = "electron-builder --win",
      `build-mac` = "electron-builder --mac",
      `build-linux` = "electron-builder --linux",
      `build-win-x64` = "electron-builder --win --x64",
      `build-win-arm64` = "electron-builder --win --arm64",
      `build-mac-x64` = "electron-builder --mac --x64",
      `build-mac-arm64` = "electron-builder --mac --arm64",
      `build-linux-x64` = "electron-builder --linux --x64",
      `build-linux-arm64` = "electron-builder --linux --arm64"
    ),
    author = "",
    license = "AGPL (>=3)",
    devDependencies = list(
      electron = "^38.0.0",
      `electron-builder` = "^26.0.12"
    )
  )

  # Dependencies vary by backend
  deps <- list()
  if (backend == "shinylive") {
    deps[["express"]] <- "^5.1.0"
    deps[["serve-static"]] <- "^2.2.0"
  }

  # Auto-update dependencies
  updates_enabled <- isTRUE(config$updates$enabled)
  if (updates_enabled) {
    deps[["electron-updater"]] <- "^6.3.9"
    deps[["electron-log"]] <- "^5.2.4"
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
    if (isTRUE(signing$mac$notarize) && !is.null(signing$mac$team_id)) {
      mac_config$notarize <- list(teamId = signing$mac$team_id)
    }

    # Windows signing
    if (!is.null(signing$win$certificate_file)) {
      win_config$certificateFile <- signing$win$certificate_file
      win_config$signingHashAlgorithms <- list("sha256")
    }
  } else {
    # Explicitly disable signing
    mac_config$identity <- NULL
  }

  if (!is.null(config$installer$license_file)) {
    win_config$license <- config$installer$license_file
  }

  if (!is.null(config$installer$one_click)) {
    build_config$nsis <- list(oneClick = config$installer$one_click)
  }

  build_config$win <- win_config
  build_config$mac <- mac_config
  build_config$linux <- linux_config

  pkg$build <- build_config

  jsonlite::toJSON(pkg, pretty = TRUE, auto_unbox = TRUE)
}
