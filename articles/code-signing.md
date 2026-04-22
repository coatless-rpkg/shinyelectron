# Code Signing and Distribution

Without code signing, macOS Gatekeeper blocks your app (“unidentified
developer”) and Windows SmartScreen warns on every download
(“unrecognized app”). This guide covers what you need, what it costs,
and how to set it up. For broader Electron security topics, see
[Security
Considerations](https://r-pkg.thecoatlessprofessor.com/shinyelectron/articles/security.md).

## Why Code Signing Matters

Unsigned apps still work once users bypass the warning, but signing
matters for:

- **User trust**: Security warnings scare non-technical users away.
- **Enterprise deployment**: Many organizations block unsigned software
  via policy.
- **Auto-updates**: macOS and Windows require signed builds for
  electron-updater to verify update integrity.

|                  | macOS                       | Windows                    | Linux      |
|------------------|-----------------------------|----------------------------|------------|
| **Required?**    | Strongly recommended        | Strongly recommended       | Optional   |
| **Cost**         | \$99/year (Apple Developer) | \$200–\$700/year (CA cert) | Free (GPG) |
| **Certificate**  | Developer ID Application    | OV or EV code signing      | GPG key    |
| **Notarization** | Yes (macOS 10.15+)          | N/A                        | N/A        |

## macOS: Code Signing and Notarization

### What You Need

1.  **Apple Developer Program membership** (\$99/year) at
    [developer.apple.com](https://developer.apple.com/programs/)
2.  **Developer ID Application certificate** — this is different from a
    Mac App Store certificate. Create one in the Apple Developer portal
    under Certificates, Identifiers & Profiles.
3.  **App-specific password** for notarization (generated at
    [appleid.apple.com](https://appleid.apple.com/account/manage))

### Setup

Export your Developer ID Application certificate as a `.p12` file from
Keychain Access, then set these environment variables:

``` bash
# Certificate (path to .p12 file, or base64-encoded content)
export CSC_LINK="/path/to/certificate.p12"
export CSC_KEY_PASSWORD="your-certificate-password"

# Notarization credentials
export APPLE_ID="your@apple.id"
export APPLE_APP_SPECIFIC_PASSWORD="xxxx-xxxx-xxxx-xxxx"
export APPLE_TEAM_ID="XXXXXXXXXX"
```

Then export your app with signing enabled:

``` r
export(
  appdir = "my-app",
  destdir = "build",
  sign = TRUE
)
```

electron-builder handles the entire signing and notarization flow
automatically when these environment variables are present. You do not
need to run `codesign` or `xcrun notarytool` yourself.

You can also configure signing behavior in `_shinyelectron.yml`
(credentials should still come from environment variables):

``` yaml
signing:
  sign: true
  mac:
    identity: "Developer ID Application: Your Name (TEAMID)"
    team_id: "XXXXXXXXXX"
    notarize: true
```

To open an unsigned `.app` on macOS during development, clear the
quarantine attribute (`xattr -cr /path/to/YourApp.app`) or right-click
and choose **Open**.

## Windows: Code Signing

### What You Need

An OV or EV code signing certificate from a CA (DigiCert, Sectigo,
GlobalSign, SSL.com). EV certificates (~\$300–\$700/year) provide
immediate SmartScreen trust. OV certificates (~\$200–\$500/year) build
reputation gradually — users may still see warnings for the first few
weeks.

### Setup

``` bash
# Path to your .pfx certificate file (or base64-encoded content)
export CSC_LINK="/path/to/certificate.pfx"
export CSC_KEY_PASSWORD="your-certificate-password"
```

Then build with signing:

``` r
export(
  appdir = "my-app",
  destdir = "build",
  platform = "win",
  sign = TRUE
)
```

Unsigned Windows builds trigger SmartScreen on every download with no
workaround.

## Linux: Optional GPG Signing

Linux distributions do not enforce code signing for desktop apps.
However, AppImage files can be GPG-signed so users can verify
authenticity.

### Setup

``` bash
export GPG_KEY="your-gpg-key-id"
```

``` yaml
signing:
  sign: true
  linux:
    gpg_sign: true
```

This is optional and only matters if your users explicitly verify
signatures.

## The `sign` Parameter

`export(..., sign = TRUE)` tells electron-builder to sign using
available credentials. It passes signing configuration to
`package.json`, sets the macOS identity, enables notarization (if
configured), and includes the Windows certificate path. It does **not**
create certificates or error on missing credentials — it warns, then
electron-builder proceeds (and may fail at the signing step).

The function parameter overrides the config file:
`export(..., sign = TRUE)` enables signing even if `_shinyelectron.yml`
says `sign: false`. You can also enable signing solely via config
(`signing: sign: true`).

Use `app_check("my-app", sign = TRUE)` to verify your signing setup
before building.

## Using with GitHub Actions

Store credentials as GitHub Actions secrets (**Settings \> Secrets and
variables \> Actions**), then reference them in your workflow.

| Secret Name                   | Value                                             |
|-------------------------------|---------------------------------------------------|
| `MAC_CERTIFICATE`             | Base64-encoded `.p12` file (`base64 -i cert.p12`) |
| `MAC_CERTIFICATE_PASSWORD`    | Password for the `.p12` file                      |
| `APPLE_ID`                    | Your Apple ID email                               |
| `APPLE_APP_SPECIFIC_PASSWORD` | App-specific password from appleid.apple.com      |
| `APPLE_TEAM_ID`               | 10-character team ID from developer.apple.com     |
| `WIN_CERTIFICATE`             | Base64-encoded `.pfx` file                        |
| `WIN_CERTIFICATE_PASSWORD`    | Password for the `.pfx` file                      |

Reference secrets in your workflow:

``` yaml
- name: Build Electron app
  env:
    # macOS
    CSC_LINK: ${{ secrets.MAC_CERTIFICATE }}
    CSC_KEY_PASSWORD: ${{ secrets.MAC_CERTIFICATE_PASSWORD }}
    APPLE_ID: ${{ secrets.APPLE_ID }}
    APPLE_APP_SPECIFIC_PASSWORD: ${{ secrets.APPLE_APP_SPECIFIC_PASSWORD }}
    APPLE_TEAM_ID: ${{ secrets.APPLE_TEAM_ID }}
    # Windows
    # CSC_LINK: ${{ secrets.WIN_CERTIFICATE }}
    # CSC_KEY_PASSWORD: ${{ secrets.WIN_CERTIFICATE_PASSWORD }}
  run: |
    Rscript -e "
      shinyelectron::export(
        appdir = 'app',
        destdir = 'build',
        sign = TRUE
      )
    "
```

> **Important**
>
> macOS and Windows use different certificates, so `CSC_LINK` and
> `CSC_KEY_PASSWORD` must point to the correct certificate for each
> platform. In a matrix build, set these per-platform using conditional
> env blocks or separate build steps.

For a complete workflow template, see [GitHub
Actions](https://r-pkg.thecoatlessprofessor.com/shinyelectron/articles/github-actions.md).

## Development vs. Production

|                         | Development                    | Production                              |
|-------------------------|--------------------------------|-----------------------------------------|
| **`sign`**              | `FALSE` (default)              | `TRUE`                                  |
| **Credentials needed?** | No                             | Yes                                     |
| **Build speed**         | Fast                           | Slower (notarization takes 1–5 minutes) |
| **OS warnings?**        | Yes (use `xattr -cr` on macOS) | No                                      |

A typical workflow:

1.  Develop and test with `sign = FALSE`
2.  Set up signing credentials once
3.  Use `sign = TRUE` (or `signing: sign: true` in config) for release
    builds
4.  Automate signed builds with GitHub Actions

## Quick Reference

| Environment Variable          | Platform       | Purpose                                       |
|-------------------------------|----------------|-----------------------------------------------|
| `CSC_LINK`                    | macOS, Windows | Path to `.p12`/`.pfx` certificate (or base64) |
| `CSC_KEY_PASSWORD`            | macOS, Windows | Certificate password                          |
| `APPLE_ID`                    | macOS          | Apple ID for notarization                     |
| `APPLE_APP_SPECIFIC_PASSWORD` | macOS          | App-specific password for notarization        |
| `APPLE_TEAM_ID`               | macOS          | 10-character Apple Developer Team ID          |
| `GPG_KEY`                     | Linux          | GPG key ID for AppImage signing               |

## Next Steps

- **[GitHub
  Actions](https://r-pkg.thecoatlessprofessor.com/shinyelectron/articles/github-actions.md)**:
  Automate signed builds in CI/CD
- **[Auto
  Updates](https://r-pkg.thecoatlessprofessor.com/shinyelectron/articles/auto-updates.md)**:
  Signed builds are required for auto-updates on macOS and Windows
- **[Configuration](https://r-pkg.thecoatlessprofessor.com/shinyelectron/articles/configuration.md)**:
  Full `_shinyelectron.yml` reference including signing options
