#!/bin/sh
set -eu

python -m uvicorn backend.app.main:app \
    --host "${PYTHON_BACKEND_HOST:-127.0.0.1}" \
    --port "${PYTHON_BACKEND_PORT:-8000}" &
api_pid=$!

node /app/server/openai_body_analysis_proxy.js &
body_proxy_pid=$!

nginx -g "daemon off;" &
nginx_pid=$!

trap 'kill "$api_pid" "$body_proxy_pid" "$nginx_pid"' INT TERM

wait "$api_pid" "$body_proxy_pid" "$nginx_pid"
