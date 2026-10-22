
FROM node:8.9-slim@sha256:288b29c1925d65b2d7d8701f8ada201e7dcd066438c0fb4299c35dff129b893f

# Install test dependencies
RUN apt-get update -qq && \
    apt-get install -qy --no-install-recommends \
        ca-certificates \
        bzip2 \
        curl \
        libfontconfig && \
    rm -rf /var/lib/apt/lists/*

# Install PhantomJS during the build
RUN yarn global add phantomjs-prebuilt

# Copy test files and assign them to the node user
COPY --chown=node:node . /app

WORKDIR /app

# Run tests as non-root
USER node

CMD ["/app/tests.sh"]
