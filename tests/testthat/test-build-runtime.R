# tests/testthat/test-build-runtime.R

test_that("embed_r_runtime resolves the recursive closure minus pre_installed and targets the sibling library", {
  skip_if_not_installed("mockery")
  out <- withr::local_tempdir()

  install_r_called <- NULL
  mockery::stub(embed_r_runtime, "install_r_portable", function(version, platform, arch, verbose) {
    install_r_called <<- list(version = version, platform = platform, arch = arch)
    fs::path(out, "cached-r")
  })

  copy_called <- NULL
  mockery::stub(embed_r_runtime, "copy_dir_contents", function(src, dst) {
    copy_called <<- list(src = src, dst = dst)
    # Pre-populate one transitive dep so the pre_installed setdiff is exercised,
    # and drop a real Rscript so the cached-binary existence check passes.
    fs::dir_create(fs::path(dst, "library", "rlang"), recurse = TRUE)
    fs::dir_create(fs::path(dst, "bin"))
    writeLines("#!/bin/sh", fs::path(dst, "bin", "Rscript"))
    invisible(dst)
  })

  mockery::stub(embed_r_runtime, "r_executable",
                function(version, platform, arch) fs::path(out, "runtime", "R", "bin", "Rscript"))

  mockery::stub(embed_r_runtime, "utils::available.packages",
                function(repos) matrix(nrow = 0, ncol = 0))
  mockery::stub(embed_r_runtime, "tools::package_dependencies",
                function(packages, db, which, recursive) {
                  list(shiny = c("htmltools", "rlang"), htmltools = "rlang")
                })
  # Force the non-linux binary clause so the captured r_code is deterministic.
  mockery::stub(embed_r_runtime, "detect_current_platform", function() "mac")

  run_args <- NULL
  mockery::stub(embed_r_runtime, "processx::run", function(command, args, ...) {
    run_args <<- list(command = command, args = args)
    lib <- fs::path(out, "runtime", "R", "library")
    for (p in c("shiny", "htmltools")) fs::dir_create(fs::path(lib, p))
    list(status = 0, stdout = "", stderr = "")
  })

  embed_r_runtime(
    output_dir = out,
    packages = c("shiny", "htmltools"),
    repos = c(CRAN = "https://cloud.r-project.org"),
    version = "4.4.1",
    platform = "mac",
    arch = "arm64",
    verbose = FALSE
  )

  # Runtime install + copy happened with the resolved version and scalar plat/arch.
  expect_equal(install_r_called$version, "4.4.1")
  expect_equal(install_r_called$platform, "mac")
  expect_equal(install_r_called$arch, "arm64")
  expect_equal(copy_called$dst, fs::path(out, "runtime", "R"))

  # The install ran against the SIBLING runtime/R/library path.
  r_code <- run_args$args[[2]]
  expect_match(r_code, "runtime/R/library", fixed = TRUE)

  # Resolved set == recursive closure {shiny,htmltools,rlang} minus pre_installed {rlang}.
  expect_match(r_code, "'shiny'", fixed = TRUE)
  expect_match(r_code, "'htmltools'", fixed = TRUE)
  expect_false(grepl("'rlang'", r_code, fixed = TRUE))
})

test_that("embed_r_runtime embeds the interpreter even when packages is empty", {
  skip_if_not_installed("mockery")
  out <- withr::local_tempdir()

  install_r_called <- FALSE
  mockery::stub(embed_r_runtime, "install_r_portable", function(version, platform, arch, verbose) {
    install_r_called <<- TRUE
    fs::path(out, "cached-r")
  })
  copy_called <- FALSE
  mockery::stub(embed_r_runtime, "copy_dir_contents", function(src, dst) {
    copy_called <<- TRUE
    fs::dir_create(dst, recurse = TRUE)
    invisible(dst)
  })
  run_called <- FALSE
  mockery::stub(embed_r_runtime, "processx::run", function(...) {
    run_called <<- TRUE
    list(status = 0, stdout = "", stderr = "")
  })
  # The package-install branch (and thus r_executable) must not be entered.
  mockery::stub(embed_r_runtime, "r_executable",
                function(...) stop("r_executable must not be called for empty packages"))

  embed_r_runtime(
    output_dir = out,
    packages = character(0),
    repos = c(CRAN = "https://cloud.r-project.org"),
    version = "4.4.1",
    platform = "mac",
    arch = "arm64",
    verbose = FALSE
  )

  expect_true(install_r_called)   # interpreter still installed
  expect_true(copy_called)        # runtime still copied
  expect_false(run_called)        # install.packages NOT invoked
})

# --- Python runtime embedding ---

test_that("embed_python_runtime targets bundled site-packages and embeds unconditionally", {
  skip_if_not_installed("mockery")
  out <- withr::local_tempdir()

  install_called <- FALSE
  mockery::stub(embed_python_runtime, "install_python_standalone", function(version, platform, arch, verbose) {
    install_called <<- TRUE
    fs::path(out, "cached-py")
  })
  copy_dst <- NULL
  mockery::stub(embed_python_runtime, "copy_dir_contents", function(src, dst) {
    copy_dst <<- dst
    fs::dir_create(dst, recurse = TRUE)
    invisible(dst)
  })
  mockery::stub(embed_python_runtime, "python_executable",
                function(version, platform, arch) fs::path(out, "cached-py", "bin", "python3"))

  pip_args <- NULL
  mockery::stub(embed_python_runtime, "processx::run", function(command, args, ...) {
    pip_args <<- args
    list(status = 0, stdout = "", stderr = "")
  })

  embed_python_runtime(
    output_dir = out,
    packages = c("shiny", "pandas"),
    index_urls = "https://pypi.org/simple",
    version = "3.14.6",
    platform = "mac",
    arch = "arm64",
    verbose = FALSE
  )

  expect_true(install_called)
  expect_equal(copy_dst, fs::path(out, "runtime", "Python"))

  target_idx <- which(pip_args == "--target")
  expect_length(target_idx, 1)
  expect_equal(
    pip_args[[target_idx + 1]],
    as.character(fs::path(out, "runtime", "Python", "lib", "python", "site-packages"))
  )
  expect_true(all(c("shiny", "pandas") %in% pip_args))
})

test_that("embed_python_runtime warns (does not abort) when pip fails", {
  skip_if_not_installed("mockery")
  out <- withr::local_tempdir()
  mockery::stub(embed_python_runtime, "install_python_standalone", function(...) fs::path(out, "cached-py"))
  mockery::stub(embed_python_runtime, "copy_dir_contents", function(src, dst) {
    fs::dir_create(dst, recurse = TRUE); invisible(dst)
  })
  mockery::stub(embed_python_runtime, "python_executable",
                function(...) fs::path(out, "cached-py", "bin", "python3"))
  mockery::stub(embed_python_runtime, "processx::run",
                function(...) list(status = 1, stdout = "", stderr = "boom"))

  expect_warning(
    embed_python_runtime(
      output_dir = out, packages = "shiny", index_urls = "https://pypi.org/simple",
      version = "3.14.6", platform = "mac", arch = "arm64", verbose = FALSE
    ),
    "Failed to install some Python packages"
  )
})

test_that("embed_python_runtime embeds the interpreter even when packages is empty", {
  skip_if_not_installed("mockery")
  out <- withr::local_tempdir()
  install_called <- FALSE
  mockery::stub(embed_python_runtime, "install_python_standalone", function(...) {
    install_called <<- TRUE; fs::path(out, "cached-py")
  })
  copy_called <- FALSE
  mockery::stub(embed_python_runtime, "copy_dir_contents", function(src, dst) {
    copy_called <<- TRUE; fs::dir_create(dst, recurse = TRUE); invisible(dst)
  })
  mockery::stub(embed_python_runtime, "python_executable",
                function(...) fs::path(out, "cached-py", "bin", "python3"))
  run_called <- FALSE
  mockery::stub(embed_python_runtime, "processx::run", function(...) {
    run_called <<- TRUE; list(status = 0, stdout = "", stderr = "")
  })

  embed_python_runtime(
    output_dir = out, packages = character(0), index_urls = "https://pypi.org/simple",
    version = "3.14.6", platform = "mac", arch = "arm64", verbose = FALSE
  )

  expect_true(install_called)
  expect_true(copy_called)
  expect_false(run_called)   # pip install NOT invoked
})
