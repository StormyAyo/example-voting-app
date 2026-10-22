
FROM python:3.9-slim@sha256:2d97f6910b16bd338d3060f261f53f144965f755599aab1acda1e13cf1731b1b

# Install Apache Bench
RUN apt-get update && \
    apt-get install -y --no-install-recommends apache2-utils && \
    rm -rf /var/lib/apt/lists/*

WORKDIR /seed

# Create a dedicated non-root user
RUN useradd --system --uid 10001 --no-create-home appuser

# Copy the generator files
COPY --chown=10001:10001 . .

# Generate the test data during the image build
RUN python make-data.py && \
    chown -R 10001:10001 /seed

# Run the vote generator as non-root
USER 10001

CMD ["/seed/generate-votes.sh"]
