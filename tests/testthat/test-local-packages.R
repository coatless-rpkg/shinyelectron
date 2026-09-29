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

  captured <- NULL
  local_mocked_bindings(
    prepare_native_app_files = function(appdir, destdir, app_type, runtime_strategy,
                                        platform, arch, config, verbose = TRUE) {
      captured <<- config$dependencies$r$local_packages
      list(converted_app = destdir, dependencies = NULL)
    }
  )
  withr::local_dir(withr::local_tempdir())

  export(appdir, file.path(root, "out"), build = FALSE, verbose = FALSE)

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

  captured <- NULL
  local_mocked_bindings(
    resolve_app_dependencies = function(appdir, app_type, runtime_strategy, config) {
      list(language = "r", packages = "shiny", repos = list())
    },
    generate_dependency_manifest = function(...) "{}",
    build_multi_app = function(...) {
      captured <<- list(...)$config$dependencies$r$local_packages
      "electron-app"
    }
  )
  withr::local_dir(withr::local_tempdir())

  export(suite, file.path(withr::local_tempdir(), "out"),
         platform = "mac", arch = "arm64", verbose = FALSE)

  expect_equal(normalizePath(captured), normalizePath(file.path(suite, "pkgs", "MyPkg")))
})

test_that("embed_r_runtime checks local packages before downloading R", {
  skip_if_not_installed("mockery")
  out <- withr::local_tempdir()
  downloaded <- FALSE
  mockery::stub(embed_r_runtime, "install_r_portable", function(...) {
    downloaded <<- TRUE
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
  expect_false(downloaded)
})

test_that("install_local_r_packages installs a package whose import is in the target lib", {
  skip_on_cran()
  rscript <- file.path(R.home("bin"),
                       if (.Platform$OS.type == "windows") "Rscript.exe" else "Rscript")
  skip_if_not(file.exists(rscript), "Rscript not available")

  work <- tempfile("lpkg-")
  dir.create(work)
  lib <- file.path(work, "lib")
  dir.create(lib)

  dep <- file.path(work, "depPkg")
  dir.create(file.path(dep, "R"), recursive = TRUE)
  writeLines(c("Package: depPkg", "Version: 0.0.1", "Title: t", "Description: t.",
               "License: MIT", "Encoding: UTF-8"), file.path(dep, "DESCRIPTION"))
  writeLines("export(depfun)", file.path(dep, "NAMESPACE"))
  writeLines("depfun <- function() 1", file.path(dep, "R", "d.R"))
  install_local_r_packages(rscript, dep, lib, verbose = FALSE)

  pkg <- file.path(work, "hello")
  dir.create(file.path(pkg, "R"), recursive = TRUE)
  writeLines(c("Package: hello", "Version: 0.0.1", "Title: t", "Description: t.",
               "License: MIT", "Encoding: UTF-8", "Imports: depPkg"),
             file.path(pkg, "DESCRIPTION"))
  writeLines(c("export(greet)", "import(depPkg)"), file.path(pkg, "NAMESPACE"))
  writeLines("greet <- function() depfun()", file.path(pkg, "R", "g.R"))

  install_local_r_packages(rscript, pkg, lib, verbose = FALSE)

  expect_true(file.exists(file.path(lib, "hello", "DESCRIPTION")))
  expect_true(file.exists(file.path(lib, "hello", "NAMESPACE")))
})
