#!/bin/bash
set -e

PORT=${PORT:-3838}
HOST=${HOST:-0.0.0.0}

# Install dependencies from manifest if present
if [ -f /app/dependencies.json ]; then
  echo "Installing Python package dependencies..."
  python3 -c "
import json
with open('/app/dependencies.json') as f:
    deps = json.load(f)
if deps.get('packages'):
    import subprocess
    pkgs = deps['packages']
    index = deps.get('index_urls', ['https://pypi.org/simple'])[0]
    subprocess.run(['pip', 'install', '--only-binary', ':all:', '-i', index] + pkgs, check=True)
"
fi

echo "Starting Shiny app on $HOST:$PORT..."
exec python3 -m shiny run --port "$PORT" --host "$HOST" --app-dir /app --no-dev-mode app:app
