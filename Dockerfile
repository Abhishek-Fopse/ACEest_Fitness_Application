
FROM python:3.12-slim

ENV PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1

WORKDIR /app

# Application version can be overridden during image builds.
ARG APP_VERSION=1.0.0
ENV ACEEST_APP_VERSION=${APP_VERSION}

# Install application dependencies.
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

# Copy application and test files.
COPY app.py .
COPY tests/ ./tests/

# Create a dedicated non-root user.
RUN groupadd --system appuser \
    && useradd --system --gid appuser --create-home appuser \
    && chown -R appuser:appuser /app

USER appuser

EXPOSE 5000

# Check application and database readiness.
HEALTHCHECK --interval=30s --timeout=5s --start-period=10s --retries=3 \
    CMD python -c "import urllib.request; urllib.request.urlopen('http://127.0.0.1:5000/health', timeout=3)" || exit 1

# Run Flask through Gunicorn instead of the development server.
CMD ["gunicorn", "--bind", "0.0.0.0:5000", "--workers", "2", "--access-logfile", "-", "--error-logfile", "-", "app:app"]