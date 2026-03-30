# ============================================================
# Dockerfile — Mobile Backend (FastAPI + Gunicorn)
# Multi-stage build for ultra-light image & fast Heroku boot
# ============================================================

# ── Stage 1: Builder ─────────────────────────────────────────
FROM python:3.11-slim AS builder

WORKDIR /build

# Install dependencies into isolated prefix (no build artifacts in runtime)
COPY requirements.txt .
RUN pip install --no-cache-dir --prefix=/install \
    --only-binary=:all: \
    -r requirements.txt

# ── Stage 2: Runtime ─────────────────────────────────────────
FROM python:3.11-slim

# Optimize Python for containers
ENV PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1

WORKDIR /app

# Copy only installed packages from builder
COPY --from=builder /install /usr/local

# Copy only application code (no tests, no config files, no venv)
COPY app/ ./app/
COPY run.py .

# Heroku injects $PORT at runtime, default to 8080 for local testing
# Use 2 workers to stay within Heroku Eco dyno memory (512MB)
CMD gunicorn app.main:app \
    -w 2 \
    -k uvicorn.workers.UvicornWorker \
    --bind 0.0.0.0:${PORT:-8080} \
    --timeout 120 \
    --access-logfile - \
    --error-logfile -
