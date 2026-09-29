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

# The script code of every template that render_shared_templates() renders,
# as lines: whole .js files and the <script> blocks of .html files.
template_scripts <- function() {
  shared <- system.file("electron", "shared", package = "shinyelectron")
  files <- list.files(shared, recursive = TRUE)
  scripts <- lapply(files, function(file) {
    text <- read_text(file.path(shared, file))
    code <- switch(tools::file_ext(file),
      js = text,
      html = script_bodies(text),
      stop("No script rule for template ", file)
    )
    unlist(strsplit(code, "\n", fixed = TRUE))
  })
  stats::setNames(scripts, files)
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
  # must come through a triple-mustache *_js (js_str()) or *_json
  # (json_for_script()) variable. Every rendered template is checked: .js
  # files as a whole and .html files inside their <script> blocks, while
  # HTML markup keeps the double mustache.
  safe_double <- c(
    "backend_module", "app_type", "app_slug", "icon_file", "server_port",
    "window_width", "window_height", "shutdown_timeout", "splash_duration"
  )
  scripts <- template_scripts()
  expect_true(all(c("main.js", "preload.js", "lifecycle.html", "launcher.html") %in% names(scripts)))
  triple_seen <- character(0)
  for (file in names(scripts)) {
    lines <- scripts[[file]]
    tags <- unlist(regmatches(
      lines, gregexpr("\\{\\{\\{?[^#^/!{}][^{}]*\\}\\}\\}?", lines, perl = TRUE)
    ))
    triple <- startsWith(tags, "{{{")
    vars <- gsub("[{}[:space:]]", "", tags)
    triple_seen <- c(triple_seen, vars[triple])
    expect_equal(
      vars[triple][!grepl("_(js|json)$", vars[triple])], character(0),
      info = file
    )
    expect_equal(setdiff(vars[!triple], safe_double), character(0), info = file)
  }
  # The scan reaches main.js and the script blocks of both HTML pages.
  expect_true(all(c("app_name_js", "preloader_background_js", "apps_json") %in% triple_seen))
})

test_that("*_js values sit inside single-quoted strings in template scripts", {
  # js_str() escapes for single-quoted literals only. Backticks, ${ and
  # double quotes pass through, so a *_js value in a template literal or a
  # double-quoted string would not be safe. Each one must follow an odd
  # number of unescaped single quotes on its line.
  scripts <- template_scripts()
  sites <- 0L
  for (file in names(scripts)) {
    for (line in scripts[[file]]) {
      starts <- gregexpr("\\{\\{\\{[^{}]*_js\\}\\}\\}", line, perl = TRUE)[[1]]
      for (start in starts[starts > 0]) {
        sites <- sites + 1L
        before <- gsub("\\\\.", "", substr(line, 1, start - 1), perl = TRUE)
        quotes <- nchar(gsub("[^']", "", before))
        expect_true(quotes %% 2 == 1, info = paste0(file, ": ", trimws(line)))
      }
    }
  }
  expect_gt(sites, 0)
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

test_that("main.js parses for app names with quotes, backslashes, backticks, and newlines", {
  skip_on_cran()
  skip_if_not(nzchar(Sys.which("node")), "Node.js not available")

  names <- c(
    "Bob's App", "The \"Best\" App", "C:\\Apps\\new", "Line one\nLine two",
    "Tick `x` ${x} App"
  )
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

  name <- "Bob's \"Best\" `C:\\Apps` ${x}\nDashboard"
  shown <- "Bob's \"Best\" `C:\\Apps` ${x} Dashboard"

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

# --- About dialog ---

# App metadata with quotes, backslashes, markup, and a line break, each of
# which would end or change a JavaScript literal if it were not escaped.
about_metadata <- function() {
  list(
    description = "It's a \"test\" \\ with <b>markup</b>\nand a second line",
    author = "Jane O'Hara <jane@example.org>",
    homepage = "https://example.org/it's?a=1&b=2",
    copyright = "Copyright 2026 O'Hara & Co \\ Ltd"
  )
}

about_flags <- c(
  "has_app_description", "has_app_author", "has_app_email",
  "has_app_homepage", "has_app_copyright"
)

about_variables <- function(app) {
  generate_template_variables(
    app_name = "Test App", app_slug = "test-app", app_type = "r-shiny",
    runtime_strategy = "system", icon = NULL, backend_module = "native-r.js",
    brand = NULL, config = list(app = app)
  )
}

# The lines of the rendered showAboutDialog() function.
about_code <- function(main) {
  start <- grep("async function showAboutDialog()", main, fixed = TRUE)
  end <- start + which(main[-seq_len(start)] == "}")[1]
  main[start:end]
}

test_that("About metadata gets escaped *_js entries and flags", {
  vars <- about_variables(about_metadata())
  expect_identical(vars$app_description_js, js_str(about_metadata()$description))
  expect_identical(vars$app_author_js, "Jane O\\'Hara")
  expect_identical(vars$app_email_js, "jane@example.org")
  expect_identical(vars$app_homepage_js, "https://example.org/it\\'s?a=1&b=2")
  expect_identical(vars$app_copyright_js, "Copyright 2026 O\\'Hara & Co \\\\ Ltd")
  expect_true(all(unlist(vars[about_flags])))
})

test_that("unset or blank About metadata leaves its flag off", {
  expect_false(any(unlist(about_variables(list())[about_flags])))
  blank <- list(description = "", author = "", homepage = "", copyright = "")
  expect_false(any(unlist(about_variables(blank)[about_flags])))
})

test_that("the About dialog offers only the buttons that apply", {
  plain <- about_code(readLines(render_main_js(list())))
  expect_false(any(grepl("buttons.push(", plain, fixed = TRUE)))
  expect_true(any(grepl("noLink: true", plain, fixed = TRUE)))

  full <- about_code(readLines(render_main_js(
    list(app = about_metadata(), updates = list(enabled = TRUE))
  )))
  for (button in c("Check for Updates", "Visit Website", "Email")) {
    expect_true(any(grepl(paste0("buttons.push('", button, "')"), full, fixed = TRUE)), info = button)
  }
  # The update check is not offered on macOS.
  guard <- grep("process.platform !== 'darwin'", full, fixed = TRUE)
  expect_length(guard, 1)
  expect_match(full[guard + 1], "Check for Updates", fixed = TRUE)

  no_updates <- about_code(readLines(render_main_js(
    list(app = about_metadata(), updates = list(enabled = FALSE))
  )))
  expect_false(any(grepl("Check for Updates", no_updates, fixed = TRUE)))
})

test_that("main.js parses with quoted About metadata, with and without updates", {
  skip_on_cran()
  skip_if_not(nzchar(Sys.which("node")), "Node.js not available")

  for (updates in c(TRUE, FALSE)) {
    for (template in c("default", "minimal")) {
      config <- list(
        app = about_metadata(), updates = list(enabled = updates),
        menu = list(template = template)
      )
      main_path <- render_main_js(config, app_name = "Bob's \"Best\" C:\\Apps")
      check <- processx::run("node", c("--check", main_path), error_on_status = FALSE)
      expect_equal(
        check$status, 0L,
        info = paste0("updates = ", updates, ", ", template, ": ", check$stderr)
      )
    }
  }
})

test_that("About dialog literals evaluate to the configured metadata", {
  skip_on_cran()
  skip_if_not(nzchar(Sys.which("node")), "Node.js not available")

  about <- about_code(readLines(render_main_js(
    list(app = about_metadata()), app_name = "Bob's App"
  )))
  first <- grep("const detail = [", about, fixed = TRUE) + 1
  last <- grep("].join('\\n');", about, fixed = TRUE) - 1
  detail <- node_values(paste0(
    "[", paste(about[first:last], collapse = "\n"), "].join('\\n')"
  ))
  expect_equal(detail, paste(
    "Version 1.0.0",
    "It's a \"test\" \\ with <b>markup</b> and a second line",
    "Author: Jane O'Hara",
    "Copyright 2026 O'Hara & Co \\ Ltd",
    "Built with shinyelectron",
    sep = "\n\n"
  ))
  expect_equal(
    js_values(about, "shell.openExternal("),
    c("https://example.org/it's?a=1&b=2", "mailto:jane@example.org")
  )
  expect_equal(js_values(about, "title: 'About "), "About Bob's App")
})

# --- Check for Updates ---

# Run the rendered checkForUpdatesInteractive() under node against a fake
# electron-updater and dialog module, once per scenario. Returns, for each
# scenario, what the user saw: "<type>: <message> [<buttons>]" for a dialog,
# and "download" when an update download started.
run_update_check <- function(scenarios) {
  main <- readLines(render_main_js(list(updates = list(enabled = TRUE))))
  start <- grep("^async function checkForUpdatesInteractive\\(\\)", main)
  end <- start + which(main[-seq_len(start)] == "}")[1]
  script <- withr::local_tempfile(fileext = ".js", lines = c(
    "(async () => {",
    "  let scenario;",
    "  let events = [];",
    "  const dialog = {",
    "    showMessageBox: async (win, o) => {",
    "      events.push(o.type + ': ' + o.message + (o.buttons ? ' [' + o.buttons.join('|') + ']' : ''));",
    "      return { response: scenario.response || 0 };",
    "    }",
    "  };",
    "  const require = () => ({ dialog });",
    "  const app = { getVersion: () => '1.0.0' };",
    "  const mainWindow = null;",
    "  const updaterLog = { error: () => {} };",
    "  const autoUpdater = {",
    "    autoDownload: false,",
    "    checkForUpdates: async () => {",
    "      if (scenario.checkError) throw new Error(scenario.checkError);",
    "      return scenario.result;",
    "    },",
    "    downloadUpdate: async () => {",
    "      events.push('download');",
    "      if (scenario.downloadError) throw new Error(scenario.downloadError);",
    "    }",
    "  };",
    main[start:end],
    "  const out = [];",
    paste0("  for (const s of ", jsonlite::toJSON(scenarios, auto_unbox = TRUE, null = "null"), ") {"),
    "    scenario = s;",
    "    events = [];",
    "    autoUpdater.autoDownload = !!s.autoDownload;",
    "    if (s.result && s.autoDownload) s.result.downloadPromise = Promise.resolve();",
    "    await checkForUpdatesInteractive();",
    "    await new Promise((resolve) => setTimeout(resolve, 10));",
    "    out.push(events);",
    "  }",
    "  process.stdout.write(JSON.stringify(out));",
    "})();"
  ))
  lapply(
    jsonlite::fromJSON(processx::run("node", script)$stdout, simplifyVector = FALSE),
    unlist
  )
}

test_that("Check for Updates answers every outcome with a dialog", {
  skip_on_cran()
  skip_if_not(nzchar(Sys.which("node")), "Node.js not available")

  current <- list(isUpdateAvailable = FALSE, updateInfo = list(version = "1.0.0"))
  newer <- list(isUpdateAvailable = TRUE, updateInfo = list(version = "2.0.0"))
  offer <- "info: Version 2.0.0 is available [Download|Later]"
  out <- run_update_check(list(
    list(result = NULL),
    list(result = current),
    list(result = newer, response = 0),
    list(result = newer, response = 1),
    list(result = newer, autoDownload = TRUE),
    list(checkError = "net::ERR_INTERNET_DISCONNECTED"),
    list(result = newer, response = 0, downloadError = "404 Not Found")
  ))

  expect_equal(out[[1]], "info: Updates work only in the installed app")
  expect_equal(out[[2]], "info: You are up to date")
  expect_equal(out[[3]], c(offer, "download"))
  expect_equal(out[[4]], offer)
  expect_equal(out[[5]], "info: Version 2.0.0 is downloading")
  expect_equal(out[[6]], "warning: Could not check for updates")
  expect_equal(out[[7]], c(offer, "download", "warning: Could not download the update"))
})

test_that("Check for Updates no longer attaches listeners or calls checkForUpdatesAndNotify", {
  main <- readLines(render_main_js(list(updates = list(enabled = TRUE))))
  start <- grep("^async function checkForUpdatesInteractive\\(\\)", main)
  end <- start + which(main[-seq_len(start)] == "}")[1]
  check <- main[start:end]
  expect_false(any(grepl("autoUpdater.on(", check, fixed = TRUE)))
  expect_false(any(grepl("checkForUpdatesAndNotify", check, fixed = TRUE)))
  expect_true(any(grepl("await autoUpdater.checkForUpdates()", check, fixed = TRUE)))
})

# --- macOS About panel ---

test_that("the macOS About panel gets the configured metadata", {
  panel_options <- function(config, app_name = "Test App") {
    main <- readLines(render_main_js(config, app_name = app_name))
    start <- grep("app.setAboutPanelOptions({", main, fixed = TRUE)
    end <- start + grep("});", main[-seq_len(start)], fixed = TRUE)[1]
    main[start:end]
  }

  plain <- panel_options(list())
  expect_true(any(grepl("applicationName: 'Test App',", plain, fixed = TRUE)))
  expect_true(any(grepl("applicationVersion: '1.0.0',", plain, fixed = TRUE)))
  expect_false(any(grepl("copyright:|website:|authors:", plain)))

  full <- panel_options(list(app = about_metadata()), app_name = "Bob's App")
  expect_true(any(grepl("applicationName: 'Bob\\'s App',", full, fixed = TRUE)))
  expect_true(any(grepl("copyright: 'Copyright 2026 O\\'Hara & Co \\\\ Ltd',", full, fixed = TRUE)))
  expect_true(any(grepl("website: 'https://example.org/it\\'s?a=1&b=2',", full, fixed = TRUE)))
  expect_true(any(grepl("authors: ['Jane O\\'Hara'],", full, fixed = TRUE)))
})

# Run the rendered showAboutDialog() under node as if on `platform`, choosing
# each of its buttons in turn. Returns the button labels and what each one
# did: "check" for the update check, "open <url>" for shell.openExternal().
run_about_dialog <- function(config, platform) {
  about <- about_code(readLines(render_main_js(config)))
  script <- withr::local_tempfile(fileext = ".js", lines = c(
    "(async () => {",
    paste0("  Object.defineProperty(process, 'platform', { value: '", platform, "' });"),
    "  let pick = 0;",
    "  let buttons = null;",
    "  const done = [];",
    "  const dialog = {",
    "    showMessageBox: async (win, o) => {",
    "      buttons = o.buttons;",
    "      return { response: pick };",
    "    }",
    "  };",
    "  const shell = { openExternal: async (url) => { done.push('open ' + url); } };",
    "  const require = () => ({ dialog, shell });",
    "  const mainWindow = null;",
    "  const checkForUpdatesInteractive = async () => { done.push('check'); };",
    about,
    "  await showAboutDialog();",
    "  const actions = [];",
    "  for (let i = 0; i < buttons.length; i++) {",
    "    pick = i;",
    "    done.length = 0;",
    "    await showAboutDialog();",
    "    actions.push(done.join(', '));",
    "  }",
    "  process.stdout.write(JSON.stringify({ buttons, actions }));",
    "})();"
  ))
  jsonlite::fromJSON(processx::run("node", script)$stdout)
}

test_that("each About button runs its own action, and macOS has no update check", {
  skip_on_cran()
  skip_if_not(nzchar(Sys.which("node")), "Node.js not available")

  config <- list(app = about_metadata(), updates = list(enabled = TRUE))
  homepage <- "open https://example.org/it's?a=1&b=2"
  email <- "open mailto:jane@example.org"

  linux <- run_about_dialog(config, "linux")
  expect_equal(linux$buttons, c("OK", "Check for Updates", "Visit Website", "Email"))
  expect_equal(linux$actions, c("", "check", homepage, email))

  mac <- run_about_dialog(config, "darwin")
  expect_equal(mac$buttons, c("OK", "Visit Website", "Email"))
  expect_equal(mac$actions, c("", homepage, email))

  plain <- run_about_dialog(list(), "win32")
  expect_equal(plain$buttons, "OK")
  expect_equal(plain$actions, "")
})
