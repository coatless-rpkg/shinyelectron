# Resolve the app slug

The slug is the app's identity. It names the package in `package.json`,
the user data folder, the per-app caches under `~/.shinyelectron`, and
the installer files, and unless `installer.app_id` is set it also gives
the app ID, which Windows installers and macOS use to recognize an
installed copy. `app.slug` wins when set. Otherwise the slug comes from
`name`, and then from the name of the app directory: when `name` is
`NULL`, or, with a message, when it has no ASCII letters or digits.

## Usage

``` r
resolve_app_slug(config, name, appdir)
```

## Arguments

- config:

  List. The effective configuration.

- name:

  Character string or `NULL`. The name the slug comes from when
  `app.slug` is unset, such as the `app_name` argument of
  [`export()`](https://r-pkg.thecoatlessprofessor.com/shinyelectron/reference/export.md).

- appdir:

  Character string. The app directory.

## Value

The slug, or `NULL` when neither `name` nor the directory gives one. It
is not validated here;
[`check_app_slug()`](https://r-pkg.thecoatlessprofessor.com/shinyelectron/reference/check_app_slug.md)
does that before a build.

## Details

[`export()`](https://r-pkg.thecoatlessprofessor.com/shinyelectron/reference/export.md)
passes its `app_name` argument as `name`, so `app.name` in the
configuration sets only the display name and never the slug, as in
earlier releases: editing the display name never changes the app's
identity.
