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

test_that("generate_container_config returns container backend settings", {
  result <- generate_container_config(
    config = list(container = list(
      engine = "podman",
      image = "myregistry/myimage",
      tag = "v2",
      pull_on_start = FALSE,
      volumes = list("/host" = "/data"),
      env = list(KEY = "value")
    ))
  )
  expect_type(result, "list")
  expect_equal(result$container_engine, "podman")
  expect_equal(result$container_image, "myregistry/myimage")
  expect_equal(result$container_tag, "v2")
  expect_false(result$pull_on_start)
  expect_equal(result$container_volumes, list("/host" = "/data"))
})

test_that("generate_container_config falls back to defaults", {
  result <- generate_container_config(config = list())
  expect_equal(result$container_engine, "docker")
  expect_null(result$container_image)
  expect_equal(result$container_tag, "latest")
  expect_true(result$pull_on_start)
})

test_that("validate_container_available errors when no engine found", {
  mockery::stub(validate_container_available, "detect_container_engine", function(...) NULL)
  expect_error(validate_container_available(), "Docker.*Podman")
})

test_that("validate_config warns on invalid container.engine and resets to NULL", {
  cfg <- list(container = list(engine = "nope"))
  result <- expect_warning(
    validate_config(cfg),
    "engine"
  )
  expect_null(result$container$engine)
})

test_that("validate_config passes valid container engines unchanged", {
  for (eng in c("docker", "podman")) {
    cfg <- list(container = list(engine = eng))
    result <- cfg
    expect_no_warning(result <- validate_config(cfg))
    expect_equal(result$container$engine, eng)
  }
})

test_that("validate_config is unaffected when container section is absent", {
  cfg <- list(build = list(type = "r-shiny"))
  expect_no_warning(result <- validate_config(cfg))
  expect_null(result$container)
})
