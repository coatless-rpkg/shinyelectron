#' Get or create the cache directory path
#'
#' Returns the path where shinyelectron stores downloaded runtimes
#' (R, Python, Node.js) and other cached assets. By default, the
#' directory is created if it doesn't already exist. Pass
#' `create = FALSE` to query the path without side effects.
#'
#' @param create Logical. Whether to create the directory if it doesn't
#'   exist. Default is TRUE.
#'
#' @return Character string. Absolute path to the cache directory,
#'   typically `~/.cache/shinyelectron/assets` on Linux,
#'   `~/Library/Caches/shinyelectron/assets` on macOS, or
#'   `\%LOCALAPPDATA\%/shinyelectron/shinyelectron/Cache/assets` on Windows.
#'
#' @section Cache Layout:
#' Cached runtimes are organized by type, platform, architecture, and
#' version:
#' ```bash
#' assets/
#' |-- r/
#' |   |-- win/x64/4.5.3/
#' |   |-- mac/arm64/4.5.3/
#' |-- python/
#' |   |-- win/x64/3.12.10/
#' |   |-- mac/arm64/3.12.10/
#' |-- nodejs/
#' |   |-- v22.11.0/darwin-arm64/
#' |   |-- v22.11.0/win-x64/
#' ```
#'
#' Use [cache_info()] to see what's actually installed with disk usage.
#'
#' @examples
#' # Query without creating
#' cache_dir(create = FALSE)
#'
#' # Get or create
#' cache_dir()
#'
#' @seealso [cache_info()] to see what's cached, [cache_clear()] to
#'   remove cached assets, [cache_remove()] to remove a specific version.
#' @export
cache_dir <- function(create = TRUE) {
  cache_dir <- path.expand(fs::path(rappdirs::user_cache_dir("shinyelectron"), "assets"))
  if (create && !fs::dir_exists(cache_dir)) {
    fs::dir_create(cache_dir, recurse = TRUE)
  }
  cache_dir
}

#' Get path to cached R installation
#'
#' Creates the path to a specific R installation in the cache based on version, 
#' platform, and architecture.
#'
#' @param version Character string. R version (e.g., "4.1.0").
#' @param platform Character string. Target platform ("win", "mac", or "linux").
#' @param arch Character string. Target architecture ("x64" or "arm64").
#'
#' @return Character string. The path to the cached R installation for the 
#'         specified version, platform, and architecture.
#'
#' @section Details:
#' The path is structured as \code{cache_dir()/r/[platform]/[arch]/[version]}.
#' This function does not check if the installation exists at that location.
#'
#' @keywords internal
cache_r_path <- function(version, platform, arch) {
  fs::path(cache_dir(), "r", platform, arch, version)
}

#' Get path to npm packages cache
#'
#' Determines the path to the cache directory for npm packages used by shinyelectron.
#'
#' @return Character string. The path to the npm packages cache.
#'
#' @section Details:
#' The npm packages are cached at \code{cache_dir()/npm}. This allows for reuse
#' of downloaded npm dependencies across multiple builds.
#'
#' @keywords internal
cache_npm_path <- function() {
  fs::path(cache_dir(), "npm")
}

#' Show cached runtime information
#'
#' Lists all cached runtimes (R, Python, Node.js) with their versions,
#' platforms, architectures, and disk usage. Modeled after
#' `shinylive::assets_info()`.
#'
#' @param quiet Logical. If TRUE, suppresses console output and returns
#'   the results invisibly. Default is FALSE.
#'
#' @return A data frame (returned invisibly) with columns:
#'   \code{runtime} (character), \code{version} (character),
#'   \code{platform} (character), \code{arch} (character),
#'   \code{size} (character, human-readable), and \code{path} (character).
#'
#' @examples
#' \dontrun{
#' # Display cached runtimes
#' cache_info()
#'
#' # Programmatic access
#' df <- cache_info(quiet = TRUE)
#' }
#'
#' @seealso [cache_clear()] to remove cached assets, [cache_dir()] for
#'   the cache location.
#' @export
cache_info <- function(quiet = FALSE) {
  dir <- cache_dir(create = FALSE)
  rows <- list()

  if (!fs::dir_exists(dir)) {
    if (!quiet) cli::cli_alert_info("No cached assets found")
    df <- data.frame(
      runtime = character(), version = character(),
      platform = character(), arch = character(),
      size = character(), path = character(),
      stringsAsFactors = FALSE
    )
    return(invisible(df))
  }

  # Scan each runtime type
  for (runtime in c("r", "python", "nodejs")) {
    runtime_dir <- fs::path(dir, runtime)
    if (!fs::dir_exists(runtime_dir)) next

    if (runtime == "nodejs") {
      # nodejs: nodejs/v{version}/{platform}-{arch}/
      version_dirs <- list.dirs(runtime_dir, recursive = FALSE, full.names = TRUE)
      for (vdir in version_dirs) {
        version <- basename(vdir)
        platform_dirs <- list.dirs(vdir, recursive = FALSE, full.names = TRUE)
        for (pdir in platform_dirs) {
          parts <- strsplit(basename(pdir), "-")[[1]]
          plat <- parts[1]
          ar <- if (length(parts) > 1) parts[2] else "unknown"
          sz <- format_dir_size(pdir)
          rows <- c(rows, list(data.frame(
            runtime = runtime, version = version,
            platform = plat, arch = ar,
            size = sz, path = pdir,
            stringsAsFactors = FALSE
          )))
        }
      }
    } else {
      # r/python: {runtime}/{platform}/{arch}/{version}/
      platform_dirs <- list.dirs(runtime_dir, recursive = FALSE, full.names = TRUE)
      for (pdir in platform_dirs) {
        plat <- basename(pdir)
        arch_dirs <- list.dirs(pdir, recursive = FALSE, full.names = TRUE)
        for (adir in arch_dirs) {
          ar <- basename(adir)
          version_dirs <- list.dirs(adir, recursive = FALSE, full.names = TRUE)
          for (vdir in version_dirs) {
            version <- basename(vdir)
            sz <- format_dir_size(vdir)
            rows <- c(rows, list(data.frame(
              runtime = runtime, version = version,
              platform = plat, arch = ar,
              size = sz, path = vdir,
              stringsAsFactors = FALSE
            )))
          }
        }
      }
    }
  }

  if (length(rows) == 0) {
    if (!quiet) cli::cli_alert_info("No cached assets found")
    df <- data.frame(
      runtime = character(), version = character(),
      platform = character(), arch = character(),
      size = character(), path = character(),
      stringsAsFactors = FALSE
    )
    return(invisible(df))
  }

  df <- do.call(rbind, rows)
  rownames(df) <- NULL

  if (!quiet) {
    cli::cli_h2("Cached shinyelectron assets")
    cli::cli_alert_info("Cache directory: {.path {dir}}")
    cat("\n")
    for (rt in unique(df$runtime)) {
      label <- switch(rt, r = "R", python = "Python", nodejs = "Node.js", rt)
      sub <- df[df$runtime == rt, , drop = FALSE]
      cli::cli_h3(label)
      for (i in seq_len(nrow(sub))) {
        cli::cli_bullets(c(
          "*" = "{sub$version[i]} ({sub$platform[i]}/{sub$arch[i]}) {cli::col_silver(sub$size[i])}"
        ))
      }
    }
    cat("\n")
    total <- format_dir_size(dir)
    cli::cli_alert_info("Total cache size: {total}")
  }

  invisible(df)
}

#' Format directory size as human-readable string
#' @param path Directory path.
#' @return Character string like "142 MB".
#' @keywords internal
format_dir_size <- function(path) {
  if (!fs::dir_exists(path)) return("0 B")
  files <- fs::dir_ls(path, recurse = TRUE, type = "file")
  if (length(files) == 0) return("0 B")
  total <- sum(fs::file_size(files))
  format(total, units = "auto")
}

#' Remove a specific cached runtime version
#'
#' Removes a single cached runtime version instead of clearing the
#' entire cache. Use [cache_info()] to see what's available.
#'
#' @param runtime Character string. One of \code{"r"}, \code{"python"},
#'   or \code{"nodejs"}.
#' @param version Character string. Version to remove (e.g., \code{"4.5.3"},
#'   \code{"3.12.10"}, \code{"v22.11.0"}).
#' @param platform Character string. Platform (e.g., \code{"win"},
#'   \code{"mac"}, \code{"linux"}). For Node.js, use the combined
#'   platform-arch format shown by [cache_info()].
#' @param arch Character string. Architecture (\code{"x64"} or
#'   \code{"arm64"}). Ignored for Node.js (embedded in platform).
#'
#' @return Invisibly returns TRUE if removed, FALSE if not found.
#'
#' @examples
#' \dontrun{
#' # Remove a specific R version
#' cache_remove("r", "4.4.0", "mac", "arm64")
#'
#' # Remove a cached Python version
#' cache_remove("python", "3.12.10", "win", "x64")
#' }
#'
#' @seealso [cache_info()] to list cached versions, [cache_clear()] to
#'   remove all cached assets of a type.
#' @export
cache_remove <- function(runtime, version, platform = NULL, arch = NULL) {
  runtime <- match.arg(runtime, c("r", "python", "nodejs"))
  dir <- cache_dir(create = FALSE)

  if (!fs::dir_exists(dir)) {
    cli::cli_alert_info("Cache directory doesn't exist: nothing to remove")
    return(invisible(FALSE))
  }

  if (runtime == "nodejs") {
    # nodejs: nodejs/{version}/{platform}-{arch}/
    target <- fs::path(dir, "nodejs", version)
  } else {
    if (is.null(platform) || is.null(arch)) {
      cli::cli_abort("Both {.arg platform} and {.arg arch} are required for {.val {runtime}}")
    }
    target <- fs::path(dir, runtime, platform, arch, version)
  }

  if (fs::dir_exists(target)) {
    fs::dir_delete(target)
    label <- switch(runtime, r = "R", python = "Python", nodejs = "Node.js")
    cli::cli_alert_success("Removed {label} {version} from cache")
    return(invisible(TRUE))
  }

  cli::cli_alert_warning("Not found in cache: {.path {target}}")
  invisible(FALSE)
}

#' Clear the asset cache
#'
#' Removes cached R installations and/or npm packages from the cache directory.
#'
#' @param what Character string specifying what to clear. One of
#'   \code{"all"}, \code{"nodejs"}, \code{"r"}, \code{"python"}, or a
#'   specific cache subdirectory name.
#'
#' @return Invisibly returns NULL.
#'
#' @section Details:
#' Use this function to free disk space or force re-downloading of assets:
#' \itemize{
#'   \item \code{"r"}: Removes only cached R installations
#'   \item \code{"npm"}: Removes only cached npm packages
#'   \item \code{"nodejs"}: Removes only cached Node.js installations
#'   \item \code{"python"}: Removes only cached Python installations
#'   \item \code{"all"}: Removes all cached assets
#' }
#' If the cache directory doesn't exist, a message is shown and nothing is done.
#'
#' @examples
#' \dontrun{
#' # Clear everything in the cache
#' cache_clear()
#'
#' # Clear only R installations
#' cache_clear("r")
#'
#' # Clear only npm packages
#' cache_clear("npm")
#'
#' # Clear only Node.js installations
#' cache_clear("nodejs")
#'
#' # Clear only Python installations
#' cache_clear("python")
#' }
#'
#' @export
cache_clear <- function(what = c("all", "r", "npm", "nodejs", "python")) {
  what <- match.arg(what)
  dir <- cache_dir(create = FALSE)

  if (!fs::dir_exists(dir)) {
    cli::cli_alert_info("Cache directory doesn't exist: nothing to clear")
    return(invisible(NULL))
  }

  if (what %in% c("all", "r")) {
    r_path <- fs::path(dir, "r")
    if (fs::dir_exists(r_path)) {
      fs::dir_delete(r_path)
      cli::cli_alert_success("Cleared R installation cache")
    }
  }

  if (what %in% c("all", "npm")) {
    npm_path <- fs::path(dir, "npm")
    if (fs::dir_exists(npm_path)) {
      fs::dir_delete(npm_path)
      cli::cli_alert_success("Cleared npm packages cache")
    }
  }

  if (what %in% c("all", "nodejs")) {
    nodejs_path <- fs::path(dir, "nodejs")
    if (fs::dir_exists(nodejs_path)) {
      fs::dir_delete(nodejs_path)
      cli::cli_alert_success("Cleared Node.js installation cache")
    }
  }

  if (what %in% c("all", "python")) {
    python_path <- fs::path(dir, "python")
    if (fs::dir_exists(python_path)) {
      fs::dir_delete(python_path)
      cli::cli_alert_success("Cleared Python installation cache")
    }
  }

  invisible(NULL)
}
