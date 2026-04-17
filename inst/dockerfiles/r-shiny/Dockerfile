# Minimal R + Shiny image for shinyelectron container strategy
# Uses rocker/r2u which provides pre-built binary R packages via apt
# Supports both amd64 and arm64 (Apple Silicon)
FROM rocker/r2u:24.04

# Install R packages as system packages — pre-compiled, no source compilation
# This works on both amd64 and arm64
RUN apt-get update && apt-get install -y --no-install-recommends \
    r-cran-shiny \
    r-cran-jsonlite \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /app

COPY entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh

EXPOSE 3838

ENTRYPOINT ["/entrypoint.sh"]
