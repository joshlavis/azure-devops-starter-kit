#!/usr/bin/env bash
# deploy-containerapp.sh - roll a new image onto the Container App, smoke test it,
# and automatically roll back to the previous image if /healthz fails.
#
# Usage: scripts/ci/deploy-containerapp.sh <workload> <environment> <image> [version]
#   image   full reference, ideally by digest: myacr.azurecr.io/web@sha256:...
#   version shown at GET / (defaults to the short git sha if available)

set -euo pipefail
WORKLOAD="${1:?workload}"
ENVIRONMENT="${2:?environment}"
IMAGE="${3:?image}"
VERSION="${4:-$(git rev-parse --short HEAD 2>/dev/null || echo manual)}"
APP_PORT="${APP_PORT:-8080}"
HERE="$(cd "$(dirname "$0")" && pwd)"

eval "$("$HERE/find-resources.sh" "$WORKLOAD" "$ENVIRONMENT")"
PREVIOUS_IMAGE="$CURRENT_IMAGE"
echo "App: $CONTAINER_APP ($RESOURCE_GROUP)"
echo "Previous image: $PREVIOUS_IMAGE"
echo "New image:      $IMAGE"

# First real deploy: the placeholder listens on 80, the sample app on $APP_PORT.
CURRENT_PORT="$(az containerapp show -n "$CONTAINER_APP" -g "$RESOURCE_GROUP" --query properties.configuration.ingress.targetPort -o tsv)"
if [[ "$CURRENT_PORT" != "$APP_PORT" ]]; then
  echo "Setting ingress target port $CURRENT_PORT -> $APP_PORT"
  az containerapp ingress update -n "$CONTAINER_APP" -g "$RESOURCE_GROUP" --target-port "$APP_PORT" -o none
fi

az containerapp update -n "$CONTAINER_APP" -g "$RESOURCE_GROUP" \
  --image "$IMAGE" \
  --set-env-vars "APP_VERSION=${VERSION}" \
  --revision-suffix "v-${VERSION:0:12}-$(date +%s | tail -c 6)" \
  -o none

FQDN="$(az containerapp show -n "$CONTAINER_APP" -g "$RESOURCE_GROUP" --query properties.configuration.ingress.fqdn -o tsv)"
URL="https://${FQDN}"
echo "Smoke testing $URL/healthz"

ok=0
for i in $(seq 1 18); do
  if curl -fsS --max-time 10 "$URL/healthz" >/dev/null; then ok=1; break; fi
  echo "  attempt $i failed, retrying in 10s (scale-from-zero can take ~30s)"
  sleep 10
done

if [[ "$ok" -ne 1 ]]; then
  echo "::error::Smoke test failed. Rolling back to $PREVIOUS_IMAGE" >&2
  az containerapp update -n "$CONTAINER_APP" -g "$RESOURCE_GROUP" --image "$PREVIOUS_IMAGE" -o none
  exit 1
fi

echo "Deployed. $URL"
echo "APP_URL=$URL" >> "${GITHUB_OUTPUT:-/dev/null}"
