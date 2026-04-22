# tests/testthat/test-dependencies.R

# --- R dependency detection ---

test_that("detect_r_dependencies finds library/require calls via renv", {
  tmpdir <- tempfile()
  dir.create(tmpdir)
  on.exit(unlink(tmpdir, recursive = TRUE))

  writeLines(c(
    "library(shiny)",
    "library(ggplot2)",
    "require(DT)"
  ), file.path(tmpdir, "app.R"))

  deps <- detect_r_dependencies(tmpdir)
  expect_true("shiny" %in% deps)
  expect_true("ggplot2" %in% deps)
  expect_true("DT" %in% deps)
})

test_that("detect_r_dependencies finds namespace references", {
  tmpdir <- tempfile()
  dir.create(tmpdir)
  on.exit(unlink(tmpdir, recursive = TRUE))

  writeLines(c(
    "library(shiny)",
    "dplyr::filter(df, x > 1)",
    "ggplot2::ggplot(df)"
  ), file.path(tmpdir, "app.R"))

  deps <- detect_r_dependencies(tmpdir)
  expect_true("dplyr" %in% deps)
  expect_true("ggplot2" %in% deps)
})

test_that("detect_r_dependencies excludes base R packages", {
  tmpdir <- tempfile()
  dir.create(tmpdir)
  on.exit(unlink(tmpdir, recursive = TRUE))

  writeLines(c(
    "library(shiny)",
    "stats::lm(y ~ x)",
    "utils::head(df)"
  ), file.path(tmpdir, "app.R"))

  deps <- detect_r_dependencies(tmpdir)
  expect_true("shiny" %in% deps)
  expect_false("stats" %in% deps)
  expect_false("utils" %in% deps)
})

test_that("detect_r_dependencies scans multiple files", {
  tmpdir <- tempfile()
  dir.create(tmpdir)
  on.exit(unlink(tmpdir, recursive = TRUE))

  writeLines("library(shiny)", file.path(tmpdir, "ui.R"))
  writeLines("library(DT)", file.path(tmpdir, "server.R"))

  deps <- detect_r_dependencies(tmpdir)
  expect_true("shiny" %in% deps)
  expect_true("DT" %in% deps)
})

test_that("detect_r_dependencies returns sorted unique vector", {
  tmpdir <- tempfile()
  dir.create(tmpdir)
  on.exit(unlink(tmpdir, recursive = TRUE))

  writeLines(c(
    "library(shiny)",
    "library(shiny)",
    "library(ggplot2)"
  ), file.path(tmpdir, "app.R"))

  deps <- detect_r_dependencies(tmpdir)
  expect_equal(deps, sort(unique(deps)))
  expect_equal(sum(deps == "shiny"), 1)
})

test_that("detect_r_dependencies returns empty for no dependencies", {
  tmpdir <- tempfile()
  dir.create(tmpdir)
  on.exit(unlink(tmpdir, recursive = TRUE))

  writeLines("# no packages used", file.path(tmpdir, "app.R"))

  deps <- detect_r_dependencies(tmpdir)
  expect_length(deps, 0)
})

test_that("detect_r_dependencies errors gracefully when renv not installed", {
  mockery::stub(detect_r_dependencies, "requireNamespace", function(...) FALSE)
  expect_error(detect_r_dependencies(tempdir()), "renv")
})

# --- Python dependency detection ---

test_that("detect_py_dependencies reads requirements.txt", {
  tmpdir <- tempfile()
  dir.create(tmpdir)
  on.exit(unlink(tmpdir, recursive = TRUE))

  writeLines(c(
    "pandas>=2.0",
    "numpy==1.24.0",
    "# this is a comment",
    "",
    "scikit-learn",
    "shiny"
  ), file.path(tmpdir, "requirements.txt"))

  deps <- detect_py_dependencies(tmpdir)
  expect_true("pandas" %in% deps)
  expect_true("numpy" %in% deps)
  expect_true("scikit-learn" %in% deps)
  expect_true("shiny" %in% deps)
})

test_that("detect_py_dependencies strips version specifiers", {
  tmpdir <- tempfile()
  dir.create(tmpdir)
  on.exit(unlink(tmpdir, recursive = TRUE))

  writeLines(c(
    "pandas>=2.0,<3.0",
    "numpy~=1.24",
    "flask[async]>=2.0"
  ), file.path(tmpdir, "requirements.txt"))

  deps <- detect_py_dependencies(tmpdir)
  expect_true("pandas" %in% deps)
  expect_true("numpy" %in% deps)
  expect_true("flask" %in% deps)
})

test_that("detect_py_dependencies reads pyproject.toml dependencies", {
  tmpdir <- tempfile()
  dir.create(tmpdir)
  on.exit(unlink(tmpdir, recursive = TRUE))

  writeLines(c(
    '[project]',
    'name = "my-app"',
    'dependencies = [',
    '  "shiny>=0.6",',
    '  "pandas",',
    '  "numpy>=1.24",',
    ']'
  ), file.path(tmpdir, "pyproject.toml"))

  deps <- detect_py_dependencies(tmpdir)
  expect_true("shiny" %in% deps)
  expect_true("pandas" %in% deps)
  expect_true("numpy" %in% deps)
})

test_that("detect_py_dependencies prefers requirements.txt over pyproject.toml", {
  tmpdir <- tempfile()
  dir.create(tmpdir)
  on.exit(unlink(tmpdir, recursive = TRUE))

  writeLines("pandas", file.path(tmpdir, "requirements.txt"))
  writeLines(c(
    '[project]',
    'dependencies = ["numpy"]'
  ), file.path(tmpdir, "pyproject.toml"))

  deps <- detect_py_dependencies(tmpdir)
  expect_true("pandas" %in% deps)
  expect_false("numpy" %in% deps)
})

test_that("detect_py_dependencies warns when no dependency file found", {
  tmpdir <- tempfile()
  dir.create(tmpdir)
  on.exit(unlink(tmpdir, recursive = TRUE))

  writeLines("from shiny import App", file.path(tmpdir, "app.py"))

  expect_warning(
    deps <- detect_py_dependencies(tmpdir),
    "requirements.txt"
  )
  expect_length(deps, 0)
})

test_that("detect_py_dependencies skips comments and flags in requirements.txt", {
  tmpdir <- tempfile()
  dir.create(tmpdir)
  on.exit(unlink(tmpdir, recursive = TRUE))

  writeLines(c(
    "# Comment line",
    "-r other-requirements.txt",
    "--extra-index-url https://example.com",
    "pandas",
    ""
  ), file.path(tmpdir, "requirements.txt"))

  deps <- detect_py_dependencies(tmpdir)
  expect_true("pandas" %in% deps)
  expect_equal(length(deps), 1)
})

test_that("detect_py_dependencies returns sorted unique list", {
  tmpdir <- tempfile()
  dir.create(tmpdir)
  on.exit(unlink(tmpdir, recursive = TRUE))

  writeLines(c("pandas", "numpy", "pandas"), file.path(tmpdir, "requirements.txt"))

  deps <- detect_py_dependencies(tmpdir)
  expect_equal(deps, sort(unique(deps)))
})

# --- Dependency merging ---

test_that("merge_r_dependencies combines detected and declared packages", {
  detected <- c("shiny", "ggplot2")
  config_deps <- list(
    auto_detect = TRUE,
    r = list(
      packages = list("DT", "plotly"),
      repos = list("https://cloud.r-project.org")
    )
  )

  result <- merge_r_dependencies(detected, config_deps)
  expect_true(all(c("shiny", "ggplot2", "DT", "plotly") %in% result$packages))
  expect_equal(result$repos, list("https://cloud.r-project.org"))
})

test_that("merge_r_dependencies uses only declared when auto_detect is FALSE", {
  detected <- c("shiny", "ggplot2")
  config_deps <- list(
    auto_detect = FALSE,
    r = list(
      packages = list("DT"),
      repos = list("https://cloud.r-project.org")
    )
  )

  result <- merge_r_dependencies(detected, config_deps)
  expect_equal(result$packages, "DT")
  expect_false("shiny" %in% result$packages)
})

test_that("merge_r_dependencies includes extra_packages", {
  detected <- c("shiny")
  config_deps <- list(
    auto_detect = TRUE,
    extra_packages = list("custom.pkg"),
    r = list(
      packages = list(),
      repos = list("https://cloud.r-project.org")
    )
  )

  result <- merge_r_dependencies(detected, config_deps)
  expect_true("custom.pkg" %in% result$packages)
  expect_true("shiny" %in% result$packages)
})

test_that("merge_py_dependencies combines detected and declared", {
  detected <- c("pandas", "numpy")
  config_deps <- list(
    auto_detect = TRUE,
    python = list(
      packages = list("scikit-learn"),
      index_urls = list("https://pypi.org/simple")
    )
  )

  result <- merge_py_dependencies(detected, config_deps)
  expect_true(all(c("pandas", "numpy", "scikit-learn") %in% result$packages))
})

# --- Manifest generation ---

test_that("generate_dependency_manifest creates valid JSON for R", {
  manifest <- generate_dependency_manifest(
    packages = c("shiny", "ggplot2"),
    language = "r",
    repos = list("https://cloud.r-project.org")
  )

  parsed <- jsonlite::fromJSON(manifest, simplifyVector = FALSE)
  expect_equal(parsed$language, "r")
  expect_equal(length(parsed$packages), 2)
  expect_true("shiny" %in% parsed$packages)
  expect_equal(parsed$repos[[1]], "https://cloud.r-project.org")
  expect_true(parsed$binary_only)
})

test_that("generate_dependency_manifest creates valid JSON for Python", {
  manifest <- generate_dependency_manifest(
    packages = c("pandas", "numpy"),
    language = "python",
    index_urls = list("https://pypi.org/simple")
  )

  parsed <- jsonlite::fromJSON(manifest, simplifyVector = FALSE)
  expect_equal(parsed$language, "python")
  expect_equal(length(parsed$packages), 2)
  expect_equal(parsed$index_urls[[1]], "https://pypi.org/simple")
})

test_that("generate_dependency_manifest handles empty packages", {
  manifest <- generate_dependency_manifest(
    packages = character(0),
    language = "r"
  )

  parsed <- jsonlite::fromJSON(manifest, simplifyVector = FALSE)
  expect_equal(length(parsed$packages), 0)
})

# --- R binary package installation ---

test_that("install_r_binary_packages calls install.packages with correct args", {
  captured_args <- NULL
  mockery::stub(install_r_binary_packages, "utils::install.packages",
                function(pkgs, lib, repos, type, ...) {
    captured_args <<- list(pkgs = pkgs, lib = lib, repos = repos, type = type)
  })

  install_r_binary_packages(
    packages = c("shiny", "ggplot2"),
    lib_path = "/tmp/test-lib",
    repos = c("https://cloud.r-project.org"),
    verbose = FALSE
  )

  # The function resolves the full dependency tree, so the actual list
  # will include transitive dependencies (R6, htmltools, etc.)
  expect_true(all(c("shiny", "ggplot2") %in% captured_args$pkgs))
  expect_equal(captured_args$lib, "/tmp/test-lib")
  expect_equal(captured_args$type, "binary")
})

test_that("install_r_binary_packages creates lib directory", {
  lib_path <- tempfile("test-lib")
  on.exit(unlink(lib_path, recursive = TRUE))

  mockery::stub(install_r_binary_packages, "utils::install.packages",
                function(...) NULL)

  install_r_binary_packages(
    packages = "shiny",
    lib_path = lib_path,
    repos = c("https://cloud.r-project.org"),
    verbose = FALSE
  )

  expect_true(fs::dir_exists(lib_path))
})

test_that("install_r_binary_packages skips empty package list", {
  install_called <- FALSE
  mockery::stub(install_r_binary_packages, "utils::install.packages",
                function(...) { install_called <<- TRUE })

  install_r_binary_packages(
    packages = character(0),
    lib_path = "/tmp/test-lib",
    verbose = FALSE
  )

  expect_false(install_called)
})

# --- Orchestration ---

test_that("resolve_app_dependencies detects and merges for r-shiny", {
  tmpdir <- tempfile()
  dir.create(tmpdir)
  writeLines(c("library(shiny)", "library(ggplot2)"), file.path(tmpdir, "app.R"))
  on.exit(unlink(tmpdir, recursive = TRUE))

  config <- list(dependencies = list(
    auto_detect = TRUE,
    r = list(
      packages = list("DT"),
      repos = list("https://cloud.r-project.org")
    )
  ))

  result <- resolve_app_dependencies(
    appdir = tmpdir,
    app_type = "r-shiny",
    config = config
  )

  expect_true("shiny" %in% result$packages)
  expect_true("ggplot2" %in% result$packages)
  expect_true("DT" %in% result$packages)
  expect_equal(result$language, "r")
})

test_that("resolve_app_dependencies reads requirements.txt for py-shiny", {
  tmpdir <- tempfile()
  dir.create(tmpdir)
  writeLines("from shiny import App", file.path(tmpdir, "app.py"))
  writeLines(c("pandas", "shiny"), file.path(tmpdir, "requirements.txt"))
  on.exit(unlink(tmpdir, recursive = TRUE))

  config <- list(dependencies = list(
    auto_detect = TRUE,
    python = list(
      packages = list(),
      index_urls = list("https://pypi.org/simple")
    )
  ))

  result <- resolve_app_dependencies(
    appdir = tmpdir,
    app_type = "py-shiny",
    config = config
  )

  expect_true("pandas" %in% result$packages)
  expect_true("shiny" %in% result$packages)
  expect_equal(result$language, "python")
})

test_that("resolve_app_dependencies returns NULL for shinylive types", {
  result <- resolve_app_dependencies(
    appdir = tempdir(),
    app_type = "r-shinylive",
    config = list()
  )
  expect_null(result)
})

# --- Python binary package installation ---

test_that("install_py_binary_packages calls pip with correct args", {
  captured_args <- NULL
  mockery::stub(install_py_binary_packages, "processx::run",
                function(command, args, ...) {
    captured_args <<- list(command = command, args = args)
    list(status = 0, stdout = "", stderr = "")
  })
  mockery::stub(install_py_binary_packages, "find_python_command",
                function() "python3")

  install_py_binary_packages(
    packages = c("pandas", "numpy"),
    index_url = "https://pypi.org/simple",
    verbose = FALSE
  )

  expect_true("--only-binary" %in% captured_args$args)
  expect_true(":all:" %in% captured_args$args)
  expect_true("pandas" %in% captured_args$args)
  expect_true("numpy" %in% captured_args$args)
})

test_that("install_py_binary_packages skips empty package list", {
  run_called <- FALSE
  mockery::stub(install_py_binary_packages, "processx::run",
                function(...) { run_called <<- TRUE; list(status = 0) })

  install_py_binary_packages(packages = character(0), verbose = FALSE)
  expect_false(run_called)
})
