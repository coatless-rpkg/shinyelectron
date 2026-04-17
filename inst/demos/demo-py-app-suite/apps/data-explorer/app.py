import random
import math
from shiny import App, reactive, render, ui

# Built-in datasets (no pandas/numpy dependency)
DATASETS = {
    "mtcars": {
        "columns": ["mpg", "cyl", "disp", "hp", "drat", "wt", "qsec", "vs", "am", "gear", "carb"],
        "rows": [
            [21.0, 6, 160.0, 110, 3.90, 2.620, 16.46, 0, 1, 4, 4],
            [21.0, 6, 160.0, 110, 3.90, 2.875, 17.02, 0, 1, 4, 4],
            [22.8, 4, 108.0, 93, 3.85, 2.320, 18.61, 1, 1, 4, 1],
            [21.4, 6, 258.0, 110, 3.08, 3.215, 19.44, 1, 0, 3, 1],
            [18.7, 8, 360.0, 175, 3.15, 3.440, 17.02, 0, 0, 3, 2],
            [18.1, 6, 225.0, 105, 2.76, 3.460, 20.22, 1, 0, 3, 1],
            [14.3, 8, 360.0, 245, 3.21, 3.570, 15.84, 0, 0, 3, 4],
            [24.4, 4, 146.7, 62, 3.69, 3.190, 20.00, 1, 0, 4, 2],
            [22.8, 4, 140.8, 95, 3.92, 3.150, 22.90, 1, 0, 4, 2],
            [19.2, 6, 167.6, 123, 3.92, 3.440, 18.30, 1, 0, 4, 4],
            [17.8, 6, 167.6, 123, 3.92, 3.440, 18.90, 1, 0, 4, 4],
            [16.4, 8, 275.8, 180, 3.07, 4.070, 17.40, 0, 0, 3, 3],
            [17.3, 8, 275.8, 180, 3.07, 3.730, 17.60, 0, 0, 3, 3],
            [15.2, 8, 275.8, 180, 3.07, 3.780, 18.00, 0, 0, 3, 3],
            [10.4, 8, 472.0, 205, 2.93, 5.250, 17.98, 0, 0, 3, 4],
            [10.4, 8, 460.0, 215, 3.00, 5.424, 17.82, 0, 0, 3, 4],
        ],
    },
    "iris": {
        "columns": ["sepal_length", "sepal_width", "petal_length", "petal_width", "species"],
        "rows": [
            [5.1, 3.5, 1.4, 0.2, "setosa"], [4.9, 3.0, 1.4, 0.2, "setosa"],
            [4.7, 3.2, 1.3, 0.2, "setosa"], [4.6, 3.1, 1.5, 0.2, "setosa"],
            [5.0, 3.6, 1.4, 0.2, "setosa"], [5.4, 3.9, 1.7, 0.4, "setosa"],
            [7.0, 3.2, 4.7, 1.4, "versicolor"], [6.4, 3.2, 4.5, 1.5, "versicolor"],
            [6.9, 3.1, 4.9, 1.5, "versicolor"], [5.5, 2.3, 4.0, 1.3, "versicolor"],
            [6.5, 2.8, 4.6, 1.5, "versicolor"], [5.7, 2.8, 4.5, 1.3, "versicolor"],
            [6.3, 3.3, 6.0, 2.5, "virginica"], [5.8, 2.7, 5.1, 1.9, "virginica"],
            [7.1, 3.0, 5.9, 2.1, "virginica"], [6.3, 2.9, 5.6, 1.8, "virginica"],
            [6.5, 3.0, 5.8, 2.2, "virginica"], [7.6, 3.0, 6.6, 2.1, "virginica"],
        ],
    },
    "faithful": {
        "columns": ["eruptions", "waiting"],
        "rows": [
            [3.600, 79], [1.800, 54], [3.333, 74], [2.283, 62], [4.533, 85],
            [2.883, 55], [4.700, 88], [3.600, 85], [1.950, 51], [4.350, 85],
            [1.833, 54], [3.917, 84], [4.200, 78], [1.750, 47], [4.700, 83],
            [2.167, 52], [1.750, 62], [4.800, 84], [1.600, 52], [4.250, 79],
        ],
    },
}


def _numeric_cols(ds):
    cols = DATASETS[ds]["columns"]
    rows = DATASETS[ds]["rows"]
    return [c for i, c in enumerate(cols) if all(isinstance(r[i], (int, float)) for r in rows)]


def _col_values(ds, col):
    idx = DATASETS[ds]["columns"].index(col)
    return [r[idx] for r in DATASETS[ds]["rows"]]


def _mean(vals):
    return sum(vals) / len(vals) if vals else 0


def _std(vals):
    m = _mean(vals)
    return math.sqrt(sum((x - m) ** 2 for x in vals) / len(vals)) if vals else 0


app_ui = ui.page_navbar(
    ui.nav_spacer(),
    ui.nav_panel(
        "Explore",
        ui.layout_sidebar(
            ui.sidebar(
                ui.input_select("dataset", "Dataset", list(DATASETS.keys())),
                ui.output_ui("x_select"),
                ui.output_ui("y_select"),
                width=240,
            ),
            ui.layout_columns(
                ui.value_box("Rows", ui.output_text("n_rows"), theme="primary"),
                ui.value_box("Columns", ui.output_text("n_cols"), theme="info"),
                ui.value_box("Numeric", ui.output_text("n_num"), theme="success"),
                col_widths=(4, 4, 4),
            ),
            ui.navset_card_underline(
                ui.nav_panel("Table", ui.output_data_frame("data_table")),
                ui.nav_panel("Summary", ui.output_text_verbatim("data_summary")),
            ),
        ),
    ),
    title="Data Explorer",
    id="navbar",
)


def server(input, output, session):
    @render.text
    def n_rows():
        return str(len(DATASETS[input.dataset()]["rows"]))

    @render.text
    def n_cols():
        return str(len(DATASETS[input.dataset()]["columns"]))

    @render.text
    def n_num():
        return str(len(_numeric_cols(input.dataset())))

    @render.ui
    def x_select():
        nums = _numeric_cols(input.dataset())
        return ui.input_select("xvar", "X axis", nums, selected=nums[0] if nums else None)

    @render.ui
    def y_select():
        nums = _numeric_cols(input.dataset())
        sel = nums[1] if len(nums) > 1 else (nums[0] if nums else None)
        return ui.input_select("yvar", "Y axis", nums, selected=sel)

    @render.data_frame
    def data_table():
        ds = DATASETS[input.dataset()]
        rows = [dict(zip(ds["columns"], r)) for r in ds["rows"]]
        return render.DataGrid(rows)

    @render.text
    def data_summary():
        ds = input.dataset()
        lines = []
        for col in _numeric_cols(ds):
            vals = _col_values(ds, col)
            lines.append(
                f"{col:>15s}  min={min(vals):.2f}  mean={_mean(vals):.2f}  "
                f"max={max(vals):.2f}  sd={_std(vals):.2f}"
            )
        return "\n".join(lines) if lines else "No numeric columns"


app = App(app_ui, server)
