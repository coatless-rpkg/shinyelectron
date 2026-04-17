import platform
import sys
import os
from datetime import datetime

from shiny import App, reactive, render, ui

# Detect available packages
try:
    import numpy as np
    import matplotlib
    HAS_PLOT = True
except ImportError:
    HAS_PLOT = False


def detect_backend():
    if os.path.exists("/.dockerenv") or os.path.exists("/run/.containerenv"):
        return "container"
    if platform.machine() == "wasm32" or "pyodide" in sys.modules:
        return "shinylive"
    # Check for runtime manifest (auto-download writes this at build time)
    app_dir = os.path.dirname(os.path.abspath(__file__))
    manifest = os.path.join(app_dir, "runtime-manifest.json")
    if os.path.exists(manifest):
        return "auto-download"
    # Check for bundled runtime embedded in the app
    if os.path.exists(os.path.join(app_dir, "..", "..", "runtime", "Python")):
        return "bundled"
    return "system"


def shorten_path(p):
    home = os.path.expanduser("~")
    if p.startswith(home):
        p = "~" + p[len(home):]
    return p


_backend = detect_backend()
_app_title = f"Python Shiny {_backend.title()}"

# Build plot or text output depending on available packages
if HAS_PLOT:
    interactive_panel = ui.card(
        ui.card_header("Interactive Plot"),
        ui.input_slider("n", "Data points:", min=20, max=500, value=150),
        ui.output_plot("scatter"),
        full_screen=True,
    )
else:
    interactive_panel = ui.card(
        ui.card_header("Interactive Test"),
        ui.input_slider("n", "Number of points:", min=10, max=200, value=50),
        ui.input_text("title", "Plot title:", value="Random Scatter"),
        ui.output_text_verbatim("stats"),
    )

app_ui = ui.page_navbar(
    ui.nav_spacer(),
    ui.nav_panel(
        "Dashboard",
        ui.layout_columns(
            ui.value_box("Runtime", ui.output_text("backend"), theme="primary"),
            ui.value_box("Python", platform.python_version(), theme="success"),
            ui.value_box("Platform", platform.system() or "WebAssembly", theme="info"),
            ui.value_box("Arch", platform.machine() or "wasm32", theme="warning"),
            col_widths=(3, 3, 3, 3),
        ),
        ui.layout_columns(
            interactive_panel,
            ui.card(
                ui.card_header("Runtime Details"),
                ui.tags.table(
                    {"class": "table table-borderless", "style": "font-size:13px;"},
                    ui.tags.tr(
                        ui.tags.td("Python Home", {"class": "text-muted"}),
                        ui.tags.td(ui.output_text("py_home", inline=True),
                                   {"style": "font-size:10px; word-break:break-all;"}),
                    ),
                    ui.tags.tr(
                        ui.tags.td("Working Dir", {"class": "text-muted"}),
                        ui.tags.td(ui.output_text("work_dir", inline=True),
                                   {"style": "font-size:10px; word-break:break-all;"}),
                    ),
                    ui.tags.tr(
                        ui.tags.td("OS", {"class": "text-muted"}),
                        ui.tags.td(f"{platform.system()} {platform.release()}"
                                   if platform.system() else "WebAssembly"),
                    ),
                    ui.tags.tr(
                        ui.tags.td("Clock", {"class": "text-muted"}),
                        ui.tags.td(ui.output_text("clock", inline=True)),
                    ),
                ),
            ),
            col_widths=(8, 4),
        ),
    ),
    title=_app_title,
    id="navbar",
)


def server(input, output, session):
    @render.text
    def backend():
        return detect_backend()

    @render.text
    def py_home():
        return shorten_path(sys.prefix)

    @render.text
    def work_dir():
        return shorten_path(os.getcwd())

    @render.text
    def clock():
        reactive.invalidate_later(1)
        return datetime.now().strftime("%H:%M:%S")

    if HAS_PLOT:
        @render.plot
        def scatter():
            np.random.seed(42)
            n = input.n()
            x = np.random.randn(n)
            y = x + np.random.randn(n) * 0.5

            import matplotlib.pyplot as plt
            fig, ax = plt.subplots(figsize=(8, 4))
            ax.scatter(x, y, alpha=0.6, edgecolors="none", s=40, c="#0d6efd")
            m, b = np.polyfit(x, y, 1)
            ax.plot(np.sort(x), m * np.sort(x) + b, color="#0d6efd", linewidth=2)
            ax.set_xlabel("X")
            ax.set_ylabel("Y")
            ax.set_title(f"{n} random points")
            ax.spines[["top", "right"]].set_visible(False)
            fig.tight_layout()
            return fig
    else:
        @render.text
        def stats():
            import random
            random.seed(42)
            n = input.n()
            vals = [random.gauss(0, 1) for _ in range(n)]
            mean_val = sum(vals) / n
            std_val = (sum((x - mean_val) ** 2 for x in vals) / n) ** 0.5
            return (
                f"Plot: {input.title()}\n"
                f"Points: {n}\n"
                f"Mean: {mean_val:.4f}\n"
                f"Std Dev: {std_val:.4f}"
            )


app = App(app_ui, server)
