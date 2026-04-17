library(shiny)
library(bslib)

datasets <- list(
  "Motor Trends (mtcars)" = mtcars,
  "Iris Flowers" = iris,
  "Air Quality" = airquality,
  "Old Faithful" = faithful,
  "Swiss Fertility" = swiss
)

ui <- page_navbar(
  title = "Data Explorer",
  window_title = "Data Explorer",
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
    title = "Explore",
    icon = bsicons::bs_icon("graph-up"),
    padding = "1.2rem",

    page_sidebar(
      sidebar = sidebar(
        title = "Options", width = 260,
        selectInput("dataset", "Dataset", names(datasets)),
        hr(),
        uiOutput("x_select"),
        uiOutput("y_select"),
        hr(),
        selectInput("plot_type", "Visualization",
                    c("Scatter" = "scatter", "Histogram" = "hist",
                      "Box Plot" = "box", "Density" = "density")),
        checkboxInput("show_smooth", "Trend line", FALSE),
        sliderInput("pt_size", "Point size", 0.5, 4, 1.8, step = 0.1, ticks = FALSE),
        sliderInput("alpha", "Opacity", 0.1, 1, 0.6, step = 0.05, ticks = FALSE),
        tags$div(class = "text-muted small mt-4", tags$em("shinyelectron demo"))
      ),

      layout_columns(
        col_widths = c(3, 3, 3, 3),
        value_box("Rows", textOutput("n_rows"),
                  showcase = bsicons::bs_icon("list-ol"), theme = "primary"),
        value_box("Columns", textOutput("n_cols"),
                  showcase = bsicons::bs_icon("layout-three-columns"), theme = "info"),
        value_box("Numeric", textOutput("n_num"),
                  showcase = bsicons::bs_icon("hash"), theme = "success"),
        value_box("Missing", textOutput("n_na"),
                  showcase = bsicons::bs_icon("exclamation-triangle"), theme = "warning")
      ),

      navset_card_underline(
        title = NULL,
        nav_panel(
          title = tags$span(bsicons::bs_icon("graph-up"), " Plot"),
          plotOutput("main_plot", height = "360px")
        ),
        nav_panel(
          title = tags$span(bsicons::bs_icon("table"), " Table"),
          tags$div(style = "max-height:360px; overflow-y:auto;",
            tableOutput("data_table")
          )
        ),
        nav_panel(
          title = tags$span(bsicons::bs_icon("info-circle"), " Summary"),
          verbatimTextOutput("data_summary")
        ),
        full_screen = TRUE
      )
    )
  )
)

server <- function(input, output, session) {
  df <- reactive(datasets[[input$dataset]])
  nums <- reactive(names(df())[sapply(df(), is.numeric)])

  # Theme-aware plot colors
  plot_colors <- reactive({
    is_dark <- isTRUE(input$color_mode == "dark")
    list(
      bg = if (is_dark) "#212529" else "#ffffff",
      fg = if (is_dark) "#adb5bd" else "#495057",
      axis = if (is_dark) "#495057" else "#dee2e6",
      accent = if (is_dark) "#20c997" else "#198754",
      accent2 = if (is_dark) "#6edff6" else "#0dcaf0"
    )
  })

  output$x_select <- renderUI({
    n <- nums()
    selectInput("xvar", "X axis", n, selected = n[1])
  })
  output$y_select <- renderUI({
    n <- nums()
    selectInput("yvar", "Y axis", n, selected = n[min(2, length(n))])
  })

  output$n_rows <- renderText(nrow(df()))
  output$n_cols <- renderText(ncol(df()))
  output$n_num <- renderText(sum(sapply(df(), is.numeric)))
  output$n_na <- renderText(sum(is.na(df())))

  output$main_plot <- renderPlot({
    req(input$xvar, input$yvar)
    d <- df()
    col <- plot_colors()
    par(mar = c(4, 4, 1, 1), bg = col$bg, fg = col$fg,
        col.axis = col$fg, col.lab = col$fg, family = "sans")

    if (input$plot_type == "scatter") {
      plot(d[[input$xvar]], d[[input$yvar]],
           pch = 19, cex = input$pt_size,
           col = adjustcolor(col$accent, input$alpha),
           xlab = input$xvar, ylab = input$yvar,
           bty = "n", las = 1, axes = FALSE)
      axis(1, col = col$axis, col.ticks = col$axis)
      axis(2, las = 1, col = col$axis, col.ticks = col$axis)
      if (input$show_smooth) {
        ok <- complete.cases(d[[input$xvar]], d[[input$yvar]])
        lo <- loess(d[[input$yvar]][ok] ~ d[[input$xvar]][ok])
        ox <- order(d[[input$xvar]][ok])
        lines(d[[input$xvar]][ok][ox], predict(lo)[ox], col = col$accent2, lwd = 2.5)
      }
    } else if (input$plot_type == "hist") {
      hist(d[[input$xvar]], breaks = 25,
           col = adjustcolor(col$accent, 0.4), border = adjustcolor(col$accent, 0.7),
           main = "", xlab = input$xvar, ylab = "Frequency",
           las = 1, axes = FALSE)
      axis(1, col = col$axis, col.ticks = col$axis)
      axis(2, las = 1, col = col$axis, col.ticks = col$axis)
    } else if (input$plot_type == "box") {
      boxplot(d[[input$xvar]], d[[input$yvar]],
              names = c(input$xvar, input$yvar),
              col = adjustcolor(c(col$accent, col$accent2), 0.3),
              border = c(col$accent, col$accent2),
              las = 1, bty = "n", axes = FALSE, horizontal = TRUE)
      axis(1, col = col$axis, col.ticks = col$axis)
      axis(2, las = 1, col = col$axis, col.ticks = col$axis)
    } else if (input$plot_type == "density") {
      dens <- density(d[[input$xvar]], na.rm = TRUE)
      plot(dens, main = "", xlab = input$xvar, bty = "n",
           las = 1, axes = FALSE, col = col$accent, lwd = 2)
      polygon(dens, col = adjustcolor(col$accent, 0.15), border = NA)
      lines(dens, col = col$accent, lwd = 2.5)
      axis(1, col = col$axis, col.ticks = col$axis)
      axis(2, las = 1, col = col$axis, col.ticks = col$axis)
    }
  })

  output$data_table <- renderTable(head(df(), 50), striped = TRUE, hover = TRUE)
  output$data_summary <- renderPrint(summary(df()))
}

shinyApp(ui, server)
