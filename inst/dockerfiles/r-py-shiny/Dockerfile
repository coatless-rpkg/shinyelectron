# R + Python Shiny image for shinyelectron container strategy
FROM rocker/r-base:latest

# Keep apt non-interactive so a conffile prompt from an updated base package
# cannot stall a cold build (no TTY); keep the image's existing conffiles.
ENV DEBIAN_FRONTEND=noninteractive

RUN apt-get update && apt-get install -y --no-install-recommends \
    -o Dpkg::Options::=--force-confold \
    python3 python3-pip python3-venv \
    libcurl4-openssl-dev \
    libssl-dev \
    && rm -rf /var/lib/apt/lists/*

RUN R -e "install.packages('shiny', repos='https://cloud.r-project.org')"
RUN pip3 install --no-cache-dir --break-system-packages shiny

WORKDIR /app

COPY entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh

EXPOSE 3838

ENTRYPOINT ["/entrypoint.sh"]
