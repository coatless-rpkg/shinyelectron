# Package index

## Export & Build

Main functions for exporting Shiny apps as Electron desktop applications

- [`export()`](https://r-pkg.thecoatlessprofessor.com/shinyelectron/reference/export.md)
  : Export Shiny Application as Electron Desktop Application
- [`build_electron_app()`](https://r-pkg.thecoatlessprofessor.com/shinyelectron/reference/build_electron_app.md)
  : Build Electron Application
- [`run_electron_app()`](https://r-pkg.thecoatlessprofessor.com/shinyelectron/reference/run_electron_app.md)
  : Run Electron Application for Testing

## Conversion

Convert Shiny apps to shinylive format

- [`convert_shiny_to_shinylive()`](https://r-pkg.thecoatlessprofessor.com/shinyelectron/reference/convert_shiny_to_shinylive.md)
  : Convert Shiny Application to Shinylive
- [`convert_py_to_shinylive()`](https://r-pkg.thecoatlessprofessor.com/shinyelectron/reference/convert_py_to_shinylive.md)
  : Convert Python Shiny Application to Shinylive

## Runtime Management

Install and manage R, Python, and Node.js runtimes

- [`install_r()`](https://r-pkg.thecoatlessprofessor.com/shinyelectron/reference/install_r.md)
  : Install a portable R distribution
- [`install_python()`](https://r-pkg.thecoatlessprofessor.com/shinyelectron/reference/install_python.md)
  : Install a portable Python distribution
- [`install_nodejs()`](https://r-pkg.thecoatlessprofessor.com/shinyelectron/reference/install_nodejs.md)
  : Install Node.js locally

## Configuration

Configure shinyelectron projects

- [`init_config()`](https://r-pkg.thecoatlessprofessor.com/shinyelectron/reference/init_config.md)
  : Initialize configuration file
- [`show_config()`](https://r-pkg.thecoatlessprofessor.com/shinyelectron/reference/show_config.md)
  : Show Effective Configuration
- [`wizard()`](https://r-pkg.thecoatlessprofessor.com/shinyelectron/reference/wizard.md)
  : Interactive Configuration Wizard
- [`enable_auto_updates()`](https://r-pkg.thecoatlessprofessor.com/shinyelectron/reference/enable_auto_updates.md)
  : Enable Auto-Updates
- [`disable_auto_updates()`](https://r-pkg.thecoatlessprofessor.com/shinyelectron/reference/disable_auto_updates.md)
  : Disable Auto-Updates
- [`check_auto_update_status()`](https://r-pkg.thecoatlessprofessor.com/shinyelectron/reference/check_auto_update_status.md)
  : Check Auto-Update Status

## Developer Tools

Pre-flight checks, examples, and diagnostics

- [`app_check()`](https://r-pkg.thecoatlessprofessor.com/shinyelectron/reference/app_check.md)
  : Check Shiny Application Readiness for Export
- [`available_examples()`](https://r-pkg.thecoatlessprofessor.com/shinyelectron/reference/available_examples.md)
  : List Available Examples
- [`example_app()`](https://r-pkg.thecoatlessprofessor.com/shinyelectron/reference/example_app.md)
  : Get Path to an Example Application

## Diagnostics

Check system requirements and troubleshoot issues

- [`sitrep_shinyelectron()`](https://r-pkg.thecoatlessprofessor.com/shinyelectron/reference/sitrep_shinyelectron.md)
  : Complete Situation Report
- [`sitrep_electron_system()`](https://r-pkg.thecoatlessprofessor.com/shinyelectron/reference/sitrep_electron_system.md)
  : System Requirements Situation Report
- [`sitrep_electron_dependencies()`](https://r-pkg.thecoatlessprofessor.com/shinyelectron/reference/sitrep_electron_dependencies.md)
  : Dependencies Situation Report
- [`sitrep_electron_build_tools()`](https://r-pkg.thecoatlessprofessor.com/shinyelectron/reference/sitrep_electron_build_tools.md)
  : Build Tools Situation Report
- [`sitrep_electron_project()`](https://r-pkg.thecoatlessprofessor.com/shinyelectron/reference/sitrep_electron_project.md)
  : Project Situation Report

## Cache Management

Inspect, manage, and clear cached runtimes and assets

- [`cache_info()`](https://r-pkg.thecoatlessprofessor.com/shinyelectron/reference/cache_info.md)
  : Show cached runtime information
- [`cache_dir()`](https://r-pkg.thecoatlessprofessor.com/shinyelectron/reference/cache_dir.md)
  : Get or create the cache directory path
- [`cache_remove()`](https://r-pkg.thecoatlessprofessor.com/shinyelectron/reference/cache_remove.md)
  : Remove a specific cached runtime version
- [`cache_clear()`](https://r-pkg.thecoatlessprofessor.com/shinyelectron/reference/cache_clear.md)
  : Clear the asset cache
