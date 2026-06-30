#' Installer extension for a platform
#'
#' The shinyelectron electron-builder template targets `dmg` on macOS, `nsis`
#' (an `.exe`) on Windows, and `AppImage` on Linux.
#'
#' @param platform Character vector of `"mac"`, `"win"`, or `"linux"`.
#' @return Character vector of file extensions.
#' @keywords internal
ext_for <- function(platform) {
  unname(c(mac = "dmg", win = "exe", linux = "AppImage")[platform])
}

#' Valid demo build matrix
#'
#' Enumerates every (demo, strategy, platform, arch) combination the demo build
#' workflow produces, after applying validity rules. The CI workflow and the
#' download tables in the README and the download-demos article all read this,
#' so the build matrix and the published links cannot drift.
#'
#' @return A data frame with one row per valid combination and columns `demo`,
#'   `name`, `language`, `strategy`, `platform`, `arch`, `runner`,
#'   `asset_name`, `requirement`.
#' @keywords internal
demo_release_matrix <- function() {
  demos <- data.frame(
    demo = c("demo-single", "demo-py-single", "demo-r-app-suite", "demo-py-app-suite"),
    name = c("R single app", "Python single app", "R demo suite", "Python demo suite"),
    language = c("r", "py", "r", "py"),
    stringsAsFactors = FALSE
  )
  strategies <- c("shinylive", "bundled", "system", "auto-download", "container")
  targets <- data.frame(
    platform = c("mac", "mac", "win", "linux"),
    arch = c("arm64", "x64", "x64", "x64"),
    runner = c("macos-latest", "macos-15-intel", "windows-latest", "ubuntu-latest"),
    stringsAsFactors = FALSE
  )
  requirement <- c(
    "shinylive" = "none",
    "bundled" = "none",
    "system" = "R or Python installed",
    "auto-download" = "internet on first launch",
    "container" = "Docker or Podman"
  )
  # Per-(demo, strategy, platform) exclusions for combinations that do not build
  # reliably. Empty by default; add rows of (demo, strategy, platform) here when
  # a combination proves incompatible.
  exclusions <- data.frame(
    demo = character(0), strategy = character(0), platform = character(0),
    stringsAsFactors = FALSE
  )

  combos <- expand.grid(
    demo_i = seq_len(nrow(demos)),
    strategy = strategies,
    target_i = seq_len(nrow(targets)),
    KEEP.OUT.ATTRS = FALSE, stringsAsFactors = FALSE
  )
  out <- data.frame(
    demo = demos$demo[combos$demo_i],
    name = demos$name[combos$demo_i],
    language = demos$language[combos$demo_i],
    strategy = combos$strategy,
    platform = targets$platform[combos$target_i],
    arch = targets$arch[combos$target_i],
    runner = targets$runner[combos$target_i],
    stringsAsFactors = FALSE
  )

  # Rule: bundled and auto-download for R have no Linux build (no portable R).
  drop <- out$strategy %in% c("bundled", "auto-download") &
    out$language == "r" & out$platform == "linux"
  out <- out[!drop, ]

  if (nrow(exclusions) > 0) {
    out <- out[!paste(out$demo, out$strategy, out$platform) %in%
                 paste(exclusions$demo, exclusions$strategy, exclusions$platform), ]
  }

  out$asset_name <- sprintf(
    "%s-%s-%s-%s.%s", out$demo, out$strategy, out$platform, out$arch,
    ext_for(out$platform)
  )
  out$requirement <- unname(requirement[out$strategy])
  out <- out[order(out$demo, out$strategy, out$platform, out$arch), ]
  rownames(out) <- NULL
  out
}
