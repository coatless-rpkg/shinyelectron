library(shiny)
library(bslib)

ui <- page_navbar(
  title = "Dashboard",
  window_title = "Dashboard",
  theme = bs_theme(
    version = 5,
    preset = "shiny",
    base_font = font_google("DM Sans"),
    heading_font = font_google("DM Sans"),
    font_scale = 0.92
  ),
  fillable = TRUE,

  nav_spacer(),
  nav_item(input_dark_mode(id = "color_mode")),

  nav_panel(
    title = "Overview",
    icon = bsicons::bs_icon("speedometer2"),
    padding = "1.2rem",

    page_sidebar(
      sidebar = sidebar(
        title = "Controls", width = 240,
        sliderInput("days", "Time range", 7, 90, 30, ticks = FALSE, post = " days"),
        selectInput("metric", "Metric",
                    c("Revenue" = "revenue", "Users" = "users", "Sessions" = "sessions")),
        hr(),
        radioButtons("chart_type", "Chart style",
                     c("Area" = "area", "Line" = "line", "Bar" = "bar"), inline = TRUE),
        tags$div(class = "text-muted small mt-4", tags$em("shinyelectron demo"))
      ),

      layout_columns(
        col_widths = c(3, 3, 3, 3),
        value_box("Active Users", textOutput("v_users"),
                  showcase = bsicons::bs_icon("people-fill"), theme = "primary"),
        value_box("Revenue", textOutput("v_revenue"),
                  showcase = bsicons::bs_icon("currency-dollar"), theme = "success"),
        value_box("Sessions", textOutput("v_sessions"),
                  showcase = bsicons::bs_icon("activity"), theme = "info"),
        value_box("Conversion", textOutput("v_conv"),
                  showcase = bsicons::bs_icon("bullseye"), theme = "warning")
      ),

      layout_columns(
        col_widths = c(8, 4),
        card(
          card_header(
            tags$div(class = "d-flex justify-content-between align-items-center",
              "Trend",
              tags$span(textOutput("trend_label", inline = TRUE), class = "text-muted small")
            ),
            class = "bg-transparent border-0"
          ),
          card_body(plotOutput("trend", height = "280px")),
          full_screen = TRUE
        ),
        card(
          card_header("Breakdown", class = "bg-transparent border-0"),
          card_body(plotOutput("breakdown", height = "280px")),
          full_screen = TRUE
        )
      )
    )
  )
)

server <- function(input, output, session) {
  # Resolve theme-aware plot colors
  plot_colors <- reactive({
    is_dark <- isTRUE(input$color_mode == "dark")
    list(
      bg = if (is_dark) "#212529" else "#ffffff",
      fg = if (is_dark) "#adb5bd" else "#495057",
      axis = if (is_dark) "#495057" else "#dee2e6",
      grid = if (is_dark) "#2b3035" else "#f1f3f5",
      accent = if (is_dark) "#6ea8fe" else "#0d6efd",
      bars = c("#0d6efd", "#198754", "#0dcaf0", "#ffc107", "#dc3545")
    )
  })

  output$v_users <- renderText(format(sample(180:450, 1), big.mark = ","))
  output$v_revenue <- renderText(paste0("$", format(sample(12e3:48e3, 1), big.mark = ",")))
  output$v_sessions <- renderText(format(sample(2e3:8e3, 1), big.mark = ","))
  output$v_conv <- renderText(paste0(sample(25:45, 1), "%"))
  output$trend_label <- renderText(paste0(input$days, "-day view"))

  ts <- reactive({
    n <- input$days
    dates <- seq(Sys.Date() - n, Sys.Date(), by = "day")
    set.seed(42 + n)
    base <- switch(input$metric, revenue = 5000, users = 200, sessions = 800)
    vals <- cumsum(rnorm(length(dates), base / n, base / (n * 2.5)))
    list(dates = dates, vals = vals)
  })

  output$trend <- renderPlot({
    d <- ts()
    col <- plot_colors()
    par(mar = c(3, 4, 0.5, 1), bg = col$bg, fg = col$fg,
        col.axis = col$fg, col.lab = col$fg, family = "sans")
    if (input$chart_type == "bar") {
      barplot(tail(d$vals, 14), col = adjustcolor(col$accent, 0.6),
              border = NA, las = 1, axes = FALSE, space = 0.3)
      axis(2, las = 1, col = col$axis, col.ticks = col$axis)
    } else {
      plot(d$dates, d$vals, type = "n", xlab = "", ylab = "",
           bty = "n", las = 1, axes = FALSE)
      axis(1, at = pretty(d$dates, 5), labels = format(pretty(d$dates, 5), "%b %d"),
           col = col$axis, col.ticks = col$axis)
      axis(2, las = 1, col = col$axis, col.ticks = col$axis)
      if (input$chart_type == "area") {
        polygon(c(d$dates[1], d$dates, tail(d$dates, 1)),
                c(min(d$vals), d$vals, min(d$vals)),
                col = adjustcolor(col$accent, 0.12), border = NA)
      }
      lines(d$dates, d$vals, col = col$accent, lwd = 2.5)
      points(tail(d$dates, 1), tail(d$vals, 1), pch = 19, col = col$accent, cex = 1.4)
    }
  })

  output$breakdown <- renderPlot({
    col <- plot_colors()
    set.seed(99)
    cats <- c("Organic", "Paid", "Referral", "Direct", "Social")
    vals <- sort(sample(50:300, 5), decreasing = TRUE)
    par(mar = c(3, 6, 0.5, 2), bg = col$bg, fg = col$fg,
        col.axis = col$fg, family = "sans")
    bp <- barplot(vals, horiz = TRUE, col = adjustcolor(col$bars, 0.6),
                  border = NA, las = 1, names.arg = cats, axes = FALSE)
    axis(1, col = col$axis, col.ticks = col$axis)
    text(vals + 8, bp, labels = vals, col = col$fg, cex = 0.85)
  })
}

shinyApp(ui, server)
