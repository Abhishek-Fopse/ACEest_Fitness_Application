
FROM python:3.12-slim AS base

ENV PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1

WORKDIR /app

ARG APP_VERSION=1.0.0
ENV ACEEST_APP_VERSION=${APP_VERSION}

COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt


# -------------------------
# Test stage
# -------------------------
FROM base AS test

COPY requirements-test.txt .
RUN pip install --no-cache-dir -r requirements-test.txt

COPY app.py .
COPY tests/ ./tests/

RUN mkdir -p /app/reports

CMD ["python", "-m", "pytest", "-v", "--junitxml=/app/reports/pytest-results.xml"]


# -------------------------
# Production stage
# -------------------------
FROM base AS production

COPY app.py .

RUN groupadd --system appuser \
    && useradd --system --gid appuser --create-home appuser \
    && chown -R appuser:appuser /app

USER appuser

EXPOSE 5000

HEALTHCHECK --interval=30s --timeout=5s --start-period=10s --retries=3 \
    CMD python -c "import urllib.request; urllib.request.urlopen('http://127.0.0.1:5000/health', timeout=3)" || exit 1

CMD ["gunicorn", "--bind", "0.0.0.0:5000", "--workers", "2", "--access-logfile", "-", "--error-logfile", "-", "app:app"]