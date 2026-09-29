test_that("local_r_package_names resolves directories and archives", {
  dir <- file.path(tempfile("pkg-"), "MyPkg")
  dir.create(file.path(dir, "R"), recursive = TRUE)
  writeLines(c("Package: MyPkg", "Version: 0.1.0", "Title: t", "Description: t.",
               "License: MIT", "Encoding: UTF-8"), file.path(dir, "DESCRIPTION"))
  writeLines("", file.path(dir, "NAMESPACE"))

  expect_equal(local_r_package_names(dir), "MyPkg")
  expect_equal(
    local_r_package_names(c(dir, "SeuratExplorer_0.1.9.tar.gz")),
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