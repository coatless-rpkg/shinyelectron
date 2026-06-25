# Minimal R + Shiny image for shinyelectron container strategy
# Uses rocker/r2u which provides pre-built binary R packages via apt
# Supports both amd64 and arm64 (Apple Silicon)
FROM rocker/r2u:24.04

# Install Shiny and its runtime dependencies as pre-built system packages.
# r-cran-shiny's apt Depends can lag shiny's actual R imports on bleeding-edge
# r2u, so the transitive deps (R6, httpuv, later, ...) are listed explicitly
# to guarantee shiny can load. Works on both amd64 and arm64.
RUN apt-get update && apt-get install -y --no-install-recommends \
    r-cran-shiny \
    r-cran-jsonlite \
    r-cran-r6 \
    r-cran-httpuv \
    r-cran-later \
    r-cran-promises \
    r-cran-htmltools \
    r-cran-fastmap \
    r-cran-rlang \
    r-cran-mime \
    r-cran-fontawesome \
    r-cran-bslib \
    r-cran-cachem \
    r-cran-commonmark \
    r-cran-glue \
    r-cran-crayon \
    r-cran-lifecycle \
    r-cran-digest \
    r-cran-sass \
    r-cran-jquerylib \
    r-cran-memoise \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /app

COPY entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh

EXPOSE 3838

ENTRYPOINT ["/entrypoint.sh"]
