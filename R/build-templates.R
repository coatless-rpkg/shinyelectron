#' Process and copy Electron templates
#'
#' Orchestrates the Electron project assembly: renders shared Whisker
#' templates, copies the appropriate backend modules, sets up Dockerfiles
#' for container strategy, generates package.json, and copies brand
#' assets. Each step is a focused helper in this file.
#'
#' @param output_dir Character destination directory
#' @param app_name Character application display name
#' @param app_type Character application type
#' @param runtime_strategy Character resolved runtime strategy
#' @param icon Character path to icon file or NULL
#' @param config List of configuration values from config file (optional)
#' @param verbose Logical whether to show progress
#' @keywords internal
process_templates <- function(output_dir, app_name, app_type,
                              runtime_strategy = "shinylive",
                              icon = NULL, config = NULL, sign = FALSE,
                              is_multi_app = FALSE, apps_manifest = NULL,
                              verbose = TRUE) {
  if (verbose) cli::cli_alert_info("Processing Electron templates...")

  app_slug <- config$app$slug %||% slugify(app_name)
  validate_slug(app_slug)

  backend_module <- resolve_backend_module(app_type, runtime_strategy)

  brand <- resolve_brand_yml(output_dir, is_multi_app, apps_manifest)

  template_vars <- generate_template_variables(
    app_name = app_name, app_slug = app_slug, app_type = app_type,
    runtime_strategy = runtime_strategy, icon = icon,
    backend_module = backend_module, brand = brand, config = config,
    is_multi_app = is_multi_app, apps_manifest = apps_manifest
  )

  render_shared_templates(output_dir, template_vars, is_multi_app)
  copy_backend_modules(output_dir, backend_module, is_multi_app)

  if (runtime_strategy == "container") {
    copy_and_bake_dockerfiles(output_dir, app_type, config = config, verbose = verbose)
  }

  writeLines(
    generate_package_json(
      app_slug = app_slug,
      app_version = config$app$version %||% SHINYELECTRON_DEFAULTS$app_version,
      backend = gsub("\\.js$", "", backend_module),
      config = config,
      has_icon = !is.null(icon),
      sign = sign,
      is_multi_app = is_multi_app
    ),
    fs::path(output_dir, "package.json")
  )

  copy_brand_assets(output_dir, icon, config)

  if (verbose) cli::cli_alert_success("Processed Electron templates")
}

#' Resolve the active _brand.yml for template rendering
#'
#' Prefers the single-app location (`src/app`); for multi-app, falls back
#' to the first listed app if the shared location has no brand file.
#' @keywords internal
resolve_brand_yml <- function(output_dir, is_multi_app, apps_manifest) {
  brand <- read_brand_yml(fs::path(output_dir, "src", "app"))
  if (!is.null(brand)) return(brand)
  if (is_multi_app && !is.null(apps_manifest) && length(apps_manifest) > 0) {
    first_app_path <- fs::path(output_dir, apps_manifest[[1]]$path)
    if (fs::dir_exists(first_app_path)) {
      return(read_brand_yml(first_app_path))
    }
  }
  NULL
}

#' Render shared Electron templates (main.js, lifecycle.html, preload.js, launcher.html)
#' @keywords internal
render_shared_templates <- function(output_dir, template_vars, is_multi_app) {
  shared_dir <- system.file("electron", "shared", package = "shinyelectron")
  if (!fs::dir_exists(shared_dir)) {
    cli::cli_abort("Shared template directory not found at {.path {shared_dir}}")
  }

  shared_files <- list.files(shared_dir, recursive = TRUE, full.names = TRUE)
  # launcher.html is only needed in multi-app mode and lives at output_dir/launcher.html
  for (template_file in shared_files) {
    rel_path <- fs::path_rel(template_file, shared_dir)
    if (rel_path == "launcher.html" && !is_multi_app) next

    template_content <- paste(readLines(template_file, warn = FALSE), collapse = "\n")
    processed <- whisker::whisker.render(template_content, template_vars)

    output_path <- fs::path(output_dir, rel_path)
    output_parent <- dirname(output_path)
    if (!fs::dir_exists(output_parent)) {
      fs::dir_create(output_parent, recurse = TRUE)
    }
    writeLines(processed, output_path)
  }
}

#' Copy backend module(s) and their shared JS helpers into the build
#' @keywords internal
copy_backend_modules <- function(output_dir, backend_module, is_multi_app) {
  backends_dir <- system.file("electron", "backends", package = "shinyelectron")
  backend_src <- fs::path(backends_dir, backend_module)
  if (!fs::file_exists(backend_src)) {
    cli::cli_abort("Backend module not found: {.path {backend_src}}")
  }

  backend_dest_dir <- fs::path(output_dir, "backends")
  fs::dir_create(backend_dest_dir, recurse = TRUE)
  fs::file_copy(backend_src, fs::path(backend_dest_dir, backend_module), overwrite = TRUE)

  # Multi-app may switch between sub-app types at runtime, so ship all backends
  if (is_multi_app) {
    for (b in c("shinylive.js", "native-r.js", "native-py.js", "container.js")) {
      b_src <- fs::path(backends_dir, b)
      if (fs::file_exists(b_src)) {
        fs::file_copy(b_src, fs::path(backend_dest_dir, b), overwrite = TRUE)
      }
    }
  }

  # Always ship shared helpers: every backend imports from utils.js;
  # native backends use dependency-checker; auto-download uses runtime-downloader
  for (f in c("utils.js", "dependency-checker.js", "runtime-downloader.js")) {
    src <- fs::path(backends_dir, f)
    if (fs::file_exists(src)) {
      fs::file_copy(src, fs::path(backend_dest_dir, f), overwrite = TRUE)
    }
  }
}

#' Copy the Dockerfile for the container strategy and bake in app dependencies
#'
#' @param output_dir Character. Destination build directory.
#' @param app_type Character. Application type (e.g. `"r-shiny"`, `"py-shiny"`).
#' @param config List of configuration values from the config file, or NULL.
#'   Used to resolve the runtime version that is baked into the `ARG` default
#'   line of the copied Dockerfile.
#' @param verbose Logical. Whether to show progress messages.
#' @keywords internal
copy_and_bake_dockerfiles <- function(output_dir, app_type, config = NULL, verbose = TRUE) {
  dockerfile_name <- if (grepl("^r-", app_type)) "r-shiny" else "py-shiny"
  dockerfile_src <- system.file("dockerfiles", dockerfile_name, package = "shinyelectron")

  if (!fs::dir_exists(dockerfile_src)) {
    cli::cli_warn("Dockerfile not found for app type: {.val {dockerfile_name}}")
    return(invisible(NULL))
  }

  dockerfile_dest <- fs::path(output_dir, "dockerfiles")
  fs::dir_create(dockerfile_dest, recurse = TRUE)
  for (f in list.files(dockerfile_src, full.names = TRUE)) {
    fs::file_copy(f, fs::path(dockerfile_dest, basename(f)), overwrite = TRUE)
  }

  # Rewrite the ARG default to the resolved runtime version so the baked
  # image tag encodes the version and avoids cache collisions.
  dockerfile_path <- fs::path(dockerfile_dest, "Dockerfile")
  df_lines <- readLines(dockerfile_path)
  if (grepl("^r-", app_type)) {
    ver <- resolve_runtime_version("r", config %||% list())
    df_lines <- sub("^(ARG R_VERSION=).*", paste0("\\1", ver), df_lines)
  } else {
    ver <- resolve_runtime_version("python", config %||% list())
    minor <- sub("^(\\d+\\.\\d+).*", "\\1", ver)
    df_lines <- sub("^(ARG PY_VERSION=).*", paste0("\\1", minor), df_lines)
  }
  writeLines(df_lines, dockerfile_path)

  bake_dockerfile_dependencies(output_dir, dockerfile_dest, config = config)

  if (verbose) cli::cli_alert_success("Copied Dockerfile for container strategy")
}

#' Append app-specific package installs to the Dockerfile
#'
#' Bakes system dependencies (via the Posit Package Manager sysreqs API and
#' `config$dependencies$system_packages`) and R/Python package installs into
#' the image at build time so container launch does not have to
#' compile/install packages on the user's machine.
#'
#' For R apps the base image is `rocker/r-ver`, which pre-wires P3M
#' binaries; packages are therefore installed via `install.packages()`.
#' @keywords internal
bake_dockerfile_dependencies <- function(output_dir, dockerfile_dest, config = NULL) {
  dep_manifest <- fs::path(output_dir, "src", "app", "dependencies.json")
  if (!fs::file_exists(dep_manifest)) return(invisible(NULL))

  deps <- jsonlite::fromJSON(dep_manifest, simplifyVector = FALSE)
  pkgs <- unlist(deps$packages)
  if (length(pkgs) == 0) return(invisible(NULL))

  dockerfile_path <- fs::path(dockerfile_dest, "Dockerfile")
  dockerfile_lines <- readLines(dockerfile_path)

  if (deps$language == "r") {
    # Gather system deps: Posit sysreqs API (ubuntu 24.04, matching the
    # rocker/r-ver base) + the config escape hatch.
    sys <- query_sysreqs(c("shiny", pkgs), "ubuntu", "24.04")
    sys <- unique(c(sys, config$dependencies$system_packages))

    if (length(sys) > 0) {
      sys_line <- paste0(
        "RUN apt-get update && apt-get install -y --no-install-recommends ",
        "-o Dpkg::Options::=--force-confold ",
        paste(sys, collapse = " "),
        " && rm -rf /var/lib/apt/lists/*"
      )
      dockerfile_lines <- c(
        dockerfile_lines, "", "# System libraries for R packages", sys_line
      )
    }

    # rocker/r-ver + P3M binaries: install via install.packages()
    r_line <- paste0(
      "RUN R -e \"install.packages(c(",
      paste0("'", pkgs, "'", collapse = ", "),
      "))\""
    )
    dockerfile_lines <- c(dockerfile_lines, "", "# App-specific R packages", r_line)

  } else if (deps$language == "python") {
    # No system-requirements auto-detection for Python; honour the config escape hatch
    sys <- unique(c(character(0), config$dependencies$system_packages))

    if (length(sys) > 0) {
      sys_line <- paste0(
        "RUN apt-get update && apt-get install -y --no-install-recommends ",
        "-o Dpkg::Options::=--force-confold ",
        paste(sys, collapse = " "),
        " && rm -rf /var/lib/apt/lists/*"
      )
      dockerfile_lines <- c(
        dockerfile_lines, "", "# System libraries for Python packages", sys_line
      )
    }

    pip_line <- paste0("RUN pip install --no-cache-dir ", paste(pkgs, collapse = " "))
    dockerfile_lines <- c(dockerfile_lines, "", "# App-specific Python packages", pip_line)
  }

  writeLines(dockerfile_lines, dockerfile_path)
}

#' Copy branding assets (icon, splash image, tray icon) into the build
#' @keywords internal
copy_brand_assets <- function(output_dir, icon, config) {
  if (!is.null(icon)) {
    icon_dest <- fs::path(output_dir, "assets",
                          paste0("icon.", tools::file_ext(icon)))
    fs::file_copy(icon, icon_dest, overwrite = TRUE)
  }

  splash_image <- config$splash$image
  if (!is.null(splash_image) && file.exists(splash_image)) {
    fs::file_copy(splash_image, fs::path(output_dir, "assets", "splash-image.png"),
                  overwrite = TRUE)
  }

  tray_icon <- config$tray$icon
  if (!is.null(tray_icon) && file.exists(tray_icon)) {
    fs::file_copy(tray_icon, fs::path(output_dir, "assets", basename(tray_icon)),
                  overwrite = TRUE)
  }
}
