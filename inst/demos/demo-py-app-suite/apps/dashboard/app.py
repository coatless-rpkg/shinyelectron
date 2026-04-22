import random
from datetime import datetime

from shiny import App, reactive, render, ui

try:
    import numpy as np
    import matplotlib
    matplotlib.use("Agg")
    import matplotlib.pyplot as plt
    HAS_PLOT = True
except ImportError:
    HAS_PLOT = False


app_ui = ui.page_navbar(
    ui.nav_spacer(),
    ui.nav_panel(
        "Overview",
        ui.layout_columns(
            ui.value_box("Active Users", ui.output_text("v_users"), theme="primary"),
            ui.value_box("Revenue", ui.output_text("v_revenue"), theme="success"),
            ui.value_box("Sessions", ui.output_text("v_sessions"), theme="info"),
            ui.value_box("Conversion", ui.output_text("v_conv"), theme="warning"),
            col_widths=(3, 3, 3, 3),
        ),
        ui.layout_columns(
            ui.card(
                ui.card_header("Trend"),
                ui.input_slider("days", "Time range (days)", min=7, max=90, value=30),
                ui.input_select(
                    "metric", "Metric",
                    {"revenue": "Revenue", "users": "Users", "sessions": "Sessions"},
                ),
                ui.output_plot("trend") if HAS_PLOT else ui.output_text_verbatim("trend_text"),
                full_screen=True,
            ),
            ui.card(
                ui.card_header("Breakdown"),
                ui.output_plot("breakdown") if HAS_PLOT else ui.output_text_verbatim("breakdown_text"),
                full_screen=True,
            ),
            col_widths=(8, 4),
        ),
    ),
    title="Dashboard",
    id="navbar",
)


def server(input, output, session):
    @render.text
    def v_users():
        reactive.invalidate_later(5)
        return f"{random.randint(180, 450):,}"

    @render.text
    def v_revenue():
        reactive.invalidate_later(5)
        return f"${random.randint(12000, 48000):,}"

    @render.text
    def v_sessions():
        reactive.invalidate_later(5)
        return f"{random.randint(2000, 8000):,}"

    @render.text
    def v_conv():
        reactive.invalidate_later(5)
        return f"{random.randint(25, 45)}%"

    if HAS_PLOT:
        @render.plot
        def trend():
            n = input.days()
            np.random.seed(42 + n)
            base = {"revenue": 5000, "users": 200, "sessions": 800}.get(input.metric(), 800)
            vals = np.cumsum(np.random.randn(n) * base / (n * 2.5) + base / n)

            fig, ax = plt.subplots(figsize=(8, 3.5))
            ax.fill_between(range(n), vals, alpha=0.12, color="#0d6efd")
            ax.plot(vals, color="#0d6efd", linewidth=2.5)
            ax.plot(n - 1, vals[-1], "o", color="#0d6efd", markersize=8)
            ax.set_xlabel("Day")
            ax.set_ylabel(input.metric().title())
            ax.spines[["top", "right"]].set_visible(False)
            fig.tight_layout()
            return fig

        @render.plot
        def breakdown():
            np.random.seed(99)
            cats = ["Organic", "Paid", "Referral", "Direct", "Social"]
            vals = sorted(np.random.randint(50, 300, 5), reverse=True)
            colors = ["#0d6efd", "#198754", "#0dcaf0", "#ffc107", "#dc3545"]

            fig, ax = plt.subplots(figsize=(4, 3.5))
            ax.barh(cats, vals, color=[c + "99" for c in colors], edgecolor="none")
            for i, v in enumerate(vals):
                ax.text(v + 5, i, str(v), va="center", fontsize=9)
            ax.invert_yaxis()
            ax.spines[["top", "right", "bottom"]].set_visible(False)
            ax.tick_params(bottom=False, labelbottom=False)
            fig.tight_layout()
            return fig
    else:
        @render.text
        def trend_text():
            n = input.days()
            random.seed(42 + n)
            vals = [random.gauss(100, 20) for _ in range(n)]
            return f"Metric: {input.metric()}\nDays: {n}\nMean: {sum(vals)/n:.1f}\nMax: {max(vals):.1f}"

        @render.text
        def breakdown_text():
            cats = ["Organic", "Paid", "Referral", "Direct", "Social"]
            random.seed(99)
            return "\n".join(f"{c}: {random.randint(50, 300)}" for c in cats)


app = App(app_ui, server)
