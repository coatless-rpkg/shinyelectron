# detect_app_type error: no entrypoint (snapshot)

    Code
      detect_app_type(appdir)
    Condition
      Error in `detect_app_type()`:
      ! Could not autodetect app type from '<tmp>'
      i Expected one of: 'app.py', 'app.R', or 'server.R' plus 'ui.R'
      i Pass `app_type` explicitly if your layout is non-standard

# detect_app_type error: ambiguous (snapshot)

    Code
      detect_app_type(appdir)
    Condition
      Error in `detect_app_type()`:
      ! Ambiguous app type in '<tmp>': found both 'app.py' and 'app.R'
      i One directory cannot be both an R and Python Shiny app.
      i To package several apps in one shell, see `vignette("multi-app-suites", package = "shinyelectron")`

# detect_app_type error: incomplete R app (snapshot)

    Code
      detect_app_type(appdir)
    Condition
      Error in `detect_app_type()`:
      ! Incomplete R Shiny app in '<tmp>'
      i Expected both 'server.R' and 'ui.R', or a single 'app.R'
      x Found only 'server.R'

