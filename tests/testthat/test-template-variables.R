# Render the shared Electron templates the way export() does: write
# `config` as _shinyelectron.yml, read it back with read_config(), then run
# process_templates(). Returns the path to the generated main.js; the
# temporary directories live until `env` exits.
render_main_js <- function(config = list(), app_name = "Test App",
                           is_multi_app = FALSE, apps_manifest = NULL,
                           env = parent.frame()) {
  appdir <- withr::local_tempdir(.local_envir = env)
  if (length(config) > 0) {
    yaml::write_yaml(config, file.path(appdir, "_shinyelectron.yml"))
  }
  out <- withr::local_tempdir(.local_envir = env)
  process_templates(
    out, app_name, "r-shiny", runtime_strategy = "system",
    config = read_config(appdir), is_multi_app = is_multi_app,
    apps_manifest = apps_manifest, verbose = FALSE
  )
  file.path(out, "main.js")
}

# Settings that each land in a JavaScript string literal in main.js. With
# `tray = TRUE` the render covers the tray sites (and the minimal menu, the
# updater, and a multi-app suite); otherwise it covers the quit dialog.
escaping_config <- function(tray = FALSE) {
  config <- list(
    app = list(log_dir = "C:\\Users\\me\\new-logs"),
    menu = list(help_url = "https://example.org/search?q=shiny&lang=en")
  )
  if (tray) {
    config$tray <- list(
      enabled = TRUE, tooltip = "Joe's \"tray\"", icon = "icons/Bob's tray.png"
    )
    config$menu$template <- "minimal"
    config$updates <- list(enabled = TRUE)
  }
  config
}

render_escaping_main_js <- function(app_name, tray = FALSE, env = parent.frame()) {
  apps <- list(list(
    id = "app1", name = "App One", description = "First app",
    path = "src/apps/app1", type = "r-shiny"
  ))
  render_main_js(
    escaping_config(tray), app_name = app_name, is_multi_app = tray,
    apps_manifest = if (tray) apps, env = env
  )
}

# Settings that land in the inline scripts of lifecycle.html (the preloader
# background) and launcher.html (the suite's app list), with text that can
# end or confuse an HTML <script> block.
hostile_background <- "url('it's.png') #0f0 & \"x\" </script><!--<script> \\ end"
hostile_apps <- function() {
  list(list(
    id = "app1", name = "Bob's <App>",
    description = paste0(
      "Tom's \"R&D\" </script><!--<script> \\ ", intToUtf8(0x2028), " end"
    ),
    path = "src/apps/app1", type = "r-shiny"
  ))
}

# Render a suite with the hostile settings; returns the output directory.
render_html_pages <- function(app_name = "Test App", env = parent.frame()) {
  main_path <- render_main_js(
    list(preloader = list(background = hostile_background)),
    app_name = app_name, is_multi_app = TRUE, apps_manifest = hostile_apps(),
    env = env
  )
  dirname(main_path)
}

read_text <- function(path) paste(readLines(path, warn = FALSE), collapse = "\n")

# The code inside each <script> block of an HTML page.
script_bodies <- function(html) {
  blocks <- regmatches(
    html, gregexpr("<script[^>]*>[\\s\\S]*?</script>", html, perl = TRUE)
  )[[1]]
  gsub("^<script[^>]*>|</script>$", "", blocks, perl = TRUE)
}

# Case-insensitive count of a fixed string in `text`.
count_fixed <- function(text, pattern) {
  sum(gregexpr(tolower(pattern), tolower(text), fixed = TRUE)[[1]] > 0)
}

# Evaluate JavaScript expressions with node and return their values. The
# JSON travels back as ASCII, with other characters as \u escapes.
node_values <- function(expressions, simplify = TRUE) {
  script <- withr::local_tempfile(
    lines = paste0(
      "const out = JSON.stringify([", paste(expressions, collapse = ", "), "]);\n",
      "process.stdout.write(out.replace(/[^\\x00-\\x7e]/g, (c) => ",
      "'\\\\u' + c.charCodeAt(0).toString(16).padStart(4, '0')));"
    ),
    fileext = ".js"
  )
  jsonlite::fromJSON(processx::run("node", script)$stdout, simplifyVector = simplify)
}

# Evaluate with node the first single-quoted JavaScript literal on each line
# of `lines` that contains `pattern`, returning the strings node sees.
js_values <- function(lines, pattern) {
  hits <- grep(pattern, lines, fixed = TRUE, value = TRUE)
  node_values(regmatches(hits, regexpr("'(?:[^'\\\\]|\\\\.)*'", hits, perl = TRUE)))
}

# The JavaScript expression assigned on the first line of `lines` that
# contains `prefix` (such as "var apps = "), without the closing semicolon.
js_assignment <- function(lines, prefix) {
  line <- grep(prefix, lines, fixed = TRUE, value = TRUE)[1]
  start <- regexpr(prefix, line, fixed = TRUE) + nchar(prefix)
  sub(";\\s*$", "", substring(line, start))
}

# --- Help menu ---

test_that("has_help_url is TRUE only for a non-empty help_url", {
  has_help_url <- function(help_url) {
    generate_template_variables(
      app_name = "Test App", app_slug = "test-app", app_type = "r-shiny",
      runtime_strategy = "shinylive", icon = NULL,
      backend_module = "shinylive.js", brand = NULL,
      config = list(menu = list(help_url = help_url))
    )$has_help_url
  }
  expect_false(has_help_url(NULL))
  expect_false(has_help_url(""))
  expect_true(has_help_url("https://docs.example.com"))
})

test_that("Help > Documentation renders only when help_url is set", {
  has_docs_item <- function(config) {
    main <- readLines(render_main_js(config))
    any(grepl("label: 'Documentation'", main, fixed = TRUE))
  }
  expect_false(has_docs_item(list()))
  expect_false(has_docs_item(list(menu = list(help_url = ""))))
  expect_true(has_docs_item(list(menu = list(help_url = "https://docs.example.com"))))
})

test_that("is_nonempty_string accepts only a single non-empty string", {
  expect_true(is_nonempty_string("x"))
  expect_false(is_nonempty_string(NULL))
  expect_false(is_nonempty_string(""))
  expect_false(is_nonempty_string(NA_character_))
  expect_false(is_nonempty_string(c("a", "b")))
  expect_false(is_nonempty_string(1))
})

# --- JavaScript string escaping ---

test_that("js_str escapes backslashes before single quotes", {
  expect_identical(js_str("Bob's"), "Bob\\'s")
  expect_identical(js_str("C:\\new"), "C:\\\\new")
  # A backslash in front of a quote must not cancel the quote's escape.
  expect_identical(js_str("a\\'b"), "a\\\\\\'b")
  # Double quotes and ampersands pass through untouched.
  expect_identical(js_str("R&D \"Lab\""), "R&D \"Lab\"")
})

test_that("js_str output cannot end or disturb an HTML script block", {
  expect_identical(
    js_str("</script><!--<SCRIPT>"),
    "\\u003C/script>\\u003C!--\\u003CSCRIPT>"
  )
})

test_that("js_str keeps line terminators out of the literal", {
  expect_identical(js_str("one\ntwo\rthree"), "one two three")
  expect_identical(js_str("a\u2028b\u2029c"), "a\\u2028b\\u2029c")
})

test_that("js_str returns NULL for NULL and coerces scalars", {
  expect_null(js_str(NULL))
  expect_identical(js_str(1.5), "1.5")
  expect_identical(js_str(TRUE), "TRUE")
  expect_identical(js_str(c("a'", "b")), c("a\\'", "b"))
})

test_that("json_for_script keeps JSON valid and inert inside a script block", {
  separators <- intToUtf8(c(0x2028, 0x2029), multiple = TRUE)
  x <- list(list(
    name = "a </script><!--<script> b",
    note = paste0("c", separators[1], "d", separators[2], "e")
  ))
  json <- json_for_script(x)
  expect_type(json, "character")
  expect_false(grepl("<", json, fixed = TRUE))
  expect_false(any(vapply(separators, grepl, logical(1), json, fixed = TRUE)))
  expect_true(jsonlite::validate(json))
  expect_identical(jsonlite::fromJSON(json, simplifyVector = FALSE), x)
})

test_that("config strings used in JavaScript literals get escaped *_js entries", {
  vars <- generate_template_variables(
    app_name = "Bob's App", app_slug = "bobs-app", app_type = "r-shiny",
    runtime_strategy = "system", icon = NULL, backend_module = "native-r.js",
    brand = NULL,
    config = list(
      app = list(version = 2, log_level = "info", log_dir = "C:\\logs"),
      tray = list(icon = "icons/Bob's tray.png"),
      menu = list(help_url = "https://example.org/?a=1&b=it's"),
      preloader = list(background = "url('bg.png') #fff")
    ),
    is_multi_app = TRUE,
    apps_manifest = list(list(id = "a", name = "<A>", description = "", path = "p", type = "r-shiny"))
  )
  expect_identical(vars$app_name_js, "Bob\\'s App")
  expect_identical(vars$app_version_js, "2")
  # The tray tooltip falls back to the app name.
  expect_identical(vars$tray_tooltip_js, "Bob\\'s App")
  expect_identical(vars$tray_icon_js, "Bob\\'s tray.png")
  expect_identical(vars$help_url_js, "https://example.org/?a=1&b=it\\'s")
  expect_identical(vars$log_dir_js, "C:\\\\logs")
  expect_identical(vars$log_level_js, "info")
  expect_identical(vars$preloader_background_js, "url(\\'bg.png\\') #fff")
  expect_identical(
    vars$apps_json,
    '[{"id":"a","name":"\\u003CA>","description":"","path":"p","type":"r-shiny"}]'
  )
  # The plain entries stay as they are for the HTML templates.
  expect_identical(vars$app_name, "Bob's App")
  expect_identical(vars$preloader_background, "url('bg.png') #fff")
})

test_that("templates put config strings into JavaScript only through escaped variables", {
  # A double mustache HTML-escapes but does not JavaScript-escape, so script
  # code may use one only for numbers and for values the package builds or
  # validates (the slug, the app type, internal file names). Everything else
  # must come through a triple-mustache *_js (js_str()) or *_json (JSON)
  # variable. main.js is all script; the HTML templates are checked inside
  # their <script> blocks, while their markup keeps the double mustache.
  safe_double <- c(
    "backend_module", "app_type", "app_slug", "icon_file", "server_port",
    "window_width", "window_height", "shutdown_timeout", "splash_duration"
  )
  shared <- system.file("electron", "shared", package = "shinyelectron")
  scripts <- list(
    main.js = read_text(file.path(shared, "main.js")),
    lifecycle.html = script_bodies(read_text(file.path(shared, "lifecycle.html"))),
    launcher.html = script_bodies(read_text(file.path(shared, "launcher.html")))
  )
  for (file in names(scripts)) {
    code <- paste(scripts[[file]], collapse = "\n")
    tags <- unlist(regmatches(
      code, gregexpr("\\{\\{\\{?[^#^/!{}][^{}]*\\}\\}\\}?", code, perl = TRUE)
    ))
    triple <- startsWith(tags, "{{{")
    vars <- gsub("[{}[:space:]]", "", tags)
    expect_true(any(triple), info = file)
    expect_equal(
      vars[triple][!grepl("_(js|json)$", vars[triple])], character(0),
      info = file
    )
    expect_equal(setdiff(vars[!triple], safe_double), character(0), info = file)
  }
})

test_that("main.js carries config strings into JavaScript literals intact", {
  main <- readLines(render_escaping_main_js("Bob's App"))
  expect_true(any(grepl("title: 'Close Bob\\'s App',", main, fixed = TRUE)))
  expect_true(any(grepl(
    "const logDir = 'C:\\\\Users\\\\me\\\\new-logs' ||", main, fixed = TRUE
  )))
  # The help URL keeps a literal '&' instead of the HTML entity.
  expect_true(any(grepl(
    "shell.openExternal('https://example.org/search?q=shiny&lang=en')",
    main, fixed = TRUE
  )))
  expect_false(any(grepl("&amp;", main, fixed = TRUE)))

  tray <- readLines(render_escaping_main_js("Bob's App", tray = TRUE))
  expect_true(any(grepl("tray.setToolTip('Joe\\'s \"tray\"');", tray, fixed = TRUE)))
  expect_true(any(grepl("tray.setToolTip('Bob\\'s App - ' + statusText);", tray, fixed = TRUE)))
  expect_true(any(grepl("(selectedApp.name || 'Bob\\'s App')", tray, fixed = TRUE)))
  expect_true(any(grepl("'assets', 'Bob\\'s tray.png'", tray, fixed = TRUE)))
})

test_that("HTML markup keeps HTML-escaping the app name", {
  out <- render_html_pages(app_name = "R&D <Lab>")
  lifecycle <- readLines(file.path(out, "lifecycle.html"))
  expect_true(any(grepl("<title>R&amp;D &lt;Lab&gt;</title>", lifecycle, fixed = TRUE)))
  launcher <- readLines(file.path(out, "launcher.html"))
  expect_true(any(grepl("<h1>R&amp;D &lt;Lab&gt;</h1>", launcher, fixed = TRUE)))
  # main.js escapes the name for JavaScript instead of HTML, so the quit
  # dialog shows it as typed.
  main <- readLines(file.path(out, "main.js"))
  expect_true(any(grepl("title: 'Close R&D \\u003CLab>',", main, fixed = TRUE)))
})

test_that("lifecycle and launcher scripts keep hostile settings inside their values", {
  out <- render_html_pages()
  shared <- system.file("electron", "shared", package = "shinyelectron")
  for (page in c("lifecycle.html", "launcher.html")) {
    template <- read_text(file.path(shared, page))
    rendered <- read_text(file.path(out, page))
    # A setting must not add anything that ends a script block or changes
    # where the HTML parser ends it.
    for (marker in c("<script", "</script", "<!--")) {
      expect_equal(
        count_fixed(rendered, marker), count_fixed(template, marker),
        info = paste(page, marker)
      )
    }
  }
  lifecycle <- readLines(file.path(out, "lifecycle.html"))
  expect_true(any(grepl(
    paste0("var preloaderBackground = '", js_str(hostile_background), "';"),
    lifecycle, fixed = TRUE
  )))
  expect_false(any(grepl("&amp;", lifecycle, fixed = TRUE)))
  launcher <- readLines(file.path(out, "launcher.html"))
  expect_true(any(grepl(
    paste0("var apps = ", json_for_script(hostile_apps()), ";"),
    launcher, fixed = TRUE
  )))
})

test_that("main.js parses for app names with quotes, backslashes, and newlines", {
  skip_on_cran()
  skip_if_not(nzchar(Sys.which("node")), "Node.js not available")

  names <- c("Bob's App", "The \"Best\" App", "C:\\Apps\\new", "Line one\nLine two")
  for (name in names) {
    for (tray in c(FALSE, TRUE)) {
      main_path <- render_escaping_main_js(name, tray = tray)
      check <- processx::run("node", c("--check", main_path), error_on_status = FALSE)
      expect_equal(check$status, 0L, info = paste0(name, " (tray = ", tray, "): ", check$stderr))
    }
  }
})

test_that("main.js string literals evaluate to the configured values", {
  skip_on_cran()
  skip_if_not(nzchar(Sys.which("node")), "Node.js not available")

  name <- "Bob's \"Best\" C:\\Apps\nDashboard"
  shown <- "Bob's \"Best\" C:\\Apps Dashboard"

  main <- readLines(render_escaping_main_js(name))
  expect_equal(js_values(main, "const logDir = "), "C:\\Users\\me\\new-logs")
  expect_equal(
    js_values(main, "shell.openExternal("),
    "https://example.org/search?q=shiny&lang=en"
  )
  expect_equal(js_values(main, "title: 'Close "), paste("Close", shown))
  expect_equal(js_values(main, "title: 'About "), paste("About", shown))

  tray <- readLines(render_escaping_main_js(name, tray = TRUE))
  expect_equal(
    js_values(tray, "tray.setToolTip("),
    c("Joe's \"tray\"", paste(shown, "- "), shown)
  )
  expect_equal(js_values(tray, "title: 'About "), paste("About", shown))
})

test_that("lifecycle and launcher scripts parse and keep their values", {
  skip_on_cran()
  skip_if_not(nzchar(Sys.which("node")), "Node.js not available")

  out <- render_html_pages()
  for (page in c("lifecycle.html", "launcher.html")) {
    bodies <- script_bodies(read_text(file.path(out, page)))
    expect_length(bodies, 1)
    script <- withr::local_tempfile(lines = bodies, fileext = ".js")
    check <- processx::run("node", c("--check", script), error_on_status = FALSE)
    expect_equal(check$status, 0L, info = paste0(page, ": ", check$stderr))
  }

  lifecycle <- readLines(file.path(out, "lifecycle.html"))
  expect_equal(js_values(lifecycle, "var preloaderBackground = "), hostile_background)

  launcher <- readLines(file.path(out, "launcher.html"))
  apps <- node_values(js_assignment(launcher, "var apps = "), simplify = FALSE)[[1]]
  expect_equal(apps[[1]]$name, hostile_apps()[[1]]$name)
  expect_equal(apps[[1]]$description, hostile_apps()[[1]]$description)
})
