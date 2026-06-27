# R + Shiny image for the shinyelectron container strategy.
# rocker/r-ver pins an exact R version and pre-wires P3M binaries, so
# install.packages() pulls precompiled binaries. System libraries those
# binaries need are baked in by the build (via the Posit Package Manager
# system-requirements API).
ARG R_VERSION=latest
FROM rocker/r-ver:${R_VERSION}

ENV DEBIAN_FRONTEND=noninteractive

RUN R -e "install.packages('shiny')"

WORKDIR /app

COPY entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh

EXPOSE 3838

ENTRYPOINT ["/entrypoint.sh"]
