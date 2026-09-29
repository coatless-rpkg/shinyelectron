# Serialize a value as JSON to inline in a script

JSON from
[`jsonlite::toJSON()`](https://jeroen.r-universe.dev/jsonlite/reference/fromJSON.html)
is a valid JavaScript expression, but a string in it that contains
`<!--` followed by `<script` can stop the HTML parser from ending the
surrounding `<script>` block at its closing tag. This writes every `<`
as `\u003C`, and U+2028 and U+2029 as escape sequences, so the JSON
stays valid and keeps its value. Templates use it for every JSON value
they inline into script code, such as `var apps = {{{apps_json}}};` in
`launcher.html` and the backend config in `main.js`.

## Usage

``` r
json_for_script(x)
```

## Arguments

- x:

  Value to serialize (with `auto_unbox = TRUE`).

## Value

A single string of JSON.
