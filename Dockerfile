FROM ghcr.io/cirruslabs/flutter:stable AS flutter-build

WORKDIR /app

COPY pubspec.yaml pubspec.lock ./
RUN flutter pub get

COPY . .
RUN flutter build web --release \
    --dart-define=API_BASE_URL= \
    --dart-define=BODY_ANALYSIS_API_URL=/analyze-body

FROM python:3.12-slim

ENV PYTHONUNBUFFERED=1 \
    PYTHON_BACKEND_HOST=127.0.0.1 \
    PYTHON_BACKEND_PORT=8000 \
    OPENAI_BODY_PROXY_PORT=8787

RUN apt-get update \
    && apt-get install -y --no-install-recommends ca-certificates nginx nodejs \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /app

COPY backend/requirements.txt /app/backend/requirements.txt
RUN pip install --no-cache-dir -r /app/backend/requirements.txt

COPY backend /app/backend
COPY server /app/server
COPY --from=flutter-build /app/build/web /usr/share/nginx/html
COPY deploy/nginx.conf /etc/nginx/nginx.conf
COPY deploy/start.sh /app/start.sh

RUN chmod +x /app/start.sh

EXPOSE 8080

CMD ["/app/start.sh"]
