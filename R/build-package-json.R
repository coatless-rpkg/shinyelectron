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
#' @param icon Character string or NULL. Path to the app icon, which
#'   [copy_brand_assets()] copies to [icon_asset_path()]. Each platform in
#'   [icon_platforms()] gets that copy as its icon; the others, and every
#'   platform when `NULL`, use the default Electron icon.
#' @return Character string. The JSON content for package.json.
#' @keywords internal
generate_package_json <- function(app_slug, app_version, backend, config,
                                  icon = NULL, sign = FALSE,
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

  # Platform targets. On Windows the executable keeps the slug, so renaming
  # the app does not break pinned shortcuts, and updates reuse the folder an
  # existing install was registered with. The installer name adds "Setup".
  win_config <- list(
    target = "nsis",
    executableName = app_slug,
    artifactName = "${name}-Setup-${version}-${arch}.${ext}"
  )
  mac_config <- list(target = "dmg")
  # Electron names the window class (WM_CLASS) after app.name, the slug,
  # while electron-builder writes the product name into the desktop entry's
  # StartupWMClass; they must match for the launcher to group the windows.
  linux_config <- list(
    target = "AppImage",
    desktop = list(entry = list(StartupWMClass = app_slug))
  )

  # Name the copy of the icon that the build writes. A platform that cannot
  # use its format gets no icon, so electron-builder uses the default one
  # there instead of failing on the file.
  if (!is.null(icon)) {
    icon_path <- icon_asset_path(icon)
    platforms <- icon_platforms(icon)
    if ("win" %in% platforms) win_config$icon <- icon_path
    if ("mac" %in% platforms) mac_config$icon <- icon_path
    if ("linux" %in% platforms) linux_config$icon <- icon_path
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
    # and credentials from APPLE_TEAM_ID / APPLE_ID / APPLE_APP_SPECIFIC_PASSWORD;
    # build_for_platforms() passes a configured team id as APPLE_TEAM_ID.
    have_notarize_creds <- nzchar(Sys.getenv("APPLE_ID")) &&
      nzchar(Sys.getenv("APPLE_APP_SPECIFIC_PASSWORD"))
    if ((isTRUE(signing$mac$notarize) || have_notarize_creds) &&
        !is.null(team_id)) {
      mac_config$notarize <- TRUE
    }

    # Windows signing. electron-builder 26 reads signtool settings only from
    # win.signtoolOptions and rejects them directly under win. It validates
    # the whole config before building, so misplaced keys would fail builds
    # for every platform, not just Windows. The certificate password stays
    # out of package.json: electron-builder reads it from
    # WIN_CSC_KEY_PASSWORD or CSC_KEY_PASSWORD at build time.
    if (!is.null(signing$win$certificate_file)) {
      win_config$signtoolOptions <- list(
        certificateFile = signing$win$certificate_file,
        signingHashAlgorithms = list("sha256")
      )
    }
  } else {
    # Without Developer ID signing, still ad-hoc sign the macOS bundle so it
    # carries a valid signature. Apple Silicon rejects an unsealed bundle as
    # "damaged"; an ad-hoc signature ("-") lets the app launch through the
    # standard unidentified-developer prompt, with no certificate or
    # notarization. Windows and Linux stay unsigned.
    mac_config$identity <- "-"
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
#' Maps `installer.one_click`, `installer.allow_to_change_installation_directory`
#' and `installer.per_machine` onto electron-builder's `oneClick`,
#' `allowToChangeInstallationDirectory` and `perMachine`. Each option is
#' emitted only when the config sets it, so electron-builder's own defaults
#' apply otherwise: the one-click installer installs for the current user,
#' and the wizard (`one_click: false`) asks whether to install for all users
#' and does not offer a directory page. [validate_config()] has already
#' checked the values.
#'
#' `installer.license_file` becomes the NSIS `license`, pointing at the copy
#' that [copy_installer_license()] places in the generated project.
#'
#' @param config List. The effective configuration.
#' @return A named list for the package.json `build.nsis` field, empty when
#'   no installer option is set.
#' @keywords internal
build_nsis_config <- function(config) {
  installer <- config$installer
  nsis <- list()
  if (!is.null(installer$one_click)) {
    nsis$oneClick <- installer$one_click
  }
  if (!is.null(installer$allow_to_change_installation_directory)) {
    nsis$allowToChangeInstallationDirectory <-
      installer$allow_to_change_installation_directory
  }
  if (!is.null(installer$per_machine)) {
    nsis$perMachine <- installer$per_machine
  }
  if (!is.null(installer$license_file)) {
    nsis$license <- installer_license_path(installer$license_file)
  }
  nsis
}

#' Project path of the Windows installer license
#'
#' The license file is copied into the generated project's build resources
#' under a fixed name. Names that electron-builder finds on its own, such as
#' `license.txt` or `eula.txt`, are avoided because they would also add the
#' license to other targets, for example as a Linux AppImage EULA. The
#' extension is kept (lowercased) since electron-builder shows `.html`
#' licenses differently from plain text and RTF. electron-builder only
#' recognizes the `.html` suffix, so `.htm` becomes `.html`; a file without
#' an extension is treated as plain text.
#'
#' @param license_file Character. Path to the license file.
#' @return Character. The license path relative to the Electron project.
#' @keywords internal
installer_license_path <- function(license_file) {
  ext <- tolower(tools::file_ext(license_file))
  if (!nzchar(ext)) {
    ext <- "txt"
  } else if (ext == "htm") {
    ext <- "html"
  }
  paste0("build/installer-license.", ext)
}

#' Project path of the app icon
#'
#' [copy_brand_assets()] copies the app icon into the generated project
#' under this name, and package.json and `main.js` refer to the copy. The
#' extension is kept, lowercased: electron-builder recognizes the format of
#' an icon file only by a lower-case extension, and stops the build when
#' asked to make a Linux icon set from a file named, say, `icon.PNG`.
#'
#' @param icon Character. Path to the app icon.
#' @return Character. The icon path relative to the Electron project, such
#'   as `"assets/icon.png"`.
#' @keywords internal
icon_asset_path <- function(icon) {
  paste0("assets/icon.", tolower(tools::file_ext(icon)))
}

#' Platforms whose icon can come from the app icon
#'
#' electron-builder makes each platform's icon from the file it is given.
#' It converts a PNG to a macOS `.icns` file and a Windows `.ico` file, and
#' an `.icns` file to a Windows icon and a Linux icon set. It cannot make a
#' macOS icon or a Linux icon set from an `.ico` file, and stops the build
#' when asked to, so an `.ico` file serves Windows only. It also checks the
#' size: a PNG must be at least 512x512 pixels for macOS and 256x256 for
#' Windows and Linux. The format is read from the extension, ignoring case.
#'
#' @param icon Character. Path to the app icon.
#' @return Character vector of the platforms (`"win"`, `"mac"`, `"linux"`)
#'   that can use `icon`, empty for another format.
#' @keywords internal
icon_platforms <- function(icon) {
  switch(tolower(tools::file_ext(icon)),
    png = ,
    icns = c("win", "mac", "linux"),
    ico = "win",
    character(0)
  )
}
