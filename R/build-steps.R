#' Install npm dependencies
#'
#' @param output_dir Character Electron project directory
#' @param verbose Logical whether to show progress
#' @keywords internal
install_npm_dependencies <- function(output_dir, verbose = TRUE) {
  if (verbose) {
    cli::cli_alert_info("Installing npm dependencies...")
  }

  # Run npm install
  result <- processx::run(
    command = get_npm_command(),
    args = c("install"),
    wd = output_dir,
    echo = verbose,
    spinner = verbose,
    error_on_status = FALSE
  )

  if (result$status != 0) {
    cli::cli_abort(c(
      "Failed to install npm dependencies",
      "x" = "Command: npm install",
      "x" = "Exit code: {result$status}",
      "x" = "Error: {result$stderr}",
      "",
      "i" = "Common causes:",
      "i" = "1. Node.js not properly installed",
      "i" = "2. Network connection issues",
      "i" = "3. npm cache corruption",
      "",
      "i" = "Try running: {.code shinyelectron::sitrep_electron_system()}",
      "i" = "Or clear npm cache: {.code npm cache clean --force}"
    ))
  }

  if (verbose) {
    cli::cli_alert_success("Installed npm dependencies")
  }
}


#' Check whether electron-builder produced output for a platform
#'
#' electron-builder 26.x has a known bug where the build completes and the
#' installer is written to disk, but the process then exits with status 1
#' during post-build publish metadata. When that happens, processx-invoked
#' npm inherits the non-zero exit even though the .dmg/.exe/.AppImage is
#' sitting right there. We treat "artifact exists" as success.
#'
#' @param output_dir Character Electron project directory
#' @param p Character platform identifier (`"mac"`, `"win"`, or `"linux"`)
#' @return Logical: `TRUE` if a platform-specific installer is present.
#' @keywords internal
dist_has_platform_artifact <- function(output_dir, p) {
  dist_dir <- fs::path(output_dir, "dist")
  if (!fs::dir_exists(dist_dir)) return(FALSE)

  # Platform-specific installer extensions
  patterns <- switch(p,
    mac = c("\\.dmg$", "\\.zip$", "^mac(-arm64|-x64)?$"),
    win = c("\\.exe$", "\\.msi$", "^win(-arm64|-x64|-unpacked)?$"),
    linux = c("\\.AppImage$", "\\.deb$", "\\.rpm$", "\\.snap$", "^linux(-arm64|-x64|-unpacked)?$"),
    character(0)
  )
  if (length(patterns) == 0) return(FALSE)

  entries <- list.files(dist_dir, recursive = FALSE)
  any(vapply(patterns, function(pat) any(grepl(pat, entries, ignore.case = TRUE)),
             logical(1)))
}

#' Build for target platforms
#'
#' @param output_dir Character Electron project directory
#' @param platform Character vector of target platforms
#' @param arch Character vector of target architectures
#' @param sign Logical whether to code-sign the build
#' @param verbose Logical whether to show progress
#' @keywords internal
build_for_platforms <- function(output_dir, platform, arch, sign = FALSE, verbose = TRUE) {
  if (verbose) {
    cli::cli_alert_info("Building for platforms: {paste(platform, collapse = ', ')}")
  }

  # Check package.json exists and has necessary scripts
  package_json_path <- fs::path(output_dir, "package.json")
  if (!fs::file_exists(package_json_path)) {
    cli::cli_abort("No package.json found in: {.path {output_dir}}")
  }

  package_json <- jsonlite::fromJSON(package_json_path, simplifyVector = FALSE)
  available_scripts <- names(package_json$scripts %||% list())

  if (verbose) {
    cli::cli_alert_info("Available npm scripts: {paste(available_scripts, collapse = ', ')}")
  }

  # Prevent auto-discovery of signing certificates for unsigned builds
  if (!isTRUE(sign)) {
    old_csc <- Sys.getenv("CSC_IDENTITY_AUTO_DISCOVERY", NA)
    Sys.setenv(CSC_IDENTITY_AUTO_DISCOVERY = "false")
    on.exit({
      if (is.na(old_csc)) {
        Sys.unsetenv("CSC_IDENTITY_AUTO_DISCOVERY")
      } else {
        Sys.setenv(CSC_IDENTITY_AUTO_DISCOVERY = old_csc)
      }
    }, add = TRUE)
  }

  # Build for each platform/arch combination
  for (p in platform) {
    for (a in arch) {
      target <- paste0(p, "-", a)

      if (verbose) {
        cli::cli_alert_info("Building for {target}...")
      }

      # Try specific platform-arch script first
      build_script <- paste0("build-", p, "-", a)

      if (build_script %in% available_scripts) {
        result <- processx::run(
          command = get_npm_command(),
          args = c("run", build_script),
          wd = output_dir,
          echo = FALSE,
          spinner = verbose,
          cleanup_tree = TRUE,
          windows_hide_window = TRUE,
          error_on_status = FALSE
        )

        # Report key build stages from electron-builder output
        if (verbose && nzchar(result$stderr)) {
          lines <- strsplit(result$stderr, "\n")[[1]]
          for (line in lines) {
            line <- trimws(line)
            if (grepl("^\\s*\u2022\\s*packaging", line)) {
              cli::cli_alert_info("Packaging application...")
            } else if (grepl("^\\s*\u2022\\s*building\\s+target", line)) {
              cli::cli_alert_info("Creating installer...")
            } else if (grepl("^\\s*\u2022\\s*signing", line) && !grepl("signtool", line)) {
              cli::cli_alert_info("Signing application...")
            }
          }
        }

        if (result$status == 0) {
          if (verbose) cli::cli_alert_success("Built for {target}")
          next
        } else if (dist_has_platform_artifact(output_dir, p)) {
          # electron-builder 26.x exits 1 during post-build publish metadata
          # even after the installer is written. Artifact exists => success.
          if (verbose) cli::cli_alert_success("Built for {target}")
          next
        } else {
          if (verbose) cli::cli_alert_warning("Specific script {build_script} failed: {result$stderr}")
        }
      } else {
        if (verbose) cli::cli_alert_info("Script {build_script} not found, trying platform-only build")
      }

      # Fallback to platform-only build
      platform_script <- paste0("build-", p)

      if (platform_script %in% available_scripts) {
        if (verbose) {
          cli::cli_alert_info("Trying fallback build for {p}...")
        }

        fallback_result <- processx::run(
          command = get_npm_command(),
          args = c("run", platform_script),
          wd = output_dir,
          echo = FALSE,
          spinner = verbose,
          error_on_status = FALSE
        )

        # Report key build stages from electron-builder output
        if (verbose && nzchar(fallback_result$stderr)) {
          lines <- strsplit(fallback_result$stderr, "\n")[[1]]
          for (line in lines) {
            line <- trimws(line)
            if (grepl("^\\s*\u2022\\s*packaging", line)) {
              cli::cli_alert_info("Packaging application...")
            } else if (grepl("^\\s*\u2022\\s*building\\s+target", line)) {
              cli::cli_alert_info("Creating installer...")
            } else if (grepl("^\\s*\u2022\\s*signing", line) && !grepl("signtool", line)) {
              cli::cli_alert_info("Signing application...")
            }
          }
        }

        if (fallback_result$status == 0) {
          cli::cli_alert_success("Built for {p} (fallback - may include multiple architectures)")
        } else if (dist_has_platform_artifact(output_dir, p)) {
          cli::cli_alert_success("Built for {p} (fallback - may include multiple architectures)")
        } else {
          cli::cli_alert_warning("Fallback build also failed for {p}: {fallback_result$stderr}")
        }
      } else {
        cli::cli_alert_warning("No build script found for platform {p}")
      }
    }
  }
}
