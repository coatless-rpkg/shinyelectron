# Write a minimal R package source folder under `parent` and return its path.
write_local_pkg <- function(parent, name, fields = character(), dir_name = name,
                            namespace = "", r_code = NULL) {
  dir <- file.path(parent, dir_name)
  dir.create(file.path(dir, "R"), recursive = TRUE, showWarnings = FALSE)
  writeLines(c(
    paste0("Package: ", name), "Version: 0.0.1", "Title: Test Package",
    "Description: A package used in tests.", "Author: Test Author",
    "Maintainer: Test Author <test@example.com>", "License: GPL-3",
    "Encoding: UTF-8", fields
  ), file.path(dir, "DESCRIPTION"))
  writeLines(namespace, file.path(dir, "NAMESPACE"))
  if (!is.null(r_code)) writeLines(r_code, file.path(dir, "R", "code.R"))
  dir
}

# Pack `<parent>/<folder>` into a gzipped tarball `<parent>/<file>`.
tar_local_pkg <- function(parent, folder, file) {
  withr::with_dir(parent, utils::tar(
    file, files = folder, compression = "gzip", tar = "internal"
  ))
  file.path(parent, file)
}

# Write a single-app directory whose config sets `config`.
write_app_with_config <- function(appdir, config) {
  dir.create(appdir, recursive = TRUE, showWarnings = FALSE)
  writeLines("library(shiny)", file.path(appdir, "app.R"))
  yaml::write_yaml(config, file.path(appdir, "_shinyelectron.yml"))
  appdir
}

# Write a two-app R suite whose root config merges in `config`.
write_suite_with_config <- function(suite, config) {
  for (id in c("one", "two")) {
    dir.create(file.path(suite, "apps", id), recursive = TRUE, showWarnings = FALSE)
    writeLines("library(shiny)", file.path(suite, "apps", id, "app.R"))
  }
  config$apps <- list(
    list(id = "one", name = "One", path = "apps/one"),
    list(id = "two", name = "Two", path = "apps/two")
  )
  yaml::write_yaml(config, file.path(suite, "_shinyelectron.yml"))
  suite
}

test_that("local_r_package_names resolves directories and archives", {
  parent <- withr::local_tempdir()
  dir <- write_local_pkg(parent, "MyPkg")
  # GitHub archives name their top-level folder <repo>-<ref>; the package name
  # comes from the DESCRIPTION inside, not from the file name.
  write_local_pkg(parent, "SeuratExplorer", dir_name = "SeuratExplorer-main")
  archive <- tar_local_pkg(parent, "SeuratExplorer-main", "SeuratExplorer_0.1.9.tar.gz")

  expect_equal(local_r_package_names(dir), "MyPkg")
  expect_equal(
    local_r_package_names(c(dir, archive)),
    c("MyPkg", "SeuratExplorer")
  )
  expect_equal(local_r_package_names(character(0)), character(0))
  expect_equal(local_r_package_names(list()), character(0))
})

test_that("local_r_package_deps reads declared deps and drops base packages", {
  dir <- file.path(tempfile("pkg-"), "MyPkg")
  dir.create(file.path(dir, "R"), recursive = TRUE)
  writeLines(c(
    "Package: MyPkg", "Version: 0.1.0", "Title: t", "Description: t.",
    "License: MIT", "Encoding: UTF-8",
    "Depends: R (>= 4.1.0), shiny",
    "Imports: stats, Seurat (>= 5.0.0), Rcpp",
    "LinkingTo: RcppArmadillo",
    "Suggests: testthat"
  ), file.path(dir, "DESCRIPTION"))
  writeLines("", file.path(dir, "NAMESPACE"))

  deps <- local_r_package_deps(dir)
  expect_true(all(c("shiny", "Seurat", "Rcpp", "RcppArmadillo") %in% deps))
  expect_false("R" %in% deps)
  expect_false("stats" %in% deps)
  expect_false("testthat" %in% deps)

  expect_equal(local_r_package_deps(character(0)), character(0))
})

test_that("local_r_package_info strips version constraints that span lines", {
  parent <- withr::local_tempdir()
  dir <- write_local_pkg(parent, "WrapPkg", fields = c(
    "Imports: jsonlite (>=", "    1.8.0), cli"
  ))
  expect_equal(local_r_package_info(dir)$WrapPkg$deps, c("jsonlite", "cli"))
})

test_that("an archive's name comes from its top-level DESCRIPTION only", {
  parent <- withr::local_tempdir()
  write_local_pkg(parent, "TopPkg")
  # A nested DESCRIPTION in a folder that sorts first must not win.
  write_local_pkg(file.path(parent, "TopPkg"), "NestedPkg", dir_name = "AAA")
  archive <- tar_local_pkg(parent, "TopPkg", "TopPkg_0.0.1.tar.gz")

  expect_equal(local_r_package_names(archive), "TopPkg")
})

test_that("a tarball's DESCRIPTION is read once until the file changes", {
  skip_if_not_installed("mockery")
  parent <- withr::local_tempdir()
  write_local_pkg(parent, "OncePkg")
  archive <- tar_local_pkg(parent, "OncePkg", "OncePkg_0.0.1.tar.gz")
  # Called once per listing of the archive.
  listings <- mockery::mock()
  real_untar <- utils::untar
  mockery::stub(local_read_archive_description, "utils::untar", function(tarfile, ...) {
    if (isTRUE(list(...)$list)) listings()
    real_untar(tarfile, ...)
  })

  for (i in 1:3) {
    expect_equal(unname(local_read_archive_description(archive)[1, "Package"]), "OncePkg")
  }
  mockery::expect_called(listings, 1)

  Sys.setFileTime(archive, Sys.time() + 10)
  local_read_archive_description(archive)
  mockery::expect_called(listings, 2)
})

test_that("a git archive tarball is read with R's own tar", {
  git <- Sys.which("git")
  skip_if(!nzchar(git), "git is not available")
  parent <- withr::local_tempdir()
  repo <- write_local_pkg(parent, "GitPkg")
  # Work on the temporary repository only, whatever git settings are around.
  withr::local_envvar(GIT_DIR = NA, GIT_WORK_TREE = NA, GIT_INDEX_FILE = NA)
  run_git <- function(...) {
    processx::run(git, c("-c", "user.name=Test", "-c", "user.email=test@example.com",
                         "-c", "commit.gpgsign=false", ...), wd = repo)
  }
  run_git("init", "-q")
  run_git("add", "-A")
  run_git("commit", "-q", "--no-verify", "-m", "Add package")
  archive <- file.path(parent, "GitPkg_0.0.1.tar.gz")
  run_git("archive", "--format=tar.gz", "--prefix=GitPkg-main/", "-o", archive, "HEAD")
  # git archive writes a pax global header, which R's own tar warns about.
  withr::local_envvar(TAR = "internal")

  expect_equal(local_r_package_names(archive), "GitPkg")
})

test_that("resolve_local_packages resolves relative paths against the app directory", {
  appdir <- withr::local_tempdir()
  write_local_pkg(file.path(appdir, "pkgs"), "InApp")
  sibling <- withr::local_tempdir()
  write_local_pkg(sibling, "Sibling")
  # Run from somewhere else: the working directory must not matter.
  withr::local_dir(withr::local_tempdir())

  resolved <- resolve_local_packages(
    list("pkgs/InApp", file.path("..", basename(sibling), "Sibling")),
    base_dir = appdir
  )

  expect_true(all(fs::is_absolute_path(resolved)))
  expect_equal(
    normalizePath(resolved),
    normalizePath(c(file.path(appdir, "pkgs", "InApp"), file.path(sibling, "Sibling")))
  )
})

test_that("resolve_local_packages rejects paths that are not package sources", {
  appdir <- withr::local_tempdir()

  expect_error(
    resolve_local_packages("missing", appdir),
    class = "shinyelectron_local_packages_missing"
  )

  dir.create(file.path(appdir, "empty"))
  expect_error(
    resolve_local_packages("empty", appdir),
    "DESCRIPTION", class = "shinyelectron_local_packages_invalid"
  )

  writeLines("not a zip", file.path(appdir, "pkg.zip"))
  expect_error(
    resolve_local_packages("pkg.zip", appdir),
    "zip", class = "shinyelectron_local_packages_invalid"
  )

  writeLines("not a package", file.path(appdir, "pkg.txt"))
  expect_error(
    resolve_local_packages("pkg.txt", appdir),
    class = "shinyelectron_local_packages_invalid"
  )

  # Installed and binary builds carry a Built field.
  write_local_pkg(appdir, "BinPkg",
                  fields = "Built: R 4.6.1; ; 2026-01-01 00:00:00 UTC; unix")
  tar_local_pkg(appdir, "BinPkg", "BinPkg_0.0.1.tgz")
  expect_error(
    resolve_local_packages("BinPkg_0.0.1.tgz", appdir),
    "binary", class = "shinyelectron_local_packages_invalid"
  )
  expect_error(
    resolve_local_packages("BinPkg", appdir),
    "installed", class = "shinyelectron_local_packages_invalid"
  )
})

test_that("resolve_local_packages rejects duplicates and entries that are not paths", {
  appdir <- withr::local_tempdir()
  write_local_pkg(appdir, "DupPkg")
  write_local_pkg(appdir, "DupPkg", dir_name = "DupPkg-copy")

  expect_error(
    resolve_local_packages(list("DupPkg", "DupPkg-copy"), appdir),
    "DupPkg", class = "shinyelectron_local_packages_invalid"
  )
  expect_error(
    resolve_local_packages(list("DupPkg", 42), appdir),
    class = "shinyelectron_local_packages_invalid"
  )
})

test_that("resolve_local_packages requires a bundled R app", {
  expect_error(
    resolve_local_packages("pkgs/MyPkg", tempdir(), bundled_r = FALSE),
    class = "shinyelectron_local_packages_strategy"
  )
  expect_equal(resolve_local_packages(list(), tempdir(), bundled_r = FALSE), character(0))
  expect_equal(resolve_local_packages(NULL, tempdir(), bundled_r = FALSE), character(0))
})

test_that("export() rejects local packages unless the R app uses the bundled strategy", {
  appdir <- write_app_with_config(
    file.path(withr::local_tempdir(), "app"),
    list(dependencies = list(r = list(local_packages = list("../MyPkg"))))
  )
  destdir <- file.path(withr::local_tempdir(), "out")

  # shinylive is the default strategy
  expect_error(
    export(appdir, destdir, verbose = FALSE),
    class = "shinyelectron_local_packages_strategy"
  )
  expect_error(
    export(appdir, destdir, runtime_strategy = "system", verbose = FALSE),
    class = "shinyelectron_local_packages_strategy"
  )
  expect_false(dir.exists(destdir))
})

test_that("export() resolves local packages against the app directory", {
  root <- withr::local_tempdir()
  write_local_pkg(root, "MyPkg")
  appdir <- write_app_with_config(file.path(root, "app"), list(
    build = list(runtime_strategy = "bundled"),
    dependencies = list(r = list(local_packages = list("../MyPkg")))
  ))

  prep <- mockery::mock()
  local_mocked_bindings(
    prepare_native_app_files = function(appdir, destdir, app_type, runtime_strategy,
                                        platform, arch, config, verbose = TRUE) {
      prep(local_packages = config$dependencies$r$local_packages)
      list(converted_app = destdir, dependencies = NULL)
    }
  )
  withr::local_dir(withr::local_tempdir())

  export(appdir, file.path(root, "out"), build = FALSE, verbose = FALSE)

  captured <- mockery::mock_args(prep)[[1]]$local_packages
  expect_equal(normalizePath(captured), normalizePath(file.path(root, "MyPkg")))
})

test_that("export() rejects local packages in a suite without a bundled R app", {
  suite <- write_suite_with_config(withr::local_tempdir(), list(
    build = list(type = "r-shiny", runtime_strategy = "shinylive"),
    dependencies = list(r = list(local_packages = list("pkgs/MyPkg")))
  ))
  destdir <- file.path(withr::local_tempdir(), "out")

  expect_error(
    export(suite, destdir, verbose = FALSE),
    class = "shinyelectron_local_packages_strategy"
  )
  expect_false(dir.exists(destdir))
})

test_that("export() resolves suite local packages against the suite root", {
  suite <- write_suite_with_config(withr::local_tempdir(), list(
    build = list(type = "r-shiny", runtime_strategy = "bundled"),
    dependencies = list(r = list(local_packages = list("pkgs/MyPkg")))
  ))
  write_local_pkg(file.path(suite, "pkgs"), "MyPkg")

  manifest <- mockery::mock()
  build <- mockery::mock()
  local_mocked_bindings(
    resolve_app_dependencies = function(appdir, app_type, runtime_strategy, config) {
      list(language = "r", packages = c("shiny", "MyPkg"), repos = list())
    },
    generate_dependency_manifest = function(...) {
      manifest(local_packages = list(...)$local_packages)
      "{}"
    },
    build_multi_app = function(...) {
      build(local_packages = list(...)$config$dependencies$r$local_packages)
      "electron-app"
    }
  )
  withr::local_dir(withr::local_tempdir())

  export(suite, file.path(withr::local_tempdir(), "out"),
         platform = "mac", arch = "arm64", verbose = FALSE)

  captured <- mockery::mock_args(build)[[1]]$local_packages
  expect_equal(normalizePath(captured), normalizePath(file.path(suite, "pkgs", "MyPkg")))
  # Local package names are kept out of the system-requirements lookup.
  # The manifest is generated more than once; check the last one.
  manifest_args <- mockery::mock_args(manifest)
  expect_equal(manifest_args[[length(manifest_args)]]$local_packages, "MyPkg")
})

test_that("generate_dependency_manifest keeps local packages out of the sysreqs lookup", {
  sysreqs <- mockery::mock()
  local_mocked_bindings(query_sysreqs = function(pkgs, distribution, release) {
    sysreqs(pkgs = pkgs)
    character(0)
  })

  manifest <- jsonlite::fromJSON(generate_dependency_manifest(
    packages = c("shiny", "MyPkg"), language = "r", local_packages = "MyPkg"
  ))
  queried <- lapply(mockery::mock_args(sysreqs), `[[`, "pkgs")

  expect_equal(manifest$packages, c("shiny", "MyPkg"))
  expect_length(queried, 2)
  for (pkgs in queried) expect_equal(pkgs, "shiny")
})

test_that("export() keeps local packages out of the sysreqs lookup", {
  skip_if_not_installed("renv")
  root <- withr::local_tempdir()
  write_local_pkg(root, "MyPkg")
  appdir <- write_app_with_config(file.path(root, "app"), list(
    build = list(runtime_strategy = "bundled"),
    dependencies = list(r = list(local_packages = list("../MyPkg")))
  ))
  writeLines(c("library(shiny)", "library(MyPkg)"), file.path(appdir, "app.R"))

  sysreqs <- mockery::mock()
  local_mocked_bindings(query_sysreqs = function(pkgs, distribution, release) {
    sysreqs(pkgs = pkgs)
    character(0)
  })

  result <- export(appdir, file.path(root, "out"), build = FALSE, verbose = FALSE)
  queried <- lapply(mockery::mock_args(sysreqs), `[[`, "pkgs")

  expect_true("MyPkg" %in% result$dependencies$packages)
  expect_true(length(queried) > 0)
  for (pkgs in queried) {
    expect_true("shiny" %in% pkgs)
    expect_false("MyPkg" %in% pkgs)
  }
})

test_that("embed_r_runtime checks local packages before downloading R", {
  skip_if_not_installed("mockery")
  out <- withr::local_tempdir()
  download <- mockery::mock()
  mockery::stub(embed_r_runtime, "install_r_portable", function(...) {
    download(...)
    fs::path(out, "cached-r")
  })

  expect_error(
    embed_r_runtime(
      output_dir = out, packages = "shiny", repos = NULL, version = "4.4.1",
      platform = "mac", arch = "arm64", verbose = FALSE,
      local_packages = file.path(out, "missing")
    ),
    class = "shinyelectron_local_packages_missing"
  )
  mockery::expect_called(download, 0)
})

test_that("local_r_install_order installs local dependencies first", {
  parent <- withr::local_tempdir()
  paths <- c(
    write_local_pkg(parent, "appPkg", fields = "Imports: midPkg, shiny"),
    write_local_pkg(parent, "loosePkg"),
    write_local_pkg(parent, "midPkg", fields = "Depends: R (>= 4.1.0), basePkg"),
    write_local_pkg(parent, "basePkg", fields = "LinkingTo: Rcpp")
  )

  expect_equal(
    local_r_install_order(local_r_package_info(paths)),
    c("loosePkg", "basePkg", "midPkg", "appPkg")
  )
})

test_that("local_r_install_order rejects a dependency cycle", {
  parent <- withr::local_tempdir()
  paths <- c(
    write_local_pkg(parent, "cycA", fields = "Imports: cycB"),
    write_local_pkg(parent, "cycB", fields = "Imports: cycA")
  )

  expect_error(
    local_r_install_order(local_r_package_info(paths)),
    class = "shinyelectron_local_packages_cycle"
  )
})

test_that("check_local_r_package_loads trusts the sentinel line, not the exit status", {
  skip_if_not_installed("mockery")
  run_result <- NULL
  run <- mockery::mock()
  mockery::stub(check_local_r_package_loads, "processx::run",
                function(command, args, ...) {
                  run(args = args)
                  run_result
                })

  # A crash while the process exits (seen on Windows) after a successful load.
  run_result <- list(status = -1073741819L, stdout = "\n<<SE_LOAD_OK>>\r\n",
                     stderr = "", timeout = FALSE)
  expect_true(check_local_r_package_loads("Rscript", "pkg", "lib", "current")$ok)
  # The marker is flushed before the process can crash on exit.
  expect_match(mockery::mock_args(run)[[1]]$args[[2]], "<<SE_LOAD_OK>>.*flush\\(stdout\\(\\)\\)")

  run_result <- list(status = 1L, stdout = "",
                     stderr = "Error: .onLoad failed", timeout = FALSE)
  expect_false(check_local_r_package_loads("Rscript", "pkg", "lib", "current")$ok)
})

test_that("local installs keep the caller's environment and use the unstaged install only on Windows", {
  skip_if_not_installed("mockery")
  lib <- withr::local_tempdir()
  run <- mockery::mock()
  mockery::stub(install_local_r_package, "processx::run", function(command, args, ...) {
    run(command = command, args = args, env = list(...)$env)
    list(status = 0L, stdout = "", stderr = NULL, timeout = FALSE)
  })
  mockery::stub(install_local_r_package, "check_local_r_package_loads", function(...) {
    list(ok = TRUE, stdout = "", stderr = "", timeout = FALSE)
  })

  mockery::stub(install_local_r_package, "detect_current_platform", function() "mac")
  install_local_r_package("Rscript", "pkg", "pkg_0.0.1.tar.gz", lib, verbose = FALSE)
  captured <- mockery::mock_args(run)[[1]]
  expect_equal(captured$env[["PATH"]], Sys.getenv("PATH"))
  expect_equal(captured$env[["R_LIBS_SITE"]], lib)
  expect_false(grepl("--no-staged-install", captured$args[[2]], fixed = TRUE))

  mockery::stub(install_local_r_package, "detect_current_platform", function() "win")
  install_local_r_package("Rscript", "pkg", "pkg_0.0.1.tar.gz", lib, verbose = FALSE)
  captured <- mockery::mock_args(run)[[2]]
  expect_match(captured$args[[2]], "--no-staged-install", fixed = TRUE)
  expect_match(captured$args[[2]], "--no-clean-on-error", fixed = TRUE)
})

test_that("local_r_env keeps the caller's environment but not its R startup file overrides", {
  startup <- file.path(withr::local_tempdir(),
                       c("site.Renviron", "site.Rprofile", "user.Renviron", "user.Rprofile"))
  file.create(startup)
  withr::local_envvar(
    R_ENVIRON = startup[[1]], R_PROFILE = startup[[2]],
    R_ENVIRON_USER = startup[[3]], R_PROFILE_USER = startup[[4]],
    R_LIBS_SITE = "/elsewhere/site-library", SHINYELECTRON_TEST_VAR = "kept"
  )

  env <- local_r_env("/abs/lib")

  expect_false(any(c("R_ENVIRON", "R_PROFILE") %in% names(env)))
  expect_false(anyDuplicated(names(env)) > 0)
  # The user files point at paths that do not exist, so R reads none.
  expect_false(file.exists(env[["R_ENVIRON_USER"]]))
  expect_false(file.exists(env[["R_PROFILE_USER"]]))
  expect_equal(unname(env[c("R_LIBS", "R_LIBS_USER", "R_LIBS_SITE")]), rep("/abs/lib", 3))
  expect_equal(env[["SHINYELECTRON_TEST_VAR"]], "kept")
})

test_that("a timed-out local install fails and leaves no lock directory", {
  skip_if_not_installed("mockery")
  lib <- withr::local_tempdir()
  mockery::stub(install_local_r_package, "processx::run", function(...) {
    # What a killed install leaves behind.
    dir.create(file.path(lib, "00LOCK-slowpkg", "00new", "slowpkg"), recursive = TRUE)
    dir.create(file.path(lib, "slowpkg"))
    list(status = NA_integer_, stdout = "", stderr = NULL, timeout = TRUE)
  })

  expect_error(
    install_local_r_package("Rscript", "slowpkg", "slowpkg_0.0.1.tar.gz", lib,
                            timeout = 90, verbose = FALSE),
    "90 seconds", class = "shinyelectron_local_packages_install"
  )
  expect_length(list.files(lib, all.files = TRUE, no.. = TRUE), 0)
})

# Real installs with the R running the tests; each builds a tarball first.
local_test_rscript <- function() {
  rscript <- file.path(
    R.home("bin"),
    if (.Platform$OS.type == "windows") "Rscript.exe" else "Rscript"
  )
  skip_if_not(file.exists(rscript), "Rscript not available")
  rscript
}

test_that("install_local_r_packages installs local packages in dependency order", {
  skip_on_cran()
  rscript <- local_test_rscript()
  src <- withr::local_tempdir()
  lib <- withr::local_tempdir()

  hello <- write_local_pkg(
    src, "hello", fields = "Imports: depPkg",
    namespace = c("export(greet)", "import(depPkg)"),
    r_code = "greet <- function() depfun()"
  )
  dep <- write_local_pkg(
    src, "depPkg", dir_name = "depPkg-src", namespace = "export(depfun)",
    r_code = "depfun <- function() 1"
  )
  # A work-in-progress file that .Rbuildignore keeps out of the package:
  # installing the folder directly would fail to parse it, the built tarball
  # does not contain it.
  writeLines("scratch <- function( {", file.path(hello, "R", "scratch.R"))
  writeLines("^R/scratch\\.R$", file.path(hello, ".Rbuildignore"))
  before <- list.files(src, recursive = TRUE, all.files = TRUE)

  # Listed before the package it imports.
  installed <- install_local_r_packages(rscript, c(hello, dep), lib, verbose = FALSE)

  expect_equal(installed, c("depPkg", "hello"))
  expect_true(file.exists(file.path(lib, "hello", "DESCRIPTION")))
  expect_true(file.exists(file.path(lib, "depPkg", "DESCRIPTION")))
  # Sources are built into tarballs elsewhere, so nothing is written next to them.
  expect_equal(list.files(src, recursive = TRUE, all.files = TRUE), before)
})

# Install a local package whose help page has a build-stage Sexpr, which makes
# R CMD build install it, so its local dependency must already be installed.
expect_build_time_dependency_install <- function(rscript) {
  src <- withr::local_tempdir()
  lib <- withr::local_tempdir()
  dep <- write_local_pkg(
    src, "depA", namespace = "export(a)", r_code = "a <- function() 1"
  )
  pkg <- write_local_pkg(
    src, "pkgB", fields = "Imports: depA",
    namespace = c("import(depA)", "export(b)"),
    r_code = "b <- function() a() + 1"
  )
  dir.create(file.path(pkg, "man"))
  writeLines(c(
    "\\name{b}", "\\alias{b}", "\\title{B}", "\\usage{b()}",
    "\\description{Two is \\Sexpr[stage=build]{1 + 1}.}"
  ), file.path(pkg, "man", "b.Rd"))

  installed <- install_local_r_packages(rscript, c(pkg, dep), lib, verbose = FALSE)

  expect_equal(installed, c("depA", "pkgB"))
  expect_true(file.exists(file.path(lib, "pkgB", "DESCRIPTION")))
}

test_that("a help page that needs a local dependency at build time builds", {
  skip_on_cran()
  expect_build_time_dependency_install(local_test_rscript())
})

test_that("a help page that needs a local dependency at build time builds with the portable R", {
  skip_on_cran()
  platform <- detect_current_platform()
  skip_if_not(platform %in% c("mac", "win"), "No portable R for this platform")
  rscript <- r_executable(SHINYELECTRON_DEFAULTS$runtime_versions$r, platform,
                          detect_current_arch())
  skip_if(is.null(rscript), "The portable R is not cached")
  expect_build_time_dependency_install(rscript)
})

test_that("the caller's R startup files cannot hide the bundled library", {
  skip_on_cran()
  rscript <- local_test_rscript()
  dir <- withr::local_tempdir()
  elsewhere <- normalizePath(withr::local_tempdir(), winslash = "/")
  path <- function(...) normalizePath(file.path(dir, ...), winslash = "/", mustWork = FALSE)
  # A user environ file that points every library variable elsewhere.
  writeLines(paste0(c("R_LIBS", "R_LIBS_USER", "R_LIBS_SITE"), "=", elsewhere),
             path("user.Renviron"))
  # Startup files like the ones callr hands to the R it starts, which on
  # Windows reach every descendant: the site environ file selects a site
  # profile that empties the site library and puts another library first.
  writeLines(c(
    ".Library.site <- character(0)",
    ".libPaths(.libPaths())",
    sprintf(".libPaths('%s')", elsewhere)
  ), path("site.Rprofile"))
  writeLines(paste0("R_PROFILE=", path("site.Rprofile")), path("site.Renviron"))
  # A user profile that switches to a project library, as renv does, for this
  # R and the ones it starts.
  writeLines(c(
    sprintf("Sys.setenv(R_LIBS = '%1$s', R_LIBS_USER = '%1$s', R_LIBS_SITE = '%1$s')", elsewhere),
    sprintf(".libPaths('%s')", elsewhere)
  ), path("user.Rprofile"))
  withr::local_envvar(
    R_ENVIRON = path("site.Renviron"),
    R_ENVIRON_USER = path("user.Renviron"),
    R_PROFILE = path("site.Rprofile"),
    R_PROFILE_USER = path("user.Rprofile")
  )

  expect_build_time_dependency_install(rscript)
})

test_that("install_local_r_packages aborts when a package fails to load", {
  skip_on_cran()
  rscript <- local_test_rscript()
  lib <- withr::local_tempdir()
  broken <- write_local_pkg(
    withr::local_tempdir(), "onloadpkg",
    r_code = ".onLoad <- function(libname, pkgname) stop('boom from onLoad')"
  )

  expect_error(
    install_local_r_packages(rscript, broken, lib, verbose = FALSE),
    "boom from onLoad", class = "shinyelectron_local_packages_install"
  )
  expect_false(dir.exists(file.path(lib, "onloadpkg")))
  expect_length(list.files(lib, pattern = "^00LOCK"), 0)
})

test_that("build_electron_app passes the configured local packages to embed_r_runtime", {
  skip_if_not_installed("mockery")
  tmp <- withr::local_tempdir()
  app_dir <- fs::path(tmp, "app")
  fs::dir_create(app_dir)
  writeLines("library(shiny)", fs::path(app_dir, "app.R"))

  mockery::stub(build_electron_app, "validate_node_npm", function(...) invisible(TRUE))
  mockery::stub(build_electron_app, "setup_electron_project", function(...) invisible(TRUE))
  mockery::stub(build_electron_app, "copy_app_files", function(...) invisible(TRUE))
  mockery::stub(build_electron_app, "process_templates", function(...) invisible(TRUE))
  mockery::stub(build_electron_app, "install_npm_dependencies", function(...) invisible(TRUE))
  mockery::stub(build_electron_app, "build_for_platforms", function(...) invisible(TRUE))
  mockery::stub(build_electron_app, "validate_build_output", function(...) invisible(TRUE))
  mockery::stub(build_electron_app, "resolve_runtime_version", function(runtime, config) "4.6.1")
  embed <- mockery::mock()
  mockery::stub(build_electron_app, "embed_r_runtime",
                function(output_dir, packages, repos, version, platform, arch,
                         verbose, prune, local_packages) {
    embed(local_packages = local_packages, prune = prune)
    invisible(fs::path(output_dir, "runtime", "R"))
  })

  local_packages <- c("/abs/pkgs/MyPkg", "/abs/vendor/other_1.0.tar.gz")
  build_electron_app(
    app_dir, fs::path(tmp, "out"), app_name = "test", app_type = "r-shiny",
    runtime_strategy = "bundled", platform = "mac", arch = "arm64",
    config = list(dependencies = list(r = list(local_packages = as.list(local_packages)))),
    verbose = FALSE
  )

  captured <- mockery::mock_args(embed)[[1]]
  expect_equal(captured$local_packages, local_packages)
  expect_true(captured$prune)   # dependencies.r.prune defaults to TRUE
})

test_that("build_multi_app passes the configured local packages to embed_r_runtime", {
  skip_if_not_installed("mockery")
  config <- list(
    build = list(type = "r-shiny", runtime_strategy = "bundled"),
    dependencies = list(r = list(local_packages = list("/abs/pkgs/MyPkg"))),
    apps = list(
      list(id = "one", name = "One", path = "./apps/one"),
      list(id = "two", name = "Two", path = "./apps/two")
    )
  )
  apps_manifest <- list(
    list(id = "one", name = "One", type = "r-shiny", runtime_strategy = "bundled"),
    list(id = "two", name = "Two", type = "r-shiny", runtime_strategy = "bundled")
  )

  embed <- mockery::mock()
  mockery::stub(build_multi_app, "embed_r_runtime",
                function(output_dir, packages, repos, version, platform, arch,
                         verbose, prune, local_packages) {
    embed(local_packages = local_packages, prune = prune)
    invisible(TRUE)
  })
  mockery::stub(build_multi_app, "validate_node_npm", function() invisible(TRUE))
  mockery::stub(build_multi_app, "setup_electron_project", function(...) invisible(TRUE))
  mockery::stub(build_multi_app, "process_templates", function(...) invisible(TRUE))
  mockery::stub(build_multi_app, "install_npm_dependencies", function(...) invisible(TRUE))
  mockery::stub(build_multi_app, "build_for_platforms", function(...) invisible(TRUE))
  mockery::stub(build_multi_app, "validate_build_output", function(...) invisible(TRUE))

  build_multi_app(
    apps_dir = withr::local_tempdir(),
    output_dir = file.path(withr::local_tempdir(), "electron-app"),
    app_name = "Suite", apps_manifest = apps_manifest, default_type = "r-shiny",
    runtime_strategy = "bundled", sign = FALSE, platform = "mac", arch = "arm64",
    icon = NULL, config = config, overwrite = TRUE, verbose = FALSE,
    r_packages = "shiny"
  )

  captured <- mockery::mock_args(embed)[[1]]
  expect_equal(captured$local_packages, "/abs/pkgs/MyPkg")
  expect_true(captured$prune)   # dependencies.r.prune defaults to TRUE
})

test_that("build_multi_app falls back to the configured repositories", {
  skip_if_not_installed("mockery")
  apps_manifest <- list(
    list(id = "one", name = "One", type = "r-shiny", runtime_strategy = "bundled"),
    list(id = "two", name = "Two", type = "r-shiny", runtime_strategy = "bundled")
  )
  suite_config <- function(repos = NULL) {
    list(
      build = list(type = "r-shiny", runtime_strategy = "bundled"),
      dependencies = list(r = list(repos = repos, local_packages = list("/abs/MyPkg"))),
      apps = list(
        list(id = "one", name = "One", path = "./apps/one"),
        list(id = "two", name = "Two", path = "./apps/two")
      )
    )
  }

  embed <- mockery::mock()
  mockery::stub(build_multi_app, "embed_r_runtime",
                function(output_dir, packages, repos, version, platform, arch,
                         verbose, prune, local_packages) {
    embed(repos = repos)
    invisible(TRUE)
  })
  mockery::stub(build_multi_app, "validate_node_npm", function() invisible(TRUE))
  mockery::stub(build_multi_app, "setup_electron_project", function(...) invisible(TRUE))
  mockery::stub(build_multi_app, "process_templates", function(...) invisible(TRUE))
  mockery::stub(build_multi_app, "install_npm_dependencies", function(...) invisible(TRUE))
  mockery::stub(build_multi_app, "build_for_platforms", function(...) invisible(TRUE))
  mockery::stub(build_multi_app, "validate_build_output", function(...) invisible(TRUE))
  build <- function(config) {
    build_multi_app(
      apps_dir = withr::local_tempdir(.local_envir = parent.frame()),
      output_dir = file.path(withr::local_tempdir(.local_envir = parent.frame()), "electron-app"),
      app_name = "Suite", apps_manifest = apps_manifest, default_type = "r-shiny",
      runtime_strategy = "bundled", sign = FALSE, platform = "mac", arch = "arm64",
      icon = NULL, config = config, overwrite = TRUE, verbose = FALSE
    )
  }

  # No app declared or detected packages, so there are no manifest repos.
  build(suite_config(repos = list("https://example.org/cran")))
  expect_equal(unlist(mockery::mock_args(embed)[[1]]$repos), "https://example.org/cran")

  build(suite_config())
  expect_equal(unlist(mockery::mock_args(embed)[[2]]$repos), "https://cloud.r-project.org")
})
