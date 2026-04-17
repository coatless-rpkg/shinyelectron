library(shiny)
library(bslib)

# --- Detect backend type ---
detect_backend <- function() {
  if (nzchar(Sys.getenv("DOCKER_CONTAINER", ""))) return("container (Docker)")
  if (nzchar(Sys.getenv("PODMAN_CONTAINER", ""))) return("container (Podman)")

  r_home <- R.home()
  wd <- getwd()

  if (grepl("runtime[/\\\\]R", r_home)) return("r-shiny (bundled)")
  if (grepl("\\.shinyelectron[/\\\\]runtimes", r_home)) return("r-shiny (auto-download)")
  if (grepl("shinylive", wd, ignore.case = TRUE)) return("r-shinylive (WebR)")

  "r-shiny (system)"
}

ui <- page_navbar(
  title = "About",
  window_title = "About",
  theme = bs_theme(
    version = 5,
    preset = "shiny",
    base_font = font_google("DM Sans"),
    heading_font = font_google("DM Sans"),
    font_scale = 0.92
  ),
  fillable = TRUE,
  navbar_options = navbar_options(
    # Dark mode toggle in the navbar
    position = "static-top"
  ),

  nav_spacer(),
  nav_item(input_dark_mode(id = "color_mode")),

  nav_panel(
    title = "System",
    icon = bsicons::bs_icon("cpu"),
    padding = "1.2rem",

    layout_columns(
      col_widths = c(4, 4, 4),
      value_box(
        title = "Backend",
        value = textOutput("backend_type"),
        showcase = bsicons::bs_icon("gear-wide-connected"),
        theme = "primary"
      ),
      value_box(
        title = "R Version",
        value = textOutput("r_ver_short"),
        showcase = bsicons::bs_icon("braces"),
        theme = "success"
      ),
      value_box(
        title = "Packages",
        value = textOutput("n_pkgs"),
        showcase = bsicons::bs_icon("boxes"),
        theme = "info"
      )
    ),

    layout_columns(
      col_widths = c(6, 6),

      card(
        card_header(
          tags$span(bsicons::bs_icon("cpu-fill"), " Runtime"),
          class = "bg-transparent border-0"
        ),
        card_body(
          tags$table(
            class = "table table-borderless mb-0",
            style = "font-size:13px;",
            tags$tr(
              tags$td("R Version", class = "text-muted", style = "width:35%;"),
              tags$td(textOutput("r_ver", inline = TRUE), style = "font-weight:500;")
            ),
            tags$tr(
              tags$td("Platform", class = "text-muted"),
              tags$td(textOutput("platform", inline = TRUE), style = "font-weight:500;")
            ),
            tags$tr(
              tags$td("Architecture", class = "text-muted"),
              tags$td(textOutput("arch", inline = TRUE), style = "font-weight:500;")
            ),
            tags$tr(
              tags$td("OS", class = "text-muted"),
              tags$td(textOutput("os_ver", inline = TRUE), style = "font-weight:500;")
            ),
            tags$tr(
              tags$td("Locale", class = "text-muted"),
              tags$td(textOutput("locale", inline = TRUE), style = "font-weight:500;")
            ),
            tags$tr(
              tags$td("Backend", class = "text-muted"),
              tags$td(
                tags$span(
                  textOutput("backend_badge", inline = TRUE),
                  class = "badge bg-primary"
                )
              )
            )
          )
        )
      ),

      card(
        card_header(
          tags$span(bsicons::bs_icon("app-indicator"), " Application"),
          class = "bg-transparent border-0"
        ),
        card_body(
          tags$table(
            class = "table table-borderless mb-0",
            style = "font-size:13px;",
            tags$tr(
              tags$td("Suite", class = "text-muted", style = "width:35%;"),
              tags$td("shinyelectron Demo", style = "font-weight:500;")
            ),
            tags$tr(
              tags$td("Version", class = "text-muted"),
              tags$td("1.0.0", style = "font-weight:500;")
            ),
            tags$tr(
              tags$td("Framework", class = "text-muted"),
              tags$td("shinyelectron", style = "font-weight:500;")
            ),
            tags$tr(
              tags$td("Clock", class = "text-muted"),
              tags$td(
                textOutput("clock", inline = TRUE),
                style = "font-weight:500; font-variant-numeric:tabular-nums;"
              )
            ),
            tags$tr(
              tags$td("Working Dir", class = "text-muted"),
              tags$td(tags$code(
                textOutput("wd", inline = TRUE),
                style = "font-size:10px; word-break:break-all;"
              ))
            ),
            tags$tr(
              tags$td("R Home", class = "text-muted"),
              tags$td(tags$code(
                textOutput("r_home", inline = TRUE),
                style = "font-size:10px; word-break:break-all;"
              ))
            )
          )
        )
      )
    )
  ),

  nav_panel(
    title = "Packages",
    icon = bsicons::bs_icon("box-seam"),
    padding = "1.2rem",

    card(
      card_header(
        tags$div(
          class = "d-flex justify-content-between align-items-center",
          tags$span(bsicons::bs_icon("boxes"), " Loaded Namespaces"),
          tags$span(textOutput("n_pkgs_label", inline = TRUE), class = "text-muted small")
        ),
        class = "bg-transparent border-0"
      ),
      card_body(
        tags$div(
          style = "line-height:2;",
          uiOutput("pkg_badges")
        )
      ),
      full_screen = TRUE
    )
  )
)

server <- function(input, output, session) {
  backend <- detect_backend()

  output$backend_type <- renderText(backend)
  output$backend_badge <- renderText(backend)
  output$r_ver <- renderText(R.version.string)
  output$r_ver_short <- renderText(paste0("R ", R.version$major, ".", R.version$minor))
  output$platform <- renderText(R.version$platform)
  output$arch <- renderText(Sys.info()[["machine"]])
  output$os_ver <- renderText(paste(Sys.info()[["sysname"]], Sys.info()[["release"]]))
  output$locale <- renderText(Sys.getlocale("LC_COLLATE"))
  output$wd <- renderText(getwd())
  output$r_home <- renderText(R.home())
  output$n_pkgs <- renderText(length(loadedNamespaces()))
  output$n_pkgs_label <- renderText(paste(length(loadedNamespaces()), "loaded"))

  output$clock <- renderText({
    invalidateLater(1000)
    format(Sys.time(), "%H:%M:%S")
  })

  output$pkg_badges <- renderUI({
    pkgs <- sort(loadedNamespaces())
    # Use Bootstrap contextual classes instead of hardcoded colors
    badge_classes <- c("bg-primary", "bg-success", "bg-info",
                       "bg-warning", "bg-danger", "bg-secondary")
    tags$div(
      lapply(seq_along(pkgs), function(i) {
        cls <- badge_classes[((i - 1) %% length(badge_classes)) + 1]
        tags$span(
          pkgs[i],
          class = paste("badge", cls, "bg-opacity-25 text-body me-1 mb-1"),
          style = "font-size:11px; font-weight:500;"
        )
      })
    )
  })
}

shinyApp(ui, server)
