#!/bin/sh
set -eu

if [ "${MOASHIR_PULL_ON_BOOT:-1}" = "1" ]; then
    repo_dir="${MOASHIR_REPO_DIR:-$(pwd)}"
    repo_remote="${MOASHIR_GIT_REMOTE:-origin}"
    repo_branch="${MOASHIR_GIT_BRANCH:-main}"

    if command -v git >/dev/null 2>&1 && [ -d "${repo_dir}/.git" ]; then
        echo "Pulling latest MO'ASHIR code from GitHub..."
        if ! git -C "${repo_dir}" fetch "${repo_remote}" "${repo_branch}" ||
            ! git -C "${repo_dir}" pull --ff-only "${repo_remote}" "${repo_branch}"; then
            echo "GitHub pull failed; continuing with the existing local code."
        fi
    else
        echo "Skipping GitHub pull; ${repo_dir} is not a Git checkout or git is unavailable."
    fi
fi

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
