
FROM node:18-slim@sha256:f9ab18e354e6855ae56ef2b290dd225c1e51a564f87584b9bd21dd651838830e

# Add curl for healthchecks and tini for process management
RUN apt-get update \
    && apt-get install -y --no-install-recommends ca-certificates curl tini \
    && sed -i 's|http://deb.debian.org|https://deb.debian.org|g' /etc/apt/sources.list.d/debian.sources \
    && apt-get update \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /usr/local/app

# Install development tooling during the build
RUN npm install -g nodemon

COPY package*.json ./

RUN npm ci && \
    npm cache clean --force && \
    mv /usr/local/app/node_modules /node_modules

COPY . .

ENV PORT=80

EXPOSE 80

# Run the application using the existing non-root node user
USER node

ENTRYPOINT ["/usr/bin/tini", "--"]
CMD ["node", "server.js"]
