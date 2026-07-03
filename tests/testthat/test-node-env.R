# Regression coverage for nodejs_subprocess_env() and run_command_safe()'s env
# handling. These guard the behavior that a Node.js PATH augmentation must
# EXTEND (not replace) the child environment, and that env values containing
# spaces survive intact.

make_fake_node <- function(dir) {
  node <- file.path(dir, if (.Platform$OS.type == "windows") "node.exe" else "node")
  writeLines("#!/bin/sh\n", node)
  Sys.chmod(node, "0755")
  node
}

test_that("nodejs_subprocess_env returns NULL when Node is already on PATH", {
  tmp <- withr::local_tempdir()
  node <- make_fake_node(tmp)
  # Match the helper's own normalization (fs::path_abs) so the PATH membership
  # check lines up regardless of tempdir slash quirks.
  node_dir <- dirname(fs::path_abs(node))
  withr::local_envvar(PATH = paste(node_dir, "/usr/bin", sep = .Platform$path.sep))
  local_mocked_bindings(get_node_command = function(...) node)
  expect_null(nodejs_subprocess_env())
})

test_that("nodejs_subprocess_env extends (not replaces) the environment when Node is off PATH", {
  tmp <- withr::local_tempdir()
  node <- make_fake_node(tmp)
  node_dir <- dirname(fs::path_abs(node))
  withr::local_envvar(PATH = "/usr/bin")
  local_mocked_bindings(get_node_command = function(...) node)

  env <- nodejs_subprocess_env()
  # "current" is what makes processx keep the inherited environment; without it
  # npm/electron-builder would lose APPDATA, HOME, etc.
  expect_true("current" %in% env)
  expect_true("PATH" %in% names(env))
  expect_match(env[["PATH"]], node_dir, fixed = TRUE)
})

test_that("run_command_safe preserves the inherited env and handles values with spaces", {
  skip_on_os("windows")
  res <- run_command_safe(
    "sh",
    c("-c", "echo \"FOO=[$FOO]\"; test -n \"$PATH\" && echo HASPATH=yes"),
    env = c("current", FOO = "a b c")
  )
  expect_equal(res$status, 0L)
  expect_match(res$stdout, "FOO=[a b c]", fixed = TRUE)  # space-bearing value intact
  expect_match(res$stdout, "HASPATH=yes", fixed = TRUE)  # inherited PATH survived
})

test_that("run_command_safe reports a missing command as failure without throwing", {
  res <- run_command_safe("shinyelectron-no-such-command-xyz", "--version")
  expect_true(is.list(res))
  expect_false(res$status == 0)
})

test_that("nodejs_subprocess_env ignores a same-named file in the working directory", {
  # A bare command name must resolve via PATH, not a decoy file in the CWD.
  tmp <- withr::local_tempdir()
  decoy <- file.path(tmp, if (.Platform$OS.type == "windows") "node.exe" else "node")
  writeLines("not really node", decoy)
  withr::local_dir(tmp)
  local_mocked_bindings(
    get_node_command = function(...) if (.Platform$OS.type == "windows") "node.exe" else "node"
  )

  env <- nodejs_subprocess_env()
  # Resolving a bare name must not prepend the working directory to PATH.
  path <- if (is.null(env)) "" else env[["PATH"]]
  expect_false(grepl(tmp, path, fixed = TRUE))
})

test_that("nodejs_subprocess_env does not leave a trailing PATH separator when PATH is empty", {
  tmp <- withr::local_tempdir()
  node <- make_fake_node(tmp)
  node_dir <- dirname(fs::path_abs(node))
  withr::local_envvar(PATH = "")
  local_mocked_bindings(get_node_command = function(...) node)

  env <- nodejs_subprocess_env()
  # A trailing separator would add an empty (working-directory) entry on POSIX.
  expect_equal(env[["PATH"]], node_dir)
  expect_false(endsWith(env[["PATH"]], .Platform$path.sep))
})
