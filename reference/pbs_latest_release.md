# Fetch the latest python-build-standalone release from GitHub

Queries the single `releases/latest` endpoint. This is a small, reliable
call, unlike the full release list which is large enough to time out
(HTTP 504) on this repository. The latest release carries the newest
patch of every currently supported CPython minor, so it resolves
`"latest"` and any current version on its own. A thin network wrapper so
tests can stub it.

## Usage

``` r
pbs_latest_release()
```

## Value

A single release object with a `tag_name` field and an `assets` list.
