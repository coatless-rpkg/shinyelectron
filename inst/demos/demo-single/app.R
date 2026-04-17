library(shiny)
library(bslib)

detect_backend <- function() {
  if (file.exists("/.dockerenv") || file.exists("/run/.containerenv")) return("container")
  if (grepl("wasm", Sys.info()[["machine"]])) return("shinylive")
  # Check for runtime manifest (auto-download writes this at build time)
  app_dir <- getwd()
  if (file.exists(file.path(app_dir, "runtime-manifest.json"))) return("auto-download")
  r_home <- R.home()
  if (grepl("portable-r", r_home)) return("bundled")
  if (grepl("runtime.R", r_home)) return("bundled")
  "system"
}

backend_label <- detect_backend()
app_title <- paste("R Shiny", tools::toTitleCase(backend_label))

ui <- page_navbar(
  title = app_title,
  window_title = paste("shinyelectron", app_title),
  theme = bs_theme(version = 5, preset = "shiny", font_scale = 0.92),
  fillable = TRUE,
  nav_spacer(),
  nav_item(input_dark_mode()),

  nav_panel(
    title = "Dashboard",
    padding = "1.2rem",

    layout_columns(
      col_widths = c(3, 3, 3, 3),
      value_box("Backend", textOutput("backend"), theme = "primary"),
      value_box("R Version", textOutput("r_ver"), theme = "success"),
      value_box("Platform", textOutput("plat"), theme = "info"),
      value_box("Packages", textOutput("n_pkgs"), theme = "warning")
    ),

    layout_columns(
      col_widths = c(8, 4),
      card(
        card_header("Interactive Plot"),
        card_body(
          sliderInput("n", "Data points:", 20, 200, 80, ticks = FALSE),
          plotOutput("plot", height = "280px")
        ),
        full_screen = TRUE
      ),
      card(
        card_header("Runtime Details"),
        card_body(
          tags$table(class = "table table-borderless", style = "font-size:13px;",
            tags$tr(tags$td("R Home", class = "text-muted"),
                    tags$td(tags$code(textOutput("r_home", inline = TRUE),
                                      style = "font-size:10px; word-break:break-all;"))),
            tags$tr(tags$td("Working Dir", class = "text-muted"),
                    tags$td(tags$code(textOutput("wd", inline = TRUE),
                                      style = "font-size:10px; word-break:break-all;"))),
            tags$tr(tags$td("Architecture", class = "text-muted"),
                    tags$td(textOutput("arch", inline = TRUE))),
            tags$tr(tags$td("OS", class = "text-muted"),
                    tags$td(textOutput("os", inline = TRUE))),
            tags$tr(tags$td("Clock", class = "text-muted"),
                    tags$td(textOutput("clock", inline = TRUE),
                            style = "font-variant-numeric:tabular-nums;"))
          )
        )
      )
    )
  )
)

server <- function(input, output, session) {
  output$backend <- renderText(detect_backend())
  output$r_ver <- renderText(paste0("R ", R.version$major, ".", R.version$minor))
  output$plat <- renderText(Sys.info()[["sysname"]])
  output$n_pkgs <- renderText(length(loadedNamespaces()))
  output$r_home <- renderText(R.home())
  output$wd <- renderText(getwd())
  output$arch <- renderText(Sys.info()[["machine"]])
  output$os <- renderText(paste(Sys.info()[["sysname"]], Sys.info()[["release"]]))
  output$clock <- renderText({ invalidateLater(1000); format(Sys.time(), "%H:%M:%S") })

  output$plot <- renderPlot({
    set.seed(42)
    x <- rnorm(input$n); y <- x + rnorm(input$n, sd = 0.5)
    par(mar = c(3, 3, 1, 1))
    plot(x, y, pch = 19, col = rgb(0.05, 0.43, 0.99, 0.5), cex = 1.2,
         bty = "n", las = 1, xlab = "", ylab = "")
    abline(lm(y ~ x), col = "#0d6efd", lwd = 2)
  })
}

shinyApp(ui, server)
