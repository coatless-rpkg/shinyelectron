# Setup demo R Shiny app ----
system.file("examples", "01_hello", package="shiny") |>
  fs::dir_copy("my-shiny-app", overwrite = TRUE)

# Export the R Shiny app to R Shinylive to an Electron app ----
shinyelectron::export(
  appdir = "my-shiny-app",
  destdir = "converted-app",
  app_name = "My-App-Title",
  app_type = "r-shinylive",
  platform = c("mac"), # c("win", "mac", "linux")
  arch = c("arm64"),   # c("x64", "arm64")
  overwrite = TRUE,
  run_after = TRUE,
  open_after = TRUE,
  verbose = TRUE
)

# Or use the individual functions:
converted <- convert_shiny_to_shinylive("my-shiny-app", "converted-app", overwrite = TRUE)
built <- build_electron_app(converted, "electron-app", overwrite = TRUE)
run_electron_app(built)
