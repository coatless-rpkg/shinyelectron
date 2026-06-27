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
  # Without app_type the tag defaults to "latest" (no runtime to resolve)
  result_no_type <- generate_container_config(config = list())
  expect_equal(result_no_type$container_engine, "docker")
  expect_null(result_no_type$container_image)
  expect_true(result_no_type$pull_on_start)
  expect_equal(result_no_type$container_tag, "latest")

  # With app_type the default (NULL) tag resolves to the pinned runtime version
  result_with_type <- generate_container_config(config = list(), app_type = "r-shiny")
  expect_equal(result_with_type$container_tag, SHINYELECTRON_DEFAULTS$runtime_versions$r)
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

test_that("copy_and_bake_dockerfiles bakes R_VERSION into r-shiny Dockerfile", {
  out <- withr::local_tempdir()
  copy_and_bake_dockerfiles(out, "r-shiny",
    config = list(dependencies = list(r = list(version = "4.5.1"))),
    verbose = FALSE)
  df_content <- readLines(fs::path(out, "dockerfiles", "Dockerfile"))
  expect_true(any(grepl("^ARG R_VERSION=4\\.5\\.1$", df_content)))
})

test_that("copy_and_bake_dockerfiles bakes PY_VERSION (major.minor) into py-shiny Dockerfile", {
  out <- withr::local_tempdir()
  copy_and_bake_dockerfiles(out, "py-shiny",
    config = list(dependencies = list(python = list(version = "3.13.2"))),
    verbose = FALSE)
  df_content <- readLines(fs::path(out, "dockerfiles", "Dockerfile"))
  expect_true(any(grepl("^ARG PY_VERSION=3\\.13$", df_content)))
})

test_that("generate_container_config uses runtime version as container_tag when no BYO image", {
  result <- generate_container_config(
    config = list(
      container = list(),
      dependencies = list(r = list(version = "4.5.1"))
    ),
    app_type = "r-shiny"
  )
  expect_equal(result$container_tag, "4.5.1")
})

test_that("generate_container_config does not override tag when BYO image is set", {
  result <- generate_container_config(
    config = list(
      container = list(image = "myregistry/myimage"),
      dependencies = list(r = list(version = "4.5.1"))
    ),
    app_type = "r-shiny"
  )
  expect_equal(result$container_tag, "latest")
})

# Regression tests: verify that a merged default config (where container$tag is
# NULL) routes through the runtime version resolver, not back to "latest".
test_that("container image tag encodes the resolved runtime version for a merged config", {
  cfg <- default_config()
  cfg$dependencies$r$version <- "4.5.1"
  cc <- generate_container_config(cfg, "r-shiny")
  expect_equal(cc$container_tag, "4.5.1")
})

test_that("a default merged config tags with the R pin, not 'latest'", {
  cfg <- default_config()
  cc <- generate_container_config(cfg, "r-shiny")
  expect_equal(cc$container_tag, SHINYELECTRON_DEFAULTS$runtime_versions$r)
})

test_that("BYO container.image keeps the latest/explicit tag, not the runtime version", {
  cfg <- default_config()
  cfg$container$image <- "myrepo/myimg"
  expect_equal(generate_container_config(cfg, "r-shiny")$container_tag, "latest")
})

test_that("bake_dockerfile_dependencies bakes sysreqs + install.packages for R (no r-cran-*)", {
  out <- withr::local_tempdir()

  # Set up app dependencies manifest
  app_dir <- fs::path(out, "src", "app")
  fs::dir_create(app_dir, recurse = TRUE)
  jsonlite::write_json(
    list(language = "r", packages = list("shiny", "ggplot2")),
    fs::path(app_dir, "dependencies.json"),
    auto_unbox = TRUE
  )

  # Set up a minimal Dockerfile to bake into
  dockerfile_dir <- fs::path(out, "dockerfiles")
  fs::dir_create(dockerfile_dir)
  writeLines(
    c("FROM rocker/r-ver:4.6.0", "", "EXPOSE 3838"),
    fs::path(dockerfile_dir, "Dockerfile")
  )

  cfg <- list(dependencies = list(system_packages = c("libfoo-dev")))

  mockery::stub(
    bake_dockerfile_dependencies,
    "query_sysreqs",
    function(...) "libxml2-dev"
  )

  bake_dockerfile_dependencies(out, dockerfile_dir, config = cfg)

  df_content <- readLines(fs::path(dockerfile_dir, "Dockerfile"))

  # System-deps RUN line must appear with --force-confold and both packages
  expect_true(any(grepl("--force-confold", df_content)))
  expect_true(any(grepl("libxml2-dev", df_content)))
  expect_true(any(grepl("libfoo-dev", df_content)))

  # R package install line uses install.packages, not r-cran-*
  expect_true(any(grepl("install\\.packages", df_content)))
  expect_false(any(grepl("r-cran-", df_content)))
})

test_that("query_sysreqs parses the Posit sysreqs API response into apt packages", {
  skip_if_not_installed("mockery")
  fixture <- paste0(
    '{"requirements":[',
    '{"name":"fs","requirements":{"packages":["cmake","libuv1-dev"]}},',
    '{"name":"curl","requirements":{"packages":["libcurl4-openssl-dev","libssl-dev"]}}',
    ']}'
  )
  mockery::stub(query_sysreqs, "utils::download.file", function(url, destfile, ...) {
    writeLines(fixture, destfile)
    0L
  })
  res <- query_sysreqs(c("fs", "curl"))
  expect_setequal(res, c("cmake", "libuv1-dev", "libcurl4-openssl-dev", "libssl-dev"))
})

test_that("query_sysreqs returns character(0) when the lookup fails", {
  skip_if_not_installed("mockery")
  mockery::stub(query_sysreqs, "utils::download.file", function(...) stop("network down"))
  expect_equal(query_sysreqs("fs"), character(0))
})
