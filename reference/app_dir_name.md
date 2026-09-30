# Name of the app directory

The last part of the directory's absolute path, where
[`base::basename()`](https://rdrr.io/r/base/basename.html) gives `"."`
or `".."` for a path such as `"."` or `"app/.."`. The path is made
absolute from its text alone, without resolving symbolic links: a link
named in `appdir` keeps the link's name, and `"link/.."` gives the name
of the folder that holds the link, not of the parent of its target. A
relative path starts from the working directory that
[`base::getwd()`](https://rdrr.io/r/base/getwd.html) reports, which on
macOS and Linux has its links resolved, so `"."` in a linked directory
gives the name of the folder the link points to.

## Usage

``` r
app_dir_name(appdir)
```

## Arguments

- appdir:

  Character string. Path to the app directory.

## Value

Character string. The directory's name.
