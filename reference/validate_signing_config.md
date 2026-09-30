# Validate code signing configuration

Checks that required credentials are available when signing is enabled.
Issues warnings (not errors) for missing credentials so the build can
continue – electron-builder will handle the actual failure.

## Usage

``` r
validate_signing_config(
  config,
  platform = NULL,
  sign = isTRUE(config$signing$sign)
)
```

## Arguments

- config:

  List. The effective configuration.

- platform:

  Character string. Target platform ("mac", "win", "linux").

- sign:

  Logical. Whether the build is signed.
  [`export()`](https://r-pkg.thecoatlessprofessor.com/shinyelectron/reference/export.md)
  and
  [`app_check()`](https://r-pkg.thecoatlessprofessor.com/shinyelectron/reference/app_check.md)
  pass the value their `sign` argument resolves to, which can turn
  signing on when `signing.sign` is off. Defaults to `signing.sign`.

## Details

On macOS, electron-builder notarizes with the first kind of credentials
it finds in the environment: an Apple ID (`APPLE_ID` and
`APPLE_APP_SPECIFIC_PASSWORD`, plus a team ID from `APPLE_TEAM_ID` or
`signing.mac.team_id`), an App Store Connect API key (`APPLE_API_KEY`,
`APPLE_API_KEY_ID` and `APPLE_API_ISSUER`), or a `notarytool` keychain
profile (`APPLE_KEYCHAIN_PROFILE`).
