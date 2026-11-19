# syntax=docker/dockerfile:1
# Small, non-root image (uid 1000 = the 'node' user in the official image). No npm install needed: the app has zero dependencies.
FROM node:24-alpine AS runtime

ENV NODE_ENV=production \
    PORT=8080

WORKDIR /app
COPY --chown=1000:1000 package.json ./
COPY --chown=1000:1000 src ./src

USER 1000:1000
EXPOSE 8080

HEALTHCHECK --interval=30s --timeout=3s --start-period=10s \
  CMD ["wget", "-q", "--spider", "http://127.0.0.1:8080/healthz"]

CMD ["node", "src/server.js"]
