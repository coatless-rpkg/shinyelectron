#!/bin/bash
set -e

PORT=${PORT:-3838}
HOST=${HOST:-0.0.0.0}

# Detect language from dependencies manifest
LANG="r"
if [ -f /app/dependencies.json ]; then
  LANG=$(python3 -c "import json; print(json.load(open('/app/dependencies.json'))['language'])" 2>/dev/null || echo "r")
fi

# Install dependencies
if [ -f /app/dependencies.json ]; then
  echo "Installing package dependencies..."
  if [ "$LANG" = "r" ]; then
    Rscript -e '
      deps <- jsonlite::fromJSON("/app/dependencies.json")
      if (length(deps$packages) > 0) {
        install.packages(unlist(deps$packages), repos = unlist(deps$repos), type = "binary", quiet = TRUE, dependencies = FALSE)
      }
    '
  else
    python3 -c "
import json, subprocess
with open('/app/dependencies.json') as f:
    deps = json.load(f)
if deps.get('packages'):
    index = deps.get('index_urls', ['https://pypi.org/simple'])[0]
    subprocess.run(['pip3', 'install', '--only-binary', ':all:', '-i', index] + deps['packages'], check=True)
"
  fi
fi

echo "Starting Shiny app ($LANG) on $HOST:$PORT..."
if [ "$LANG" = "r" ]; then
  exec Rscript -e "shiny::runApp('/app', port = ${PORT}, host = '${HOST}', launch.browser = FALSE)"
else
  exec python3 -m shiny run --port "$PORT" --host "$HOST" /app
fi
