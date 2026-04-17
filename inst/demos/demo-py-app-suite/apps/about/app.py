import platform
import sys
import os
from datetime import datetime

from shiny import App, reactive, render, ui


def detect_backend():
    if os.path.exists("/.dockerenv") or os.path.exists("/run/.containerenv"):
        return "container"
    if platform.machine() == "wasm32" or "pyodide" in sys.modules:
        return "shinylive"
    app_dir = os.path.dirname(os.path.abspath(__file__))
    manifest = os.path.join(app_dir, "runtime-manifest.json")
    if os.path.exists(manifest):
        return "auto-download"
    if os.path.exists(os.path.join(app_dir, "..", "..", "runtime", "Python")):
        return "bundled"
    return "system"


def shorten_path(p):
    home = os.path.expanduser("~")
    if p.startswith(home):
        p = "~" + p[len(home):]
    return p


app_ui = ui.page_navbar(
    ui.nav_spacer(),
    ui.nav_panel(
        "System",
        ui.layout_columns(
            ui.value_box("Backend", ui.output_text("backend_type"), theme="primary"),
            ui.value_box("Python", platform.python_version(), theme="success"),
            ui.value_box("Platform", platform.system() or "WebAssembly", theme="info"),
            col_widths=(4, 4, 4),
        ),
        ui.layout_columns(
            ui.card(
                ui.card_header("Runtime"),
                ui.tags.table(
                    {"class": "table table-borderless mb-0", "style": "font-size:13px;"},
                    ui.tags.tr(
                        ui.tags.td("Python Version", {"class": "text-muted", "style": "width:35%;"}),
                        ui.tags.td(platform.python_version(), {"style": "font-weight:500;"}),
                    ),
                    ui.tags.tr(
                        ui.tags.td("Platform", {"class": "text-muted"}),
                        ui.tags.td(platform.platform(), {"style": "font-weight:500;"}),
                    ),
                    ui.tags.tr(
                        ui.tags.td("Architecture", {"class": "text-muted"}),
                        ui.tags.td(platform.machine() or "wasm32", {"style": "font-weight:500;"}),
                    ),
                    ui.tags.tr(
                        ui.tags.td("OS", {"class": "text-muted"}),
                        ui.tags.td(
                            f"{platform.system()} {platform.release()}" if platform.system() else "WebAssembly",
                            {"style": "font-weight:500;"},
                        ),
                    ),
                    ui.tags.tr(
                        ui.tags.td("Backend", {"class": "text-muted"}),
                        ui.tags.td(ui.output_text("backend_badge", inline=True), {"style": "font-weight:500;"}),
                    ),
                ),
            ),
            ui.card(
                ui.card_header("Application"),
                ui.tags.table(
                    {"class": "table table-borderless mb-0", "style": "font-size:13px;"},
                    ui.tags.tr(
                        ui.tags.td("Suite", {"class": "text-muted", "style": "width:35%;"}),
                        ui.tags.td("Python Shiny Demo", {"style": "font-weight:500;"}),
                    ),
                    ui.tags.tr(
                        ui.tags.td("Version", {"class": "text-muted"}),
                        ui.tags.td("1.0.0", {"style": "font-weight:500;"}),
                    ),
                    ui.tags.tr(
                        ui.tags.td("Framework", {"class": "text-muted"}),
                        ui.tags.td("shinyelectron", {"style": "font-weight:500;"}),
                    ),
                    ui.tags.tr(
                        ui.tags.td("Clock", {"class": "text-muted"}),
                        ui.tags.td(ui.output_text("clock", inline=True), {"style": "font-weight:500;"}),
                    ),
                    ui.tags.tr(
                        ui.tags.td("Working Dir", {"class": "text-muted"}),
                        ui.tags.td(
                            ui.output_text("work_dir", inline=True),
                            {"style": "font-size:10px; word-break:break-all;"},
                        ),
                    ),
                    ui.tags.tr(
                        ui.tags.td("Python Home", {"class": "text-muted"}),
                        ui.tags.td(
                            ui.output_text("py_home", inline=True),
                            {"style": "font-size:10px; word-break:break-all;"},
                        ),
                    ),
                ),
            ),
            col_widths=(6, 6),
        ),
    ),
    ui.nav_panel(
        "Modules",
        ui.card(
            ui.card_header("Loaded Modules"),
            ui.output_text_verbatim("modules"),
            full_screen=True,
        ),
    ),
    title="About",
    id="navbar",
)


def server(input, output, session):
    @render.text
    def backend_type():
        return detect_backend()

    @render.text
    def backend_badge():
        return detect_backend()

    @render.text
    def clock():
        reactive.invalidate_later(1)
        return datetime.now().strftime("%H:%M:%S")

    @render.text
    def work_dir():
        return shorten_path(os.getcwd())

    @render.text
    def py_home():
        return shorten_path(sys.prefix)

    @render.text
    def modules():
        mods = sorted(set(m.split(".")[0] for m in sys.modules if not m.startswith("_")))
        return "\n".join(mods)


app = App(app_ui, server)
