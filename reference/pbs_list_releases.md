# List python-build-standalone releases from GitHub

Fetches release metadata from the astral-sh/python-build-standalone
GitHub API. Returns a list of release objects, each with a `tag_name`
field and an `assets` list whose elements have a `name` field. Releases
are ordered newest first (GitHub API default). This function is
intentionally a thin network wrapper so it can be stubbed in tests.

## Usage

``` r
pbs_list_releases()
```

## Value

List of release objects from the GitHub releases API.
