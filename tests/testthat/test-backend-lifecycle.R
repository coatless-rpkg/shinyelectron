# The start()/stop() lifecycle of the native R and Python backends and the
# container backend, driven under plain Node (no Electron) with fake Rscript,
# python3 and docker executables. See js/backend-lifecycle.js for the
# scenarios and js/fake-runtime.js for the fakes.

test_that("backends start, stop, time out and hand over cleanly", {
  skip_on_cran()
  # The fake executables are shell scripts.
  skip_on_os("windows")
  node <- Sys.which("node")
  skip_if_not(nzchar(node), "Node.js not available")

  backends <- system.file("electron", "backends", package = "shinyelectron")
  results_file <- withr::local_tempfile(fileext = ".json")
  result <- processx::run(
    node,
    c(test_path("js", "backend-lifecycle.js"), backends, results_file),
    env = c(
      "current",
      HOME = withr::local_tempdir(),
      TMPDIR = withr::local_tempdir(),
      SHINYELECTRON_DEBUG = ""
    ),
    error_on_status = FALSE,
    timeout = 180
  )
  expect_equal(result$status, 0, info = result$stderr)
  expect_true(file.exists(results_file))

  if (file.exists(results_file)) {
    scenarios <- jsonlite::read_json(results_file)
    expect_gt(length(scenarios), 0)
    for (scenario in scenarios) {
      expect(isTRUE(scenario$ok), paste0(scenario$name, ": ", scenario$message))
    }
  }
})
