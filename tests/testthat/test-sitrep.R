# tests/testthat/test-sitrep.R
#
# Tests for the sitrep_* family of exported functions.
# All tests use verbose = FALSE to suppress console output.
# External system probes (node, npm, python, container engine, filesystem
# cache) are stubbed so results are deterministic across machines.

# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

# Returns a minimal fake run_command_safe result (success by default).
fake_run_ok <- function(stdout = "") {
  list(status = 0L, stdout = stdout, stderr = "")
}

fake_run_fail <- function() {
  list(status = 1L, stdout = "", stderr = "not found")
}

# ---------------------------------------------------------------------------
# sitrep_electron_dependencies
# ---------------------------------------------------------------------------

test_that("sitrep_electron_dependencies returns new_sitrep_results structure", {
  result <- sitrep_electron_dependencies(verbose = FALSE)
  expect_type(result, "list")
  expect_true("issues" %in% names(result))
  expect_true("recommendations" %in% names(result))
  expect_type(result$issues, "character")
  expect_type(result$recommendations, "character")
})

test_that("sitrep_electron_dependencies has required/optional/missing fields", {
  result <- sitrep_electron_dependencies(verbose = FALSE)
  expect_true(all(c("required", "optional",
                     "missing_required", "missing_optional") %in% names(result)))
  expect_type(result$missing_required, "character")
  expect_type(result$missing_optional, "character")
})

test_that("sitrep_electron_dependencies finds all hard-import packages installed", {
  result <- sitrep_electron_dependencies(verbose = FALSE)
  # All required packages in DESCRIPTION Imports must be present in the test env
  expect_equal(length(result$missing_required), 0L)
})

test_that("sitrep_electron_dependencies required list contains cli entry", {
  result <- sitrep_electron_dependencies(verbose = FALSE)
  expect_true("cli" %in% names(result$required))
  expect_true(isTRUE(result$required$cli$installed))
})

# ---------------------------------------------------------------------------
# sitrep_electron_project
# ---------------------------------------------------------------------------

test_that("sitrep_electron_project returns new_sitrep_results structure", {
  tmp <- withr::local_tempdir()
  result <- sitrep_electron_project(project_dir = tmp, verbose = FALSE)
  expect_type(result, "list")
  expect_true("issues" %in% names(result))
  expect_true("recommendations" %in% names(result))
})

test_that("sitrep_electron_project has expected extra fields", {
  tmp <- withr::local_tempdir()
  result <- sitrep_electron_project(project_dir = tmp, verbose = FALSE)
  expect_true(all(c("project_dir", "is_electron_project",
                     "package_json", "main_js", "app_files",
                     "node_modules", "build_scripts") %in% names(result)))
})

test_that("sitrep_electron_project records issue for non-existent directory", {
  result <- sitrep_electron_project(
    project_dir = "/this/path/does/not/exist",
    verbose = FALSE
  )
  expect_true(any(grepl("does not exist", result$issues, ignore.case = TRUE)))
})

test_that("sitrep_electron_project returns is_electron_project FALSE for empty dir", {
  tmp <- withr::local_tempdir()
  result <- sitrep_electron_project(project_dir = tmp, verbose = FALSE)
  expect_false(result$is_electron_project)
})

test_that("sitrep_electron_project detects package.json when present", {
  tmp <- withr::local_tempdir()
  writeLines('{"name":"myapp","scripts":{}}', file.path(tmp, "package.json"))
  result <- sitrep_electron_project(project_dir = tmp, verbose = FALSE)
  expect_true(result$package_json$exists)
})

test_that("sitrep_electron_project detects main.js when present", {
  tmp <- withr::local_tempdir()
  writeLines('{"name":"myapp","scripts":{}}', file.path(tmp, "package.json"))
  writeLines("// main", file.path(tmp, "main.js"))
  result <- sitrep_electron_project(project_dir = tmp, verbose = FALSE)
  expect_true(result$main_js$exists)
})

test_that("sitrep_electron_project marks is_electron_project TRUE when both files present", {
  tmp <- withr::local_tempdir()
  writeLines('{"name":"myapp","scripts":{}}', file.path(tmp, "package.json"))
  writeLines("// main", file.path(tmp, "main.js"))
  result <- sitrep_electron_project(project_dir = tmp, verbose = FALSE)
  expect_true(result$is_electron_project)
})

# ---------------------------------------------------------------------------
# sitrep_electron_build_tools
# ---------------------------------------------------------------------------

test_that("sitrep_electron_build_tools returns new_sitrep_results structure (mac)", {
  mockery::stub(sitrep_electron_build_tools, "detect_current_platform", function() "mac")
  mockery::stub(sitrep_electron_build_tools, "run_command_safe",
                function(...) fake_run_ok("/Library/Developer/CommandLineTools"))

  result <- sitrep_electron_build_tools(verbose = FALSE)
  expect_type(result, "list")
  expect_true("issues" %in% names(result))
  expect_true("recommendations" %in% names(result))
  expect_type(result$issues, "character")
  expect_type(result$recommendations, "character")
})

test_that("sitrep_electron_build_tools has platform and tools fields", {
  mockery::stub(sitrep_electron_build_tools, "detect_current_platform", function() "mac")
  mockery::stub(sitrep_electron_build_tools, "run_command_safe",
                function(...) fake_run_ok("/Library/Developer/CommandLineTools"))

  result <- sitrep_electron_build_tools(verbose = FALSE)
  expect_true(all(c("platform", "tools") %in% names(result)))
})

test_that("sitrep_electron_build_tools records no issues when xcode found on mac", {
  mockery::stub(sitrep_electron_build_tools, "detect_current_platform", function() "mac")
  mockery::stub(sitrep_electron_build_tools, "run_command_safe",
                function(...) fake_run_ok("/Library/Developer/CommandLineTools"))

  result <- sitrep_electron_build_tools(verbose = FALSE)
  expect_length(result$issues, 0L)
  expect_true(isTRUE(result$tools$xcode))
})

test_that("sitrep_electron_build_tools records issue when xcode missing on mac", {
  mockery::stub(sitrep_electron_build_tools, "detect_current_platform", function() "mac")
  mockery::stub(sitrep_electron_build_tools, "run_command_safe",
                function(...) fake_run_fail())

  result <- sitrep_electron_build_tools(verbose = FALSE)
  expect_gt(length(result$issues), 0L)
  expect_false(isTRUE(result$tools$xcode))
})

test_that("sitrep_electron_build_tools returns correct structure on linux", {
  call_n <- 0L
  mockery::stub(sitrep_electron_build_tools, "detect_current_platform", function() "linux")
  mockery::stub(sitrep_electron_build_tools, "run_command_safe", function(...) {
    call_n <<- call_n + 1L
    fake_run_ok("gcc (Ubuntu 11) 11.4.0")
  })

  result <- sitrep_electron_build_tools(verbose = FALSE)
  expect_true(all(c("issues", "recommendations", "platform", "tools") %in% names(result)))
  expect_equal(result$platform, "linux")
})

# ---------------------------------------------------------------------------
# sitrep_electron_system
# ---------------------------------------------------------------------------

test_that("sitrep_electron_system returns new_sitrep_results structure", {
  mockery::stub(sitrep_electron_system, "detect_current_platform", function() "mac")
  mockery::stub(sitrep_electron_system, "detect_current_arch", function() "arm64")
  mockery::stub(sitrep_electron_system, "nodejs_list_installed", function() character(0))
  mockery::stub(sitrep_electron_system, "get_node_command", function(...) "node")
  mockery::stub(sitrep_electron_system, "get_npm_command", function(...) "npm")

  call_n <- 0L
  mockery::stub(sitrep_electron_system, "run_command_safe", function(...) {
    call_n <<- call_n + 1L
    if (call_n == 1L) fake_run_ok("v22.10.0") else fake_run_ok("11.5.0")
  })

  mockery::stub(sitrep_electron_system, "find_python_command", function() NULL)
  mockery::stub(sitrep_electron_system, "detect_container_engine", function(...) NULL)
  mockery::stub(sitrep_electron_system, "cache_dir", function(...) "/nonexistent/cache/path")

  result <- sitrep_electron_system(verbose = FALSE)

  expect_type(result, "list")
  expect_true("issues" %in% names(result))
  expect_true("recommendations" %in% names(result))
  expect_type(result$issues, "character")
  expect_type(result$recommendations, "character")
})

test_that("sitrep_electron_system has expected extra fields", {
  mockery::stub(sitrep_electron_system, "detect_current_platform", function() "mac")
  mockery::stub(sitrep_electron_system, "detect_current_arch", function() "arm64")
  mockery::stub(sitrep_electron_system, "nodejs_list_installed", function() character(0))
  mockery::stub(sitrep_electron_system, "get_node_command", function(...) "node")
  mockery::stub(sitrep_electron_system, "get_npm_command", function(...) "npm")

  call_n <- 0L
  mockery::stub(sitrep_electron_system, "run_command_safe", function(...) {
    call_n <<- call_n + 1L
    if (call_n == 1L) fake_run_ok("v22.10.0") else fake_run_ok("11.5.0")
  })

  mockery::stub(sitrep_electron_system, "find_python_command", function() NULL)
  mockery::stub(sitrep_electron_system, "detect_container_engine", function(...) NULL)
  mockery::stub(sitrep_electron_system, "cache_dir", function(...) "/nonexistent/cache/path")

  result <- sitrep_electron_system(verbose = FALSE)

  expect_true(all(c("platform", "arch", "node", "npm",
                     "nodejs_local", "r_version") %in% names(result)))
})

test_that("sitrep_electron_system records node as installed on success", {
  mockery::stub(sitrep_electron_system, "detect_current_platform", function() "mac")
  mockery::stub(sitrep_electron_system, "detect_current_arch", function() "arm64")
  mockery::stub(sitrep_electron_system, "nodejs_list_installed", function() character(0))
  mockery::stub(sitrep_electron_system, "get_node_command", function(...) "node")
  mockery::stub(sitrep_electron_system, "get_npm_command", function(...) "npm")

  call_n <- 0L
  mockery::stub(sitrep_electron_system, "run_command_safe", function(...) {
    call_n <<- call_n + 1L
    if (call_n == 1L) fake_run_ok("v22.10.0") else fake_run_ok("11.5.0")
  })

  mockery::stub(sitrep_electron_system, "find_python_command", function() NULL)
  mockery::stub(sitrep_electron_system, "detect_container_engine", function(...) NULL)
  mockery::stub(sitrep_electron_system, "cache_dir", function(...) "/nonexistent/cache/path")

  result <- sitrep_electron_system(verbose = FALSE)

  expect_true(result$node$installed)
  expect_equal(result$node$version, "22.10.0")
  expect_true(result$npm$installed)
  expect_equal(result$npm$version, "11.5.0")
  expect_length(result$issues, 0L)
})

test_that("sitrep_electron_system records issue when node missing", {
  mockery::stub(sitrep_electron_system, "detect_current_platform", function() "mac")
  mockery::stub(sitrep_electron_system, "detect_current_arch", function() "arm64")
  mockery::stub(sitrep_electron_system, "nodejs_list_installed", function() character(0))
  mockery::stub(sitrep_electron_system, "get_node_command", function(...) "node")
  mockery::stub(sitrep_electron_system, "get_npm_command", function(...) "npm")
  mockery::stub(sitrep_electron_system, "run_command_safe", function(...) fake_run_fail())
  mockery::stub(sitrep_electron_system, "find_python_command", function() NULL)
  mockery::stub(sitrep_electron_system, "detect_container_engine", function(...) NULL)
  mockery::stub(sitrep_electron_system, "cache_dir", function(...) "/nonexistent/cache/path")

  result <- sitrep_electron_system(verbose = FALSE)

  expect_false(result$node$installed)
  expect_true(any(grepl("Node.js not found", result$issues)))
})

test_that("sitrep_electron_system records issue when node version too old", {
  mockery::stub(sitrep_electron_system, "detect_current_platform", function() "mac")
  mockery::stub(sitrep_electron_system, "detect_current_arch", function() "arm64")
  mockery::stub(sitrep_electron_system, "nodejs_list_installed", function() character(0))
  mockery::stub(sitrep_electron_system, "get_node_command", function(...) "node")
  mockery::stub(sitrep_electron_system, "get_npm_command", function(...) "npm")

  call_n <- 0L
  mockery::stub(sitrep_electron_system, "run_command_safe", function(...) {
    call_n <<- call_n + 1L
    if (call_n == 1L) fake_run_ok("v18.0.0") else fake_run_ok("11.5.0")
  })

  mockery::stub(sitrep_electron_system, "find_python_command", function() NULL)
  mockery::stub(sitrep_electron_system, "detect_container_engine", function(...) NULL)
  mockery::stub(sitrep_electron_system, "cache_dir", function(...) "/nonexistent/cache/path")

  result <- sitrep_electron_system(verbose = FALSE)

  expect_true(any(grepl("too old", result$issues)))
  expect_gt(length(result$recommendations), 0L)
})

test_that("sitrep_electron_system sets r_version from running R", {
  mockery::stub(sitrep_electron_system, "detect_current_platform", function() "mac")
  mockery::stub(sitrep_electron_system, "detect_current_arch", function() "arm64")
  mockery::stub(sitrep_electron_system, "nodejs_list_installed", function() character(0))
  mockery::stub(sitrep_electron_system, "get_node_command", function(...) "node")
  mockery::stub(sitrep_electron_system, "get_npm_command", function(...) "npm")

  call_n <- 0L
  mockery::stub(sitrep_electron_system, "run_command_safe", function(...) {
    call_n <<- call_n + 1L
    if (call_n == 1L) fake_run_ok("v22.10.0") else fake_run_ok("11.5.0")
  })

  mockery::stub(sitrep_electron_system, "find_python_command", function() NULL)
  mockery::stub(sitrep_electron_system, "detect_container_engine", function(...) NULL)
  mockery::stub(sitrep_electron_system, "cache_dir", function(...) "/nonexistent/cache/path")

  result <- sitrep_electron_system(verbose = FALSE)

  expect_true(nzchar(result$r_version))
  # Running R 4.6.0 which is >= 4.4.0; should not add an R-version issue
  expect_false(any(grepl("R version too old", result$issues)))
})

# ---------------------------------------------------------------------------
# sitrep_shinyelectron (aggregator)
# ---------------------------------------------------------------------------

test_that("sitrep_shinyelectron returns list with system/dependencies/build_tools/project keys", {
  minimal <- list(issues = character(0), recommendations = character(0))
  mockery::stub(sitrep_shinyelectron, "sitrep_electron_system",
                function(...) minimal)
  mockery::stub(sitrep_shinyelectron, "sitrep_electron_dependencies",
                function(...) minimal)
  mockery::stub(sitrep_shinyelectron, "sitrep_electron_build_tools",
                function(...) minimal)
  mockery::stub(sitrep_shinyelectron, "sitrep_electron_project",
                function(...) minimal)

  result <- sitrep_shinyelectron(verbose = FALSE)

  expect_type(result, "list")
  expect_true(all(c("system", "dependencies", "build_tools", "project") %in% names(result)))
})

test_that("sitrep_shinyelectron returns invisibly", {
  minimal <- list(issues = character(0), recommendations = character(0))
  mockery::stub(sitrep_shinyelectron, "sitrep_electron_system",
                function(...) minimal)
  mockery::stub(sitrep_shinyelectron, "sitrep_electron_dependencies",
                function(...) minimal)
  mockery::stub(sitrep_shinyelectron, "sitrep_electron_build_tools",
                function(...) minimal)
  mockery::stub(sitrep_shinyelectron, "sitrep_electron_project",
                function(...) minimal)

  # withVisible detects invisible
  vis <- withVisible(sitrep_shinyelectron(verbose = FALSE))
  expect_false(vis$visible)
})

test_that("sitrep_shinyelectron passes project_dir to sitrep_electron_project", {
  minimal <- list(issues = character(0), recommendations = character(0))
  captured_dir <- NULL

  mockery::stub(sitrep_shinyelectron, "sitrep_electron_system",
                function(...) minimal)
  mockery::stub(sitrep_shinyelectron, "sitrep_electron_dependencies",
                function(...) minimal)
  mockery::stub(sitrep_shinyelectron, "sitrep_electron_build_tools",
                function(...) minimal)
  mockery::stub(sitrep_shinyelectron, "sitrep_electron_project",
                function(project_dir, ...) {
                  captured_dir <<- project_dir
                  minimal
                })

  sitrep_shinyelectron(project_dir = "/my/test/dir", verbose = FALSE)
  expect_equal(captured_dir, "/my/test/dir")
})
