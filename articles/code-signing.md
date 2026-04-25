# Code Signing and Distribution

Signing tells the operating system who built this. Notarization tells
the OS that Apple has seen it. Without either, macOS Gatekeeper blocks
your app as an “unidentified developer” and Windows SmartScreen warns on
every download. This guide covers what you need, what it costs, and how
to wire it up. For the wider security picture, see [Security
Considerations](https://r-pkg.thecoatlessprofessor.com/shinyelectron/articles/security.md).

![Four-stage horizontal flow diagram. Stage 1 is a blue Certificate card
noting the certificate is issued by a CA such as Apple, DigiCert,
Sectigo, GlobalSign, or a GPG key. A trusts arrow points to Stage 2, a
purple Signing card labeled export(sign = TRUE) where electron-builder
stamps the app and notarizes on macOS. A produces arrow points to Stage
3, a green Signed Build card containing a .app, .exe, or AppImage with
an embedded cryptographic signature. A verified-by arrow leads to Stage
4, an amber User OS card noting the operating system verifies and
launches the app cleanly. A platform strip below repeats the summary for
macOS, Windows, and Linux, with certificate type, representative cost,
the CSC_LINK or GPG_KEY environment variable, and what happens without
signing.](../reference/figures/signing-chain.svg)

The code signing chain of trust: a certificate from a trusted authority
signs the app during export, the signed build is distributed, and the
end user’s OS verifies the signature before launching. The bottom strip
summarises what each stage looks like on macOS, Windows, and Linux.

## When signing matters

Users can click past warnings, but the friction is real. Three reasons
to sign anyway:

- **Trust.** Non-technical users read “unidentified developer” as
  “malware” and leave.
- **Enterprise.** Many IT policies block anything unsigned outright.
- **Auto-updates.** `electron-updater` verifies signatures on macOS and
  Windows before applying an update, so unsigned builds lose the update
  path entirely.

The concrete outcomes differ per platform:

![Three-row comparison table showing what happens on launch without and
with signing on each platform. macOS row: without signing the app is
blocked by Gatekeeper with an error message that the app can't be opened
because Apple cannot check it for malicious software; with signing the
app opens cleanly after Apple verifies the Developer ID and notarization
ticket. Windows row: without signing SmartScreen warns that Windows
protected your PC and prevented the unrecognized app from starting; with
signing the app opens cleanly, with EV certificates trusted immediately
and OV certificates building reputation over weeks. Linux row: without
signing the app opens without any OS warning but users cannot verify the
artifact; with signing the GPG signature allows security-minded users to
verify authenticity
manually.](../reference/figures/signing-outcomes.svg)

Side-by-side comparison of launch behaviour with and without signing on
macOS, Windows, and Linux. macOS and Windows block or warn on unsigned
builds, while Linux has no OS-level enforcement but benefits from an
optional GPG signature.

|                  | macOS                       | Windows                       | Linux      |
|------------------|-----------------------------|-------------------------------|------------|
| **Required?**    | Strongly recommended        | Strongly recommended          | Optional   |
| **Cost**         | \$99/year (Apple Developer) | \$200 to \$700/year (CA cert) | Free (GPG) |
| **Certificate**  | Developer ID Application    | OV or EV code signing         | GPG key    |
| **Notarization** | Yes (macOS 10.15+)          | N/A                           | N/A        |

## Turning signing on

Pass `sign = TRUE` to
[`export()`](https://r-pkg.thecoatlessprofessor.com/shinyelectron/reference/export.md)
and electron-builder does the rest:

``` r
export(
  appdir = "my-app",
  destdir = "build",
  sign = TRUE
)
```

`sign = TRUE` tells electron-builder to use whatever credentials it
finds in the environment. It writes the signing configuration into
`package.json`, sets the macOS identity, enables notarization (when
configured), and points Windows at the certificate. It does **not**
create certificates. If the credentials are missing, it warns and hands
off to electron-builder, which then fails at the signing step with a
specific error.

The function argument overrides the config file.
`export(..., sign = TRUE)` signs even when `_shinyelectron.yml` says
`sign: false`. You can also enable signing purely through the config:

``` yaml
signing:
  sign: true
  mac:
    identity: "Developer ID Application: Your Name (TEAMID)"
    team_id: "XXXXXXXXXX"
    notarize: true
```

Credentials themselves (certificate password, Apple ID password, etc.)
must stay in environment variables. Never commit them to the config
file.

Before you kick off a full build, verify your setup with
[`app_check()`](https://r-pkg.thecoatlessprofessor.com/shinyelectron/reference/app_check.md):

``` r
app_check("my-app", sign = TRUE)
```

That catches missing certificates or environment variables cheaply,
without going through the full build.

## macOS: sign and notarize

**Cost:** \$99/year for Apple Developer Program membership, plus the
time to generate an app-specific password.

**What you need:**

1.  An **Apple Developer Program** membership at
    [developer.apple.com/programs](https://developer.apple.com/programs/).
2.  A **Developer ID Application certificate**. Not the same as a Mac
    App Store certificate. Create it in the Apple Developer portal under
    Certificates, Identifiers & Profiles.
3.  An **app-specific password** for notarization, generated at
    [appleid.apple.com/account/manage](https://appleid.apple.com/account/manage).

**Wiring it up.** Export the Developer ID Application certificate from
Keychain Access as a `.p12` file, then set these environment variables:

``` bash
# Certificate (path to .p12 file, or base64-encoded content)
export CSC_LINK="/path/to/certificate.p12"
export CSC_KEY_PASSWORD="your-certificate-password"

# Notarization credentials
export APPLE_ID="your@apple.id"
export APPLE_APP_SPECIFIC_PASSWORD="xxxx-xxxx-xxxx-xxxx"
export APPLE_TEAM_ID="XXXXXXXXXX"
```

Then run `export(..., sign = TRUE)`. electron-builder drives the full
signing and notarization flow. You do not call `codesign` or
`xcrun notarytool` yourself.

**Without signing:** Gatekeeper blocks the app on first launch with “App
can’t be opened because Apple cannot check it for malicious software.”
To open an unsigned `.app` during local development, strip the
quarantine flag:

``` bash
xattr -cr /path/to/YourApp.app
```

Or right-click the app in Finder and choose **Open** to bypass
Gatekeeper once.

## Windows: sign with a code signing certificate

**Cost:** \$200 to \$700/year depending on validation level. An EV
certificate builds SmartScreen trust immediately; an OV certificate
builds reputation over several weeks, during which users still see
warnings.

**What you need:** An OV or EV code signing certificate from a
commercial CA. Common options:

- [DigiCert](https://www.digicert.com/signing/code-signing-certificates)
- [Sectigo](https://www.sectigo.com/ssl-certificates-tls/code-signing)
- [GlobalSign](https://www.globalsign.com/en/code-signing-certificate)
- [SSL.com](https://www.ssl.com/certificates/code-signing/)

EV certificates ship on a hardware token (USB dongle or HSM) and require
a different signing workflow when used from CI; plan for that up front.

**Wiring it up.**

``` bash
export CSC_LINK="/path/to/certificate.pfx"
export CSC_KEY_PASSWORD="your-certificate-password"
```

Then:

``` r
export(
  appdir = "my-app",
  destdir = "build",
  platform = "win",
  sign = TRUE
)
```

**Without signing:** unsigned Windows installers trigger SmartScreen on
every download. There is no workaround short of signing the build.

## Linux: optional GPG signing

**Cost:** free. Uses a GPG key you already control.

**What you need:** a GPG key whose private half lives on the build
machine. Generate one with `gpg --full-generate-key` if you do not have
one, and publish the public key where your users can find it (your
website, a keyserver, or your GitHub profile).

**Wiring it up.**

``` bash
export GPG_KEY="your-gpg-key-id"
```

``` yaml
signing:
  sign: true
  linux:
    gpg_sign: true
```

**Without signing:** nothing visibly changes. AppImage files do not
require a signature to run, so most users never notice. Sign if your
audience includes security-minded users who want to verify authenticity
with `gpg --verify` before installing.

## Signing in CI

CI is where signing usually lives in the long run: no human holds the
keys on a laptop, and every tagged release is signed automatically.
Store credentials as GitHub Actions secrets (**Settings → Secrets and
variables → Actions**) and reference them from your workflow:

``` yaml
- name: Build Electron app
  env:
    # macOS
    CSC_LINK: ${{ secrets.MAC_CERTIFICATE }}
    CSC_KEY_PASSWORD: ${{ secrets.MAC_CERTIFICATE_PASSWORD }}
    APPLE_ID: ${{ secrets.APPLE_ID }}
    APPLE_APP_SPECIFIC_PASSWORD: ${{ secrets.APPLE_APP_SPECIFIC_PASSWORD }}
    APPLE_TEAM_ID: ${{ secrets.APPLE_TEAM_ID }}
    # Windows (set in the Windows job instead)
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
> macOS and Windows certificates use different files. `CSC_LINK` and
> `CSC_KEY_PASSWORD` must point at the right one for the runner. In a
> matrix build, set them per-platform in a conditional `env` block or
> split the build into separate jobs so each runner gets only its own
> credentials.

For the full workflow template (toolchain setup, matrix jobs, artifact
upload), see [Building with GitHub
Actions](https://r-pkg.thecoatlessprofessor.com/shinyelectron/articles/github-actions.md).

## Development versus production

A working rhythm:

1.  Develop and iterate locally with `sign = FALSE` (the default). Use
    `xattr -cr` on macOS when you need to launch your own unsigned
    build.
2.  Set up signing credentials once, per platform, in a secure vault or
    password manager.
3.  Flip `sign = TRUE` for release builds, either in the
    [`export()`](https://r-pkg.thecoatlessprofessor.com/shinyelectron/reference/export.md)
    call or through `signing: sign: true` in `_shinyelectron.yml`.
4.  Move signing into CI so human laptops never touch the keys.

|                         | Development                    | Production                                |
|-------------------------|--------------------------------|-------------------------------------------|
| **`sign`**              | `FALSE` (default)              | `TRUE`                                    |
| **Credentials needed?** | No                             | Yes                                       |
| **Build speed**         | Fast                           | Slower: notarization takes 1 to 5 minutes |
| **OS warnings?**        | Yes (use `xattr -cr` on macOS) | No                                        |

## Environment variables reference

One canonical table for every variable the signing pipeline reads.

| Variable                      | Platform       | Purpose                                                          |
|-------------------------------|----------------|------------------------------------------------------------------|
| `CSC_LINK`                    | macOS, Windows | Path to `.p12` or `.pfx` certificate (or base64-encoded content) |
| `CSC_KEY_PASSWORD`            | macOS, Windows | Password for the `.p12` or `.pfx` file                           |
| `APPLE_ID`                    | macOS          | Apple ID email used for notarization                             |
| `APPLE_APP_SPECIFIC_PASSWORD` | macOS          | App-specific password from `appleid.apple.com`                   |
| `APPLE_TEAM_ID`               | macOS          | 10-character Apple Developer Team ID                             |
| `GPG_KEY`                     | Linux          | GPG key ID for AppImage signing                                  |

## Next steps

- **[GitHub
  Actions](https://r-pkg.thecoatlessprofessor.com/shinyelectron/articles/github-actions.md)**:
  automate signed builds across platform runners.
- **[Auto
  Updates](https://r-pkg.thecoatlessprofessor.com/shinyelectron/articles/auto-updates.md)**:
  electron-updater requires signed builds on macOS and Windows.
- **[Configuration
  Guide](https://r-pkg.thecoatlessprofessor.com/shinyelectron/articles/configuration.md)**:
  the full `_shinyelectron.yml` reference, signing included.
