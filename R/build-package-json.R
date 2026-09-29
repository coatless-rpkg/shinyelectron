#' Generate package.json content for Electron app
#'
#' Programmatically creates the package.json content based on the backend type
#' and configuration. This replaces the previous Whisker template approach
#' to avoid fragile JSON + Mustache comma handling.
#'
#' @param app_slug Character string. The slugified app name.
#' @param app_version Character string. The app version.
#' @param app_name Character string or NULL. Display name, used as the
#'   electron-builder productName. `NULL` uses the slug.
#' @param backend Character string. The backend module name without .js (e.g., "shinylive", "native-r").
#' @param config List. The effective configuration.
#' @param has_icon Logical. Whether an icon is provided.
#' @return Character string. The JSON content for package.json.
#' @keywords internal
generate_package_json <- function(app_slug, app_version, backend, config,
                                  has_icon = FALSE, sign = FALSE,
                                  is_multi_app = FALSE, app_name = NULL) {
  metadata <- app_metadata(config)
  # electron-builder writes the product name, the copyright, and the author's
  # name into double-quoted Windows installer strings without escaping them,
  # so their straight double quotes become typographic ones (see
  # smart_quotes()). It already does this for the description.
  author <- metadata$author
  if (!is.null(author)) author$name <- smart_quotes(author$name)

  # Base structure
  pkg <- list(
    name = app_slug,
    version = app_version,
    description = metadata$description %||% paste0(app_slug, " - Shiny Electron App"),
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
    # npm's object form of a person, leaving out unset fields.
    author = if (is.null(author)) "" else Filter(Negate(is.null), author),
    license = "AGPL-3.0-or-later",
    devDependencies = list(
      electron = paste0("^", resolve_runtime_version("electron", config)),
      `electron-builder` = paste0("^", SHINYELECTRON_DEFAULTS$electron_toolchain$builder)
    )
  )
  # electron-builder links the homepage from the Windows uninstall entry.
  pkg$homepage <- metadata$homepage

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

  # Build configuration. The display name labels the installed app (the
  # macOS .app, the Windows shortcuts and uninstall entry); file names keep
  # the slug.
  build_config <- list(
    appId = config$installer$app_id %||% paste0("com.shinyelectron.", app_slug),
    productName = smart_quotes(app_name %||% app_slug),
    # ${name} is the package.json name, the slug, so installer names are safe
    # for GitHub Releases. ${arch} keeps the build of each architecture, all
    # written to the same dist/, from overwriting another.
    artifactName = "${name}-${version}-${arch}.${ext}",
    directories = list(output = "dist")
  )
  # The copyright goes into the Windows file properties and the macOS
  # Info.plist, which the native About panel reads. Unset, electron-builder
  # writes a default notice with the year and the author name (or productName).
  build_config$copyright <- smart_quotes(metadata$copyright)

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

  # Platform targets. On Windows the executable, and with it the install
  # folder, keeps the slug, so renaming the app does not break pinned
  # shortcuts or move existing installs; the installer name adds "Setup".
  win_config <- list(
    target = "nsis",
    executableName = app_slug,
    artifactName = "${name}-Setup-${version}-${arch}.${ext}"
  )
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

  if (!is.null(config$installer$one_click)) {
    build_config$nsis <- list(oneClick = config$installer$one_click)
  }

  build_config$win <- win_config
  build_config$mac <- mac_config
  build_config$linux <- linux_config

  pkg$build <- build_config

  jsonlite::toJSON(pkg, pretty = TRUE, auto_unbox = TRUE)
}
