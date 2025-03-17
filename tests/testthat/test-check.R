# Test check_directories function
test_that("check_directories validates directories correctly", {
  # Create temporary directories for testing
  temp_appdir <- tempfile("appdir")
  temp_destdir <- tempfile("destdir")
  dir.create(temp_appdir)
  
  # Clean up after tests
  on.exit(unlink(c(temp_appdir, temp_destdir), recursive = TRUE))
  
  # Valid case
  expect_true(check_directories(temp_appdir, temp_destdir))
  expect_true(dir.exists(temp_destdir)) # destdir should be created
  
  # Invalid appdir
  non_existent_dir <- tempfile("nonexistent")
  expect_error(
    check_directories(non_existent_dir, temp_destdir),
    "The specified app directory does not exist"
  )
})

# Test check_app_name function
test_that("check_app_name validates app names correctly", {
  # Valid cases
  expect_true(check_app_name("valid-app", tempdir()))
  expect_true(check_app_name("valid_app", tempdir()))
  expect_true(check_app_name("valid.app", tempdir()))
  expect_true(check_app_name("valid123", tempdir()))
  
  # NULL app_name should use basename of appdir
  expect_true(check_app_name(NULL, tempdir()))
  
  # Invalid cases
  expect_error(check_app_name(123, tempdir()), "app_name must be a single character string")
  expect_error(check_app_name(c("app1", "app2"), tempdir()), "app_name must be a single character string")
  expect_error(check_app_name("", tempdir()), "app_name cannot be empty")
  expect_error(check_app_name("invalid@app", tempdir()), "app_name can only contain alphanumeric")
  expect_error(check_app_name("invalid app", tempdir()), "app_name can only contain alphanumeric")
})

# Test check_platform function
test_that("check_platform validates platforms correctly", {
  # Valid cases
  expect_true(check_platform("win"))
  expect_true(check_platform("mac"))
  expect_true(check_platform("linux"))
  expect_true(check_platform(NULL))  # Should use current platform
  
  # Invalid cases
  expect_error(check_platform("android"), "Invalid platform")
  expect_error(check_platform("ios"), "Invalid platform")
})

# Test check_arch function
test_that("check_arch validates architectures correctly", {
  # Valid cases
  expect_true(check_arch("x64"))
  expect_true(check_arch("arm64"))
  expect_true(check_arch(NULL))  # Should use current architecture
  
  # Invalid cases
  expect_error(check_arch("arm32"), "Invalid architecture")
  expect_error(check_arch("x86"), "Invalid architecture")
})

# Test check_r_version function
test_that("check_r_version validates R versions correctly", {
  # Skip check if include_r is FALSE
  expect_true(check_r_version("invalid", FALSE))
  
  # Valid cases with include_r = TRUE
  expect_true(check_r_version("4.1.0", TRUE))
  expect_true(check_r_version("3.6.3", TRUE))
  expect_true(check_r_version(NULL, TRUE))  # Should use current R version
  
  # Invalid cases with include_r = TRUE
  expect_error(check_r_version("4.1", TRUE), "Invalid R version format")
  expect_error(check_r_version("R-4.1.0", TRUE), "Invalid R version format")
  expect_error(check_r_version("latest", TRUE), "Invalid R version format")
})

# Test check_icon function
test_that("check_icon validates icon files correctly", {
  # No icon provided case
  expect_true(check_icon(NULL, "win"))
  
  # Set up temporary icon files for testing
  temp_dir <- tempdir()
  win_icon <- file.path(temp_dir, "app.ico")
  mac_icon <- file.path(temp_dir, "app.icns")
  linux_icon <- file.path(temp_dir, "app.png")
  
  # Create empty files
  file.create(win_icon, mac_icon, linux_icon)
  on.exit(unlink(c(win_icon, mac_icon, linux_icon)))
  
  # Valid cases
  expect_true(check_icon(win_icon, "win"))
  expect_true(check_icon(mac_icon, "mac"))
  expect_true(check_icon(linux_icon, "linux"))
  
  # Non-existent icon file
  expect_error(check_icon("nonexistent.ico", "win"), "Icon file does not exist")
  
  # Incorrect format for platform
  expect_error(check_icon(mac_icon, "win"), "Invalid icon format for win")
  expect_error(check_icon(win_icon, "mac"), "Invalid icon format for mac")
  expect_error(check_icon(win_icon, "linux"), "Invalid icon format for linux")
})