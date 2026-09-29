# Normalize the app author

`app.author` takes either form npm uses for a person: a string
`"Name <email> (url)"`, where each part is optional, or a map with
`name`, `email`, and `url` entries. Both become the same list, which
fills the `author` field of `package.json` and the About dialog. The
string is split the way npm and electron-builder split it.

## Usage

``` r
normalize_app_author(x)
```

## Arguments

- x:

  The `app.author` setting.

## Value

A list with `name`, `email`, and `url` entries, each a string or `NULL`,
or `NULL` when `x` is unset or blank. Any other shape warns and returns
`NULL`.
