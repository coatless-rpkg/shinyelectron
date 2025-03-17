# Mock the user_cache_dir function to use a temporary directory for testing
mock_cache_base <- function() {
  # Create a temporary directory for testing
  test_dir <- fs::path(tempdir(), paste0("shinyelectron_test_cache_", round(runif(1, 1, 1000))))
  fs::dir_create(test_dir)
  return(test_dir)
}

# Test cache_dir() function ----
test_that("cache_dir(): returns and creates correct directory", {
  # Mock rappdirs::user_cache_dir
  mockery::stub(cache_dir, "rappdirs::user_cache_dir", mock_cache_base())
  
  # Test with create = TRUE
  path_str <- cache_dir(create = TRUE)
  expect_true(fs::dir_exists(path_str))
  expect_match(path_str, "assets$")
  
  # Test with create = FALSE 
  fs::dir_delete(path_str)
  mockery::stub(cache_dir, "rappdirs::user_cache_dir", mock_cache_base())
  path_no_create <- cache_dir(create = FALSE)
  expect_false(fs::dir_exists(path_no_create))
  
  # Clean up
  if (fs::dir_exists(dirname(path_str))) {
    fs::dir_delete(dirname(path_str))
  }
})

# Test cache_r_path() function ----
test_that("cache_r_path(): returns correct path structure", {
  # Mock cache_dir
  test_cache_dir <- fs::path(tempdir(), "cache_dir")
  mockery::stub(cache_r_path, "cache_dir", test_cache_dir)
  
  # Test path construction
  r_path <- cache_r_path("4.1.0", "win", "x64")
  expected_path <- fs::path(test_cache_dir, "r", "win", "x64", "4.1.0")
  expect_equal(r_path, expected_path)
  
  # Test with different parameters
  r_path2 <- cache_r_path("3.6.3", "mac", "arm64")
  expected_path2 <- fs::path(test_cache_dir, "r", "mac", "arm64", "3.6.3")
  expect_equal(r_path2, expected_path2)
})

# Test cache_npm_path() function ----
test_that("cache_npm_path(): returns correct path", {
  # Mock cache_dir
  test_cache_dir <- fs::path(tempdir(), "cache_dir")
  mockery::stub(cache_npm_path, "cache_dir", test_cache_dir)
  
  # Test path construction
  npm_path <- cache_npm_path()
  expected_path <- fs::path(test_cache_dir, "npm")
  expect_equal(npm_path, expected_path)
})

# Test cache_clear() function ----
test_that("cache_clear(): correctly removes cache directories", {
  # Create a test cache directory with subdirectories
  test_dir <- fs::path(tempdir(), paste0("shinyelectron_test_cache_", round(runif(1, 1, 1000))))
  fs::dir_create(test_dir)
  r_path <- fs::path(test_dir, "assets", "r")
  npm_path <- fs::path(test_dir, "assets", "npm")
  fs::dir_create(r_path, recurse = TRUE)
  fs::dir_create(npm_path, recurse = TRUE)
  
  # Write a test file in each directory
  writeLines("test", fs::path(r_path, "test.txt"))
  writeLines("test", fs::path(npm_path, "test.txt"))
  
  # Mock cache_dir and cli functions
  mockery::stub(cache_clear, "cache_dir", fs::path(test_dir, "assets"))
  mockery::stub(cache_clear, "cli::cli_alert_info", NULL)
  mockery::stub(cache_clear, "cli::cli_alert_success", NULL)
  
  # Test clearing R cache only
  cache_clear("r")
  expect_false(fs::dir_exists(r_path))
  expect_true(fs::dir_exists(npm_path))
  
  # Recreate R directory
  fs::dir_create(r_path, recurse = TRUE)
  writeLines("test", fs::path(r_path, "test.txt"))
  
  # Test clearing npm cache only
  cache_clear("npm")
  expect_true(fs::dir_exists(r_path))
  expect_false(fs::dir_exists(npm_path))
  
  # Recreate npm directory
  fs::dir_create(npm_path, recurse = TRUE)
  writeLines("test", fs::path(npm_path, "test.txt"))
  
  # Test clearing all cache
  cache_clear("all")
  expect_false(fs::dir_exists(r_path))
  expect_false(fs::dir_exists(npm_path))
  
  # Test when cache doesn't exist
  fs::dir_delete(fs::path(test_dir, "assets"))
  result <- cache_clear()
  expect_null(result)
  
  # Clean up
  if (fs::dir_exists(test_dir)) {
    fs::dir_delete(test_dir)
  }
})
