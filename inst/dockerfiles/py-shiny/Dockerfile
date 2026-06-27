# Python + Shiny image for the shinyelectron container strategy.
ARG PY_VERSION=3.14
FROM python:${PY_VERSION}-slim

ENV DEBIAN_FRONTEND=noninteractive

RUN pip install --no-cache-dir shiny

WORKDIR /app

COPY entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh

EXPOSE 3838

ENTRYPOINT ["/entrypoint.sh"]
