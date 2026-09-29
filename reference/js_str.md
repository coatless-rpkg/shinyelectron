# Escape a value for a single-quoted JavaScript string literal

Rendered templates place configuration strings between single quotes in
JavaScript, both in `main.js` and in the inline `<script>` of
`lifecycle.html`, as in `title: 'Close {{{app_name_js}}}'`. This escapes
backslashes and then single quotes, turns carriage returns and line
feeds into spaces, and writes U+2028, U+2029, and every `<` as escape
sequences (`<` becomes `\u003C`). No value can then end the literal
early, change its meaning (a Windows path keeps its backslashes), or end
or disturb an HTML `<script>` block. Double quotes are left alone, so
use the result only inside single quotes.

## Usage

``` r
js_str(x)
```

## Arguments

- x:

  A character vector, a non-character scalar (coerced with
  [`as.character()`](https://rdrr.io/r/base/character.html), such as a
  version that YAML read as a number), or `NULL`.

## Value

A character vector, or `NULL` when `x` is `NULL`.

## Details

Render the result with a triple mustache (`{{{name_js}}}`). A double
mustache would HTML-escape it again and turn `&` into `&amp;`. HTML
markup, such as the page title in `lifecycle.html`, keeps the double
mustache.
