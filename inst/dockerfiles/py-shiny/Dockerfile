# Minimal Python + Shiny image for shinyelectron container strategy
FROM python:3.12-slim

RUN pip install --no-cache-dir shiny

WORKDIR /app

COPY entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh

EXPOSE 3838

ENTRYPOINT ["/entrypoint.sh"]
