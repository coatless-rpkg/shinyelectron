#!/bin/bash
set -e

PORT=${PORT:-3838}
HOST=${HOST:-0.0.0.0}

echo "Starting Shiny app on $HOST:$PORT..."
exec Rscript --vanilla -e ".libPaths(c('/usr/local/lib/R/site-library', '/usr/lib/R/site-library', '/usr/lib/R/library')); shiny::runApp('/app', port = ${PORT}, host = '${HOST}', launch.browser = FALSE)"
