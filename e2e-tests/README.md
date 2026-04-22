# shinyelectron End-to-End Tests

Playwright-based end-to-end tests for the shinyelectron Electron app, covering all app types and runtime strategies.

## Prerequisites

- Node.js >= 18
- R >= 4.4.0 with the shinyelectron package (loaded via `devtools::load_all()`)
- Strategy-specific requirements (see table below)

## Setup

```bash
cd e2e-tests
npm install
```

## Running Tests

```bash
# Run ALL tests (all app types + strategies — takes 30+ min)
npm test

# Run only fast tests (r-shiny system, ~2 min)
npm run test:fast

# Individual test suites
npm run test:single         # r-shiny system: single app
npm run test:multi          # r-shiny system: multi-app launcher
npm run test:error          # r-shiny system: crash/error recovery
npm run test:r-shinylive    # r-shinylive: WebR in browser
npm run test:py-shinylive   # py-shinylive: Pyodide in browser
npm run test:py-system      # py-shiny system: native Python
npm run test:r-bundled      # r-shiny bundled: embedded portable R
npm run test:r-autodownload # r-shiny auto-download: first-launch download
npm run test:r-container    # r-shiny container: Docker/Podman
```

## Coverage Matrix

| Test File | App Type | Strategy | Prerequisites | Time |
|-----------|----------|----------|---------------|------|
| `single-app.spec.js` | r-shiny | system | R + shiny | ~1 min |
| `multi-app-launcher.spec.js` | r-shiny | system | R + shiny | ~1 min |
| `error-recovery.spec.js` | r-shiny | system | R | ~5 min |
| `r-shinylive.spec.js` | r-shinylive | shinylive | R + shinylive pkg | ~3 min |
| `py-shinylive.spec.js` | py-shinylive | shinylive | Python + shinylive | ~3 min |
| `py-shiny-system.spec.js` | py-shiny | system | Python + shiny | ~2 min |
| `r-shiny-bundled.spec.js` | r-shiny | bundled | R (downloads portable R) | ~10 min |
| `r-shiny-auto-download.spec.js` | r-shiny | auto-download | R + network | ~5 min |
| `r-shiny-container.spec.js` | r-shiny | container | R + Docker | ~10 min |

## How It Works

1. `beforeAll` calls `buildApp()` which runs `shinyelectron::export()` via `Rscript` to build a real Electron app in a temp directory
2. `beforeEach` launches the built app with Playwright's Electron support
3. Tests interact with the app windows (click buttons, fill inputs, check text)
4. `afterAll` cleans up temp directories

## Test Helpers

| Function | Description |
|----------|-------------|
| `buildApp({ appdir, destdir, app_type, runtime_strategy })` | Build an Electron app from a Shiny app directory |
| `launchApp(electronDir)` | Launch the built Electron app with Playwright |
| `createTestApp(dir, rCode)` | Create a temp R Shiny app with given code |
| `createPythonTestApp(dir, pyCode)` | Create a temp Python Shiny app with given code |
| `createMultiAppProject(dir, apps)` | Create a multi-app project with YAML config |

## Notes

- The `beforeAll` build step downloads dependencies and can take minutes per test file
- Bundled and auto-download tests download ~200MB portable R on first run
- Container tests require Docker Desktop running
- Shinylive tests require the `shinylive` R/Python package
- Tests use extended timeouts (up to 10 min) for slow strategies
- Each test in a file gets a fresh Electron launch but shares the same build
