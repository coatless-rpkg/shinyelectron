test_that("portable_r_env drops site file overrides and keeps everything else", {
  withr::local_envvar(
    R_ENVIRON = "/elsewhere/Renviron.site", R_PROFILE = "/elsewhere/Rprofile.site",
    R_ENVIRON_USER = "/home/me/.Renviron", R_PROFILE_USER = "/home/me/.Rprofile",
    SHINYELECTRON_TEST_VAR = "kept"
  )

  env <- portable_r_env()

  expect_false(any(c("R_ENVIRON", "R_PROFILE") %in% names(env)))
  expect_equal(env[["R_ENVIRON_USER"]], "/home/me/.Renviron")
  expect_equal(env[["R_PROFILE_USER"]], "/home/me/.Rprofile")
  expect_equal(env[["SHINYELECTRON_TEST_VAR"]], "kept")
  expect_equal(env[["PATH"]], Sys.getenv("PATH"))
})

test_that("embed_r_runtime installs packages from an empty directory without site file overrides", {
  skip_if_not_installed("mockery")
  out <- withr::local_tempdir()
  # The caller works inside a project, as when export() runs in an renv project.
  project <- withr::local_tempdir()
  writeLines("source('renv/activate.R')", file.path(project, ".Rprofile"))
  withr::local_dir(project)
  withr::local_envvar(
    R_ENVIRON = "/elsewhere/Renviron.site", R_PROFILE = "/elsewhere/Rprofile.site",
    R_ENVIRON_USER = "/home/me/.Renviron", SHINYELECTRON_TEST_VAR = "kept"
  )

  mockery::stub(embed_r_runtime, "install_r_portable", function(...) fs::path(out, "cached-r"))
  mockery::stub(embed_r_runtime, "copy_dir_contents", function(src, dst) {
    fs::dir_create(fs::path(dst, "bin"), recurse = TRUE)
    writeLines("#!/bin/sh", fs::path(dst, "bin", "Rscript"))
    invisible(dst)
  })
  mockery::stub(embed_r_runtime, "r_executable",
                function(...) fs::path(out, "runtime", "R", "bin", "Rscript"))
  mockery::stub(embed_r_runtime, "utils::available.packages",
                function(repos) matrix(nrow = 0, ncol = 0))
  mockery::stub(embed_r_runtime, "tools::package_dependencies", function(...) list())
  mockery::stub(embed_r_runtime, "detect_current_platform", function() "mac")
  seen <- NULL
  mockery::stub(embed_r_runtime, "processx::run", function(command, args, ..., wd = NULL, env = NULL) {
    seen <<- list(
      wd = wd, env = env, wd_exists = !is.null(wd) && dir.exists(wd),
      wd_files = if (!is.null(wd)) list.files(wd, all.files = TRUE, no.. = TRUE),
      wd_is_project = !is.null(wd) && identical(normalizePath(wd), normalizePath(project))
    )
    fs::dir_create(fs::path(out, "runtime", "R", "library", "shiny"), recurse = TRUE)
    list(status = 0, stdout = "", stderr = "")
  })

  embed_r_runtime(
    output_dir = out, packages = "shiny", repos = "https://cloud.r-project.org",
    version = "4.6.1", platform = "mac", arch = "arm64", verbose = FALSE
  )

  # An empty directory of its own, removed afterwards.
  expect_true(seen$wd_exists)
  expect_length(seen$wd_files, 0)
  expect_false(seen$wd_is_project)
  expect_false(dir.exists(seen$wd))
  # Site file overrides are dropped; the user's files and the rest are kept.
  expect_false(any(c("R_ENVIRON", "R_PROFILE") %in% names(seen$env)))
  expect_equal(seen$env[["R_ENVIRON_USER"]], "/home/me/.Renviron")
  expect_equal(seen$env[["SHINYELECTRON_TEST_VAR"]], "kept")
})

# Build a package with compiled code with the R running the tests and publish
# the binary in a local repository that the portable R `rscript` installs
# binaries from. Like a CRAN binary, it links the R framework by absolute path.
local_framework_binary_repo <- function(work, rscript) {
  src <- file.path(work, "tinycpkg")
  dir.create(file.path(src, "R"), recursive = TRUE)
  dir.create(file.path(src, "src"))
  writeLines(c(
    "Package: tinycpkg", "Version: 0.1.0", "Title: Test Package",
    "Description: A package used in tests.", "Author: Test Author",
    "Maintainer: Test Author <test@example.com>", "License: GPL-3"
  ), file.path(src, "DESCRIPTION"))
  writeLines(c("useDynLib(tinycpkg, .registration = TRUE)", "export(answer)"),
             file.path(src, "NAMESPACE"))
  writeLines("answer <- function() .Call(answer_c)", file.path(src, "R", "answer.R"))
  writeLines(c(
    "#include <R.h>",
    "#include <Rinternals.h>",
    "#include <R_ext/Rdynload.h>",
    "SEXP answer_c(void) { return Rf_ScalarInteger(42); }",
    "static const R_CallMethodDef entries[] = {{\"answer_c\", (DL_FUNC) &answer_c, 0}, {NULL, NULL, 0}};",
    "void R_init_tinycpkg(DllInfo *dll) {",
    "  R_registerRoutines(dll, NULL, entries, NULL, NULL);",
    "  R_useDynamicSymbols(dll, FALSE);",
    "}"
  ), file.path(src, "src", "answer.c"))

  build <- file.path(work, "build")
  host_lib <- file.path(work, "host-lib")
  dir.create(build)
  dir.create(host_lib)
  built <- processx::run(
    file.path(R.home("bin"), "R"), c("CMD", "INSTALL", "--build", "-l", host_lib, src),
    wd = build, error_on_status = FALSE
  )
  binary <- list.files(build, pattern = "\\.tgz$", full.names = TRUE)
  skip_if(built$status != 0 || length(binary) != 1,
          "Could not build a binary package with the R running the tests")
  links <- tryCatch(
    system2("otool", c("-L", file.path(host_lib, "tinycpkg", "libs", "tinycpkg.so")),
            stdout = TRUE),
    error = function(e) character(0)
  )
  skip_if_not(any(grepl("/Library/Frameworks/R.framework", links, fixed = TRUE)),
              "The R running the tests does not link the R framework")

  repo <- file.path(work, "repo")
  contrib <- processx::run(rscript, c(
    "--vanilla", "-e", sprintf("cat(contrib.url('file://%s', type = 'binary'))", repo)
  ))$stdout
  binary_dir <- sub("^file://", "", contrib)
  dir.create(binary_dir, recursive = TRUE)
  file.copy(binary, binary_dir)
  tools::write_PACKAGES(binary_dir, type = "mac.binary")
  # The calling R resolves dependencies from the source index.
  source_dir <- file.path(repo, "src", "contrib")
  dir.create(source_dir, recursive = TRUE)
  file.copy(list.files(binary_dir, pattern = "^PACKAGES", full.names = TRUE), source_dir)
  repo
}

test_that("embed_r_runtime installs with the portable R's own startup files", {
  skip_on_cran()
  skip_if_not_installed("mockery")
  skip_if_not(identical(detect_current_platform(), "mac"),
              "The portable R's shared-library fix-up is macOS only")
  version <- SHINYELECTRON_DEFAULTS$runtime_versions$r
  arch <- detect_current_arch()
  rscript <- r_executable(version, "mac", arch)
  skip_if(is.null(rscript), "The portable R is not cached")

  work <- withr::local_tempdir()
  repo <- local_framework_binary_repo(work, rscript)
  marks <- file.path(work, "marks")
  dir.create(marks)
  # A project profile in the working directory, as renv's autoloader is.
  project <- file.path(work, "project")
  dir.create(project)
  writeLines(sprintf("writeLines('ran', '%s')", file.path(marks, "project-profile")),
             file.path(project, ".Rprofile"))
  # A site profile chosen for the calling R, which skips the portable R's own
  # Rprofile.site and its fix-up.
  site_profile <- file.path(work, "site.Rprofile")
  writeLines(sprintf("writeLines('ran', '%s')", file.path(marks, "site-profile")),
             site_profile)
  withr::local_dir(project)
  withr::local_envvar(R_PROFILE = site_profile)
  mockery::stub(embed_r_runtime, "install_r_portable",
                function(...) r_install_path(version, "mac", arch))
  mockery::stub(embed_r_runtime, "copy_dir_contents", function(src, dst) {
    fs::dir_create(dst, recurse = TRUE)
    invisible(dst)
  })
  out <- file.path(work, "out")
  dir.create(out)

  embed_r_runtime(
    output_dir = out, packages = "tinycpkg", repos = paste0("file://", repo),
    version = version, platform = "mac", arch = arch, verbose = FALSE
  )

  expect_length(list.files(marks), 0)
  lib <- file.path(out, "runtime", "R", "library")
  links <- system2("otool", c("-L", file.path(lib, "tinycpkg", "libs", "tinycpkg.so")),
                   stdout = TRUE)
  expect_false(any(grepl("/Library/Frameworks/R.framework", links, fixed = TRUE)))
  loaded <- processx::run(
    rscript, c("--vanilla", "-e", "cat(tinycpkg::answer())"),
    env = c("current", R_LIBS = lib), wd = work, error_on_status = FALSE
  )
  expect_equal(loaded$stdout, "42")
})
