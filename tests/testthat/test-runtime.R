# tests/testthat/test-runtime.R

test_that("r_download_url constructs correct URL for macOS arm64", {
  url <- r_download_url("4.4.0", "mac", "arm64")
  expect_true(grepl("4.4.0", url))
  expect_true(grepl("arm64", url))
  expect_true(grepl("portable-r-macos", url))
  expect_true(grepl("tar\\.gz$", url))
})

test_that("r_download_url constructs correct URL for macOS x64", {
  url <- r_download_url("4.4.0", "mac", "x64")
  expect_true(grepl("4.4.0", url))
  expect_true(grepl("x86_64", url))
  expect_true(grepl("portable-r-macos", url))
})

test_that("r_download_url constructs correct URL for Windows x64", {
  url <- r_download_url("4.4.0", "win", "x64")
  expect_true(grepl("4.4.0", url))
  expect_true(grepl("portable-r-windows", url))
  expect_true(grepl("zip$", url))
})

test_that("r_download_url errors for Linux", {
  expect_error(r_download_url("4.4.0", "linux", "x64"), "not yet supported")
})

test_that("r_install_path returns correct cache path", {
  path <- r_install_path("4.4.0", "mac", "arm64")
  expect_true(grepl("r", path, ignore.case = TRUE))
  expect_true(grepl("4.4.0", path))
  expect_true(grepl("mac", path))
  expect_true(grepl("arm64", path))
})

test_that("r_install_path uses current platform/arch when NULL", {
  path <- r_install_path("4.4.0")
  expect_true(nzchar(path))
  expect_true(grepl("4.4.0", path))
})

test_that("r_is_installed returns FALSE for non-existent version", {
  expect_false(r_is_installed("99.99.99"))
})

test_that("r_executable returns correct path structure for mac", {
  mockery::stub(r_executable, "detect_current_platform", function() "mac")
  mockery::stub(r_executable, "detect_current_arch", function() "arm64")
  mockery::stub(r_executable, "fs::file_exists", function(path) TRUE)

  result <- r_executable("4.4.0", "mac", "arm64")
  expect_true(grepl("Rscript", result))
  # portable-r layout: portable-r-{version}-macos-{arch}/bin/Rscript
  expect_true(grepl("portable-r.*bin.*Rscript", result) || grepl("bin.*Rscript", result))
})

test_that("r_executable returns correct path structure for win", {
  mockery::stub(r_executable, "detect_current_platform", function() "win")
  mockery::stub(r_executable, "detect_current_arch", function() "x64")
  mockery::stub(r_executable, "fs::file_exists", function(path) TRUE)

  result <- r_executable("4.4.0", "win", "x64")
  expect_true(grepl("Rscript.exe", result))
})

test_that("r_executable returns NULL when not installed", {
  mockery::stub(r_executable, "detect_current_platform", function() "mac")
  mockery::stub(r_executable, "detect_current_arch", function() "arm64")
  mockery::stub(r_executable, "fs::file_exists", function(path) FALSE)

  result <- r_executable("4.4.0", "mac", "arm64")
  expect_null(result)
})

test_that("install_r_portable validates version format", {
  expect_error(install_r_portable(version = "not-a-version"), "version")
})

test_that("generate_runtime_manifest creates valid JSON", {
  skip_if_not_installed("mockery")
  # Keep manifest generation offline; the published-checksum lookup is covered
  # in test-checksum.R.
  mockery::stub(generate_runtime_manifest, "r_expected_sha256", function(...) NULL)
  manifest <- generate_runtime_manifest("4.4.0", "mac", "arm64")
  parsed <- jsonlite::fromJSON(manifest, simplifyVector = FALSE)

  expect_equal(parsed$language, "r")
  expect_equal(parsed$version, "4.4.0")
  expect_true(grepl("4.4.0", parsed$download_url))
  expect_true(grepl("R-4.4.0", parsed$install_path))
  expect_equal(parsed$platform, "mac")
  expect_equal(parsed$arch, "arm64")
})

test_that("generate_runtime_manifest uses current platform when NULL", {
  # Uses current platform; on Linux this hits r_download_url() which
  # aborts because portable-r has no Linux builds.
  skip_on_os("linux")
  skip_if_not_installed("mockery")
  mockery::stub(generate_runtime_manifest, "r_expected_sha256", function(...) NULL)
  manifest <- generate_runtime_manifest("4.4.0")
  parsed <- jsonlite::fromJSON(manifest, simplifyVector = FALSE)

  expect_true(nzchar(parsed$platform))
  expect_true(nzchar(parsed$arch))
})

# --- Python runtime functions ---

test_that("python_download_url constructs correct URL for macOS", {
  url <- python_download_url("3.12.0", "mac", "arm64", release_date = "20251007")
  expect_true(grepl("3.12.0", url))
  expect_true(grepl("aarch64", url) || grepl("arm64", url))
})

test_that("python_download_url constructs correct URL for Windows", {
  url <- python_download_url("3.12.0", "win", "x64", release_date = "20251007")
  expect_true(grepl("3.12.0", url))
  expect_true(grepl("x86_64", url) || grepl("x64", url))
})

test_that("python_download_url constructs correct URL for Linux", {
  url <- python_download_url("3.12.0", "linux", "x64", release_date = "20251007")
  expect_true(grepl("3.12.0", url))
  expect_true(grepl("x86_64", url))
})

test_that("python_install_path returns correct cache path", {
  path <- python_install_path("3.12.0", "mac", "arm64")
  expect_true(grepl("python", path, ignore.case = TRUE))
  expect_true(grepl("3.12.0", path))
})

test_that("python_is_installed returns FALSE for non-existent version", {
  expect_false(python_is_installed("99.99.99"))
})

test_that("python_executable returns correct path for mac", {
  mockery::stub(python_executable, "detect_current_platform", function() "mac")
  mockery::stub(python_executable, "detect_current_arch", function() "arm64")
  mockery::stub(python_executable, "fs::file_exists", function(path) TRUE)
  result <- python_executable("3.12.0", "mac", "arm64")
  expect_true(grepl("python", result))
})

test_that("python_executable returns NULL when not installed", {
  mockery::stub(python_executable, "detect_current_platform", function() "mac")
  mockery::stub(python_executable, "detect_current_arch", function() "arm64")
  mockery::stub(python_executable, "fs::file_exists", function(path) FALSE)
  result <- python_executable("3.12.0", "mac", "arm64")
  expect_null(result)
})

test_that("install_python_standalone validates version format", {
  expect_error(install_python_standalone(version = "not-a-version"), "version")
})

test_that("generate_python_runtime_manifest creates valid JSON", {
  skip_if_not_installed("mockery")
  mockery::stub(generate_python_runtime_manifest, "resolve_python_pbs", function(v) {
    list(version = v, release = "20250101")
  })
  mockery::stub(generate_python_runtime_manifest, "python_expected_sha256", function(...) NULL)
  manifest <- generate_python_runtime_manifest("3.12.0", "mac", "arm64")
  parsed <- jsonlite::fromJSON(manifest, simplifyVector = FALSE)
  expect_equal(parsed$language, "python")
  expect_equal(parsed$version, "3.12.0")
  expect_true(grepl("3.12.0", parsed$download_url))
  expect_equal(parsed$platform, "mac")
  expect_equal(parsed$arch, "arm64")
})

# --- install_nodejs: atomic extraction preserves prior install on failure ---

test_that("install_nodejs preserves prior install when extraction fails", {
  tmp <- withr::local_tempdir()
  # Build a realistic install_dir path matching nodejs_install_path() layout.
  install_dir <- file.path(tmp, "nodejs", "v22.0.0", "darwin-arm64")
  dir.create(install_dir, recursive = TRUE)
  # Sentinel file representing a working prior install.
  writeLines("prior", file.path(install_dir, "node"))

  # Stub platform/arch detection and path resolution to use tmp.
  mockery::stub(install_nodejs, "detect_current_platform", function() "mac")
  mockery::stub(install_nodejs, "detect_current_arch", function() "arm64")
  mockery::stub(install_nodejs, "nodejs_install_path",
                function(v, p, a) file.path(tmp, "nodejs", paste0("v", v), "darwin-arm64"))
  mockery::stub(install_nodejs, "utils::download.file",
                function(url, dest, ...) invisible(file.create(dest)))
  mockery::stub(install_nodejs, "nodejs_download_checksums", function(v) character(0))
  # Stub extraction to fail so we can confirm prior install is untouched.
  mockery::stub(install_nodejs, "utils::untar",
                function(...) stop("simulated extraction failure"))

  expect_error(
    install_nodejs(version = "22.0.0", force = TRUE, verbose = FALSE),
    "simulated extraction failure"
  )

  # The sentinel from the prior install must still be present.
  expect_true(file.exists(file.path(install_dir, "node")))
})

test_that("install_nodejs preserves prior install when node binary missing from archive", {
  # RED before fix: verify-after-swap meant the prior install was already
  # destroyed when the abort fired.
  # GREEN after fix: verify-before-swap keeps the prior install intact.
  tmp <- withr::local_tempdir()
  install_dir <- file.path(tmp, "nodejs", "v22.0.0", "darwin-arm64")
  dir.create(install_dir, recursive = TRUE)
  # Sentinel file representing a working prior install.
  writeLines("prior", file.path(install_dir, "sentinel"))

  mockery::stub(install_nodejs, "detect_current_platform", function() "mac")
  mockery::stub(install_nodejs, "detect_current_arch", function() "arm64")
  mockery::stub(install_nodejs, "nodejs_install_path",
                function(v, p, a) file.path(tmp, "nodejs", paste0("v", v), "darwin-arm64"))
  mockery::stub(install_nodejs, "utils::download.file",
                function(url, dest, ...) invisible(file.create(dest)))
  mockery::stub(install_nodejs, "nodejs_download_checksums", function(v) character(0))
  # Extraction creates the top-level dir (correct structure) but omits bin/node,
  # simulating a structurally-valid but incomplete archive.
  mockery::stub(install_nodejs, "utils::untar", function(tarfile, exdir, ...) {
    extracted <- file.path(exdir, "node-v22.0.0-darwin-arm64")
    dir.create(file.path(extracted, "bin"), recursive = TRUE)
    # node binary intentionally absent
    invisible(NULL)
  })

  expect_error(
    install_nodejs(version = "22.0.0", force = TRUE, verbose = FALSE),
    "Node.js executable not found"
  )

  # The prior install directory and its sentinel must still be present.
  expect_true(dir.exists(install_dir))
  expect_true(file.exists(file.path(install_dir, "sentinel")))
})

# --- download_and_extract_portable_tool: abort when executable missing ---

# --- resolve_backend_module: correct backend module for each strategy/type ---

test_that("resolve_backend_module returns shinylive.js for shinylive strategy", {
  expect_equal(resolve_backend_module("r-shiny",  "shinylive"), "shinylive.js")
  expect_equal(resolve_backend_module("py-shiny", "shinylive"), "shinylive.js")
})

test_that("resolve_backend_module returns native-r.js for r-* types with native strategies", {
  expect_equal(resolve_backend_module("r-shiny", "system"),        "native-r.js")
  expect_equal(resolve_backend_module("r-shiny", "bundled"),       "native-r.js")
  expect_equal(resolve_backend_module("r-shiny", "auto-download"), "native-r.js")
})

test_that("resolve_backend_module returns native-py.js for py-* types with native strategies", {
  expect_equal(resolve_backend_module("py-shiny", "system"),        "native-py.js")
  expect_equal(resolve_backend_module("py-shiny", "bundled"),       "native-py.js")
  expect_equal(resolve_backend_module("py-shiny", "auto-download"), "native-py.js")
})

test_that("resolve_backend_module returns container.js for container strategy", {
  expect_equal(resolve_backend_module("r-shiny",  "container"), "container.js")
  expect_equal(resolve_backend_module("py-shiny", "container"), "container.js")
})

test_that("resolve_backend_module aborts for unknown runtime strategy", {
  expect_error(
    resolve_backend_module("r-shiny", "unknown-strategy"),
    "Unknown runtime strategy"
  )
})

# --- build_electron_app: multi-platform abort guard ---

test_that("build_electron_app aborts for bundled strategy with multiple platforms", {
  tmp <- withr::local_tempdir()
  out <- file.path(tmp, "out")
  expect_error(
    build_electron_app(tmp, out, app_name = "test", app_type = "r-shiny",
                       runtime_strategy = "bundled",
                       platform = c("mac", "win"), arch = "x64",
                       verbose = FALSE),
    "one platform and architecture"
  )
})

test_that("build_electron_app aborts for bundled strategy with multiple architectures", {
  tmp <- withr::local_tempdir()
  out <- file.path(tmp, "out")
  expect_error(
    build_electron_app(tmp, out, app_name = "test", app_type = "r-shiny",
                       runtime_strategy = "bundled",
                       platform = "mac", arch = c("x64", "arm64"),
                       verbose = FALSE),
    "one platform and architecture"
  )
})

test_that("build_electron_app aborts for auto-download strategy with multiple platforms", {
  tmp <- withr::local_tempdir()
  out <- file.path(tmp, "out")
  expect_error(
    build_electron_app(tmp, out, app_name = "test", app_type = "py-shiny",
                       runtime_strategy = "auto-download",
                       platform = c("mac", "win"), arch = "x64",
                       verbose = FALSE),
    "one platform and architecture"
  )
})

test_that("build_electron_app does not abort for system strategy with multiple platforms", {
  tmp <- withr::local_tempdir()
  out <- file.path(tmp, "out")
  mockery::stub(build_electron_app, "validate_node_npm", function(...) stop("PAST_GUARD"))
  expect_error(
    build_electron_app(tmp, out, app_name = "test", app_type = "r-shiny",
                       runtime_strategy = "system",
                       platform = c("mac", "win"), arch = "x64",
                       verbose = FALSE),
    "PAST_GUARD"
  )
})

test_that("build_electron_app does not abort for container strategy with multiple platforms", {
  tmp <- withr::local_tempdir()
  out <- file.path(tmp, "out")
  mockery::stub(build_electron_app, "validate_node_npm", function(...) stop("PAST_GUARD"))
  expect_error(
    build_electron_app(tmp, out, app_name = "test", app_type = "r-shiny",
                       runtime_strategy = "container",
                       platform = c("mac", "win"), arch = "x64",
                       verbose = FALSE),
    "PAST_GUARD"
  )
})

test_that("build_electron_app does not abort for shinylive strategy with multiple platforms", {
  tmp <- withr::local_tempdir()
  out <- file.path(tmp, "out")
  mockery::stub(build_electron_app, "validate_node_npm", function(...) stop("PAST_GUARD"))
  expect_error(
    build_electron_app(tmp, out, app_name = "test", app_type = "r-shiny",
                       runtime_strategy = "shinylive",
                       platform = c("mac", "win"), arch = "x64",
                       verbose = FALSE),
    "PAST_GUARD"
  )
})

test_that("build_electron_app does not abort for bundled with single platform and arch", {
  tmp <- withr::local_tempdir()
  out <- file.path(tmp, "out")
  mockery::stub(build_electron_app, "validate_node_npm", function(...) stop("PAST_GUARD"))
  expect_error(
    build_electron_app(tmp, out, app_name = "test", app_type = "r-shiny",
                       runtime_strategy = "bundled",
                       platform = "mac", arch = "arm64",
                       verbose = FALSE),
    "PAST_GUARD"
  )
})

# --- download_and_extract_portable_tool: abort when executable missing ---

test_that("download_and_extract_portable_tool aborts (not warns) when executable not found", {
  tmp <- withr::local_tempdir()
  install_path <- file.path(tmp, "install")

  # Stub network download to write an empty file (the real content is not needed).
  mockery::stub(
    download_and_extract_portable_tool, "utils::download.file",
    function(url, destfile, ...) invisible(file.create(destfile))
  )
  # Stub extraction: silently create some content in the staging dir so
  # fs::file_move(staging, install_path) succeeds normally.
  mockery::stub(
    download_and_extract_portable_tool, "utils::untar",
    function(tarfile, exdir, ...) dir.create(file.path(exdir, "content"))
  )

  # executable_finder returns NULL -> should abort, not merely warn.
  expect_error(
    download_and_extract_portable_tool(
      label = "TestTool",
      version = "1.0.0",
      install_path = install_path,
      download_url = "https://example.com/tool-1.0.0.tar.gz",
      executable_finder = function() NULL,
      verbose = FALSE
    ),
    class = "rlang_error"
  )
})

# --- build_electron_app: delegates bundled embedding to the shared helpers ---

test_that("build_electron_app delegates bundled R embedding to embed_r_runtime with direct deps", {
  skip_if_not_installed("mockery")
  tmp <- withr::local_tempdir()
  app_dir <- fs::path(tmp, "app"); fs::dir_create(app_dir)
  writeLines("library(shiny)", fs::path(app_dir, "app.R"))
  out <- fs::path(tmp, "out")

  # Neutralize the heavyweight build steps.
  mockery::stub(build_electron_app, "validate_node_npm", function(...) invisible(TRUE))
  mockery::stub(build_electron_app, "setup_electron_project", function(...) invisible(TRUE))
  mockery::stub(build_electron_app, "copy_app_files",
                function(app_dir, output_dir, app_type, ...) {
    dep_dir <- fs::path(output_dir, "src", "app")
    fs::dir_create(dep_dir, recurse = TRUE)
    jsonlite::write_json(
      list(language = "r",
           packages = c("shiny", "bslib"),
           repos = "https://cloud.r-project.org"),
      fs::path(dep_dir, "dependencies.json"), auto_unbox = TRUE
    )
    invisible(TRUE)
  })
  mockery::stub(build_electron_app, "process_templates", function(...) invisible(TRUE))
  mockery::stub(build_electron_app, "install_npm_dependencies", function(...) invisible(TRUE))
  mockery::stub(build_electron_app, "build_for_platforms", function(...) invisible(TRUE))
  mockery::stub(build_electron_app, "validate_build_output", function(...) invisible(TRUE))
  mockery::stub(build_electron_app, "resolve_runtime_version", function(runtime, config) "4.4.1")

  # Neutralize the PRE-refactor inline path so the only behavioral difference is
  # whether embed_r_runtime is reached (clean red-before-green).
  mockery::stub(build_electron_app, "install_r_portable", function(...) fs::path(out, "cached-r"))
  mockery::stub(build_electron_app, "copy_dir_contents", function(src, dst) {
    fs::dir_create(dst, recurse = TRUE)
    if (basename(dst) == "R") {
      fs::dir_create(fs::path(dst, "bin"))
      writeLines("#!/bin/sh", fs::path(dst, "bin", "Rscript"))
    }
    invisible(dst)
  })
  mockery::stub(build_electron_app, "r_executable",
                function(...) fs::path(out, "runtime", "R", "bin", "Rscript"))
  mockery::stub(build_electron_app, "utils::available.packages",
                function(repos) matrix(nrow = 0, ncol = 0))
  mockery::stub(build_electron_app, "tools::package_dependencies",
                function(packages, db, which, recursive) list())
  mockery::stub(build_electron_app, "processx::run", function(command, args, ...) {
    lib <- fs::path(out, "runtime", "R", "library")
    for (p in c("shiny", "bslib")) fs::dir_create(fs::path(lib, p))
    list(status = 0, stdout = "", stderr = "")
  })

  embed_rec <- mockery::mock()
  mockery::stub(build_electron_app, "embed_r_runtime",
                function(output_dir, packages, repos, version, platform, arch, verbose,
                         prune, local_packages) {
    embed_rec(packages = packages, repos = repos, version = version,
              platform = platform, arch = arch, prune = prune,
              local_packages = local_packages)
    invisible(fs::path(output_dir, "runtime", "R"))
  })

  build_electron_app(app_dir, out, app_name = "test", app_type = "r-shiny",
                     runtime_strategy = "bundled",
                     platform = "mac", arch = "arm64", verbose = FALSE)

  embed_args <- mockery::mock_args(embed_rec)[[1]]
  expect_false(is.null(embed_args))
  expect_equal(embed_args$packages, c("shiny", "bslib"))
  expect_equal(embed_args$repos, "https://cloud.r-project.org")
  expect_equal(embed_args$version, "4.4.1")
  expect_equal(embed_args$platform, "mac")
  expect_equal(embed_args$arch, "arm64")
  expect_true(embed_args$prune)   # dependencies.r.prune defaults to TRUE
  expect_equal(embed_args$local_packages, character(0))
})

test_that("build_electron_app passes dependencies.r.prune from config to embed_r_runtime", {
  skip_if_not_installed("mockery")

  tmp <- withr::local_tempdir()
  app_dir <- fs::path(tmp, "app"); fs::dir_create(app_dir)
  writeLines("library(shiny)", fs::path(app_dir, "app.R"))

  mockery::stub(build_electron_app, "validate_node_npm", function(...) invisible(TRUE))
  mockery::stub(build_electron_app, "setup_electron_project", function(...) invisible(TRUE))
  mockery::stub(build_electron_app, "copy_app_files", function(...) invisible(TRUE))
  mockery::stub(build_electron_app, "process_templates", function(...) invisible(TRUE))
  mockery::stub(build_electron_app, "install_npm_dependencies", function(...) invisible(TRUE))
  mockery::stub(build_electron_app, "build_for_platforms", function(...) invisible(TRUE))
  mockery::stub(build_electron_app, "validate_build_output", function(...) invisible(TRUE))
  mockery::stub(build_electron_app, "resolve_runtime_version", function(runtime, config) "4.6.1")

  embed_rec <- mockery::mock()
  mockery::stub(build_electron_app, "embed_r_runtime",
                function(output_dir, packages, repos, version, platform, arch, verbose,
                         prune, local_packages) {
    embed_rec(prune = prune, local_packages = local_packages)
    invisible(fs::path(output_dir, "runtime", "R"))
  })

  build_electron_app(app_dir, fs::path(tmp, "out"), app_type = "r-shiny",
                     runtime_strategy = "bundled", platform = "mac", arch = "arm64",
                     config = list(dependencies = list(r = list(prune = FALSE))),
                     verbose = FALSE)
  expect_false(mockery::mock_args(embed_rec)[[1]]$prune)
  expect_equal(mockery::mock_args(embed_rec)[[1]]$local_packages, character(0))

  # A quoted "false" in a config built in R also turns pruning off, with a
  # single warning from the up-front check.
  quoted_rec <- mockery::mock()
  withCallingHandlers(
    build_electron_app(app_dir, fs::path(tmp, "out2"), app_type = "r-shiny",
                       runtime_strategy = "bundled", platform = "mac", arch = "arm64",
                       config = list(dependencies = list(r = list(prune = "false"))),
                       verbose = FALSE),
    shinyelectron_quoted_flag = function(w) {
      quoted_rec()
      invokeRestart("muffleWarning")
    }
  )
  mockery::expect_called(quoted_rec, 1)
  # The second build is the recorder's second call.
  expect_false(mockery::mock_args(embed_rec)[[2]]$prune)
})

test_that("build_electron_app rejects a bad dependencies.r.prune before touching output or runtimes", {
  tmp <- withr::local_tempdir()
  app_dir <- fs::path(tmp, "app"); fs::dir_create(app_dir)
  writeLines("library(shiny)", fs::path(app_dir, "app.R"))
  out <- fs::path(tmp, "out"); fs::dir_create(out)
  writeLines("previous build", fs::path(out, "previous.txt"))

  # The real embed_r_runtime() runs; record whether it gets as far as
  # downloading or copying a runtime.
  calls_rec <- mockery::mock()
  record <- function(name, value = NULL) {
    force(value)
    function(...) {
      calls_rec(name)
      value
    }
  }
  local_mocked_bindings(
    validate_node_npm = function(...) invisible(TRUE),
    setup_electron_project = record("setup_electron_project"),
    copy_app_files = record("copy_app_files"),
    resolve_runtime_version = function(...) "4.6.1",
    install_r_portable = record("install_r_portable", fs::path(tmp, "cached-r")),
    copy_dir_contents = record("copy_dir_contents")
  )

  # A config built in R skips read_config(), so a value that is neither true
  # nor false must still stop the build, and before the previous output is
  # deleted.
  expect_error(
    build_electron_app(app_dir, out, app_type = "r-shiny",
                       runtime_strategy = "bundled", platform = "mac", arch = "arm64",
                       config = list(dependencies = list(r = list(prune = "maybe"))),
                       overwrite = TRUE, verbose = FALSE),
    "dependencies.r.prune",
    class = "shinyelectron_invalid_flag"
  )
  calls <- vapply(mockery::mock_args(calls_rec), `[[`, character(1), 1)
  expect_equal(calls, character(0))
  expect_true(fs::file_exists(fs::path(out, "previous.txt")))
})

test_that("build_electron_app falls back to the configured repositories without a dependency manifest", {
  skip_if_not_installed("mockery")
  tmp <- withr::local_tempdir()
  app_dir <- fs::path(tmp, "app"); fs::dir_create(app_dir)
  writeLines("library(shiny)", fs::path(app_dir, "app.R"))

  mockery::stub(build_electron_app, "validate_node_npm", function(...) invisible(TRUE))
  mockery::stub(build_electron_app, "setup_electron_project", function(...) invisible(TRUE))
  # Writes no dependencies.json.
  mockery::stub(build_electron_app, "copy_app_files", function(...) invisible(TRUE))
  mockery::stub(build_electron_app, "process_templates", function(...) invisible(TRUE))
  mockery::stub(build_electron_app, "install_npm_dependencies", function(...) invisible(TRUE))
  mockery::stub(build_electron_app, "build_for_platforms", function(...) invisible(TRUE))
  mockery::stub(build_electron_app, "validate_build_output", function(...) invisible(TRUE))
  mockery::stub(build_electron_app, "resolve_runtime_version", function(runtime, config) "4.4.1")

  embed_rec <- mockery::mock()
  mockery::stub(build_electron_app, "embed_r_runtime",
                function(output_dir, packages, repos, version, platform, arch,
                         verbose, prune, local_packages) {
    embed_rec(repos = repos)
    invisible(fs::path(output_dir, "runtime", "R"))
  })

  config <- list(dependencies = list(r = list(repos = list("https://example.org/cran"))))
  build_electron_app(app_dir, fs::path(tmp, "out1"), app_name = "test",
                     app_type = "r-shiny", runtime_strategy = "bundled",
                     platform = "mac", arch = "arm64", config = config,
                     verbose = FALSE)
  expect_equal(unlist(mockery::mock_args(embed_rec)[[1]]$repos), "https://example.org/cran")

  build_electron_app(app_dir, fs::path(tmp, "out2"), app_name = "test",
                     app_type = "r-shiny", runtime_strategy = "bundled",
                     platform = "mac", arch = "arm64", verbose = FALSE)
  expect_equal(unlist(mockery::mock_args(embed_rec)[[2]]$repos), "https://cloud.r-project.org")
})
