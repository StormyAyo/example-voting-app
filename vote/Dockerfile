
# Base stage
FROM python:3.11-slim@sha256:cce12316475d7d56d605f76e1d811d0dc4e7227f2d4afd29951521264f504ff8 AS base

# Add curl for healthchecks
RUN sed -i 's|http://deb.debian.org|https://deb.debian.org|g' /etc/apt/sources.list.d/debian.sources \
    && apt-get update \
    && apt-get install -y --no-install-recommends curl \
    && rm -rf /var/lib/apt/lists/*

# Create a dedicated application user
RUN useradd --system --uid 10001 --no-create-home appuser

WORKDIR /usr/local/app

# Install dependencies as root during the build
COPY requirements.txt ./requirements.txt
RUN pip install --no-cache-dir -r requirements.txt

# Development stage
FROM base AS dev

RUN pip install watchdog

ENV FLASK_ENV=development

# Run development application as non-root
USER 10001

CMD ["python", "app.py"]

# Production stage
FROM base AS final

# Copy application files with non-root ownership
COPY --chown=10001:10001 . .

EXPOSE 80

# Run production application as non-root
USER 10001

CMD ["gunicorn", "app:app", "-b", "0.0.0.0:80", "--log-file", "-", "--access-logfile", "-", "--workers", "4", "--keep-alive", "0"]
