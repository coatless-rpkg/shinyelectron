test_that("detect_container_engine finds docker", {
  mockery::stub(detect_container_engine, "Sys.which", function(cmd) {
    if (cmd == "docker") "/usr/bin/docker" else ""
  })
  expect_equal(detect_container_engine(), "docker")
})

test_that("detect_container_engine finds podman when docker absent", {
  mockery::stub(detect_container_engine, "Sys.which", function(cmd) {
    if (cmd == "podman") "/usr/bin/podman" else ""
  })
  expect_equal(detect_container_engine(), "podman")
})

test_that("detect_container_engine respects config preference", {
  mockery::stub(detect_container_engine, "Sys.which", function(cmd) {
    if (cmd == "podman") "/usr/bin/podman"
    else if (cmd == "docker") "/usr/bin/docker"
    else ""
  })
  expect_equal(detect_container_engine("podman"), "podman")
})

test_that("detect_container_engine returns NULL when none found", {
  mockery::stub(detect_container_engine, "Sys.which", function(cmd) "")
  expect_null(detect_container_engine())
})

test_that("select_container_image returns correct image for r-shiny", {
  result <- select_container_image("r-shiny")
  expect_equal(result, "shinyelectron/r-shiny:latest")
})

test_that("select_container_image returns correct image for py-shiny", {
  result <- select_container_image("py-shiny")
  expect_equal(result, "shinyelectron/py-shiny:latest")
})

test_that("select_container_image uses custom image from config", {
  result <- select_container_image("r-shiny", image = "myregistry/myimage", tag = "v2")
  expect_equal(result, "myregistry/myimage:v2")
})

test_that("generate_container_config creates valid JSON", {
  result <- generate_container_config(
    app_type = "r-shiny",
    engine = "docker",
    config = list(container = list(
      image = NULL,
      tag = "latest",
      pull_on_start = TRUE
    ))
  )
  parsed <- jsonlite::fromJSON(result, simplifyVector = FALSE)
  expect_equal(parsed$container_engine, "docker")
  expect_true(parsed$pull_on_start)
  expect_equal(parsed$app_type, "r-shiny")
})

test_that("validate_container_available errors when no engine found", {
  mockery::stub(validate_container_available, "detect_container_engine", function(...) NULL)
  expect_error(validate_container_available(), "Docker.*Podman")
})
