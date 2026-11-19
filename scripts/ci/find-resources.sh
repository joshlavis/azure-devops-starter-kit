#!/usr/bin/env bash
# find-resources.sh - look up the kit's resources by tag (workload + environment),
# so pipelines never hard-code generated names or suffixes.
# Prints KEY=VALUE lines: RESOURCE_GROUP, CONTAINER_APP, ACR_NAME, ACR_LOGIN_SERVER, CURRENT_IMAGE
#
# Usage: eval "$(scripts/ci/find-resources.sh starter dev)"

set -euo pipefail
WORKLOAD="${1:?workload}"
ENVIRONMENT="${2:?environment}"
Q="[?tags.workload=='${WORKLOAD}' && tags.environment=='${ENVIRONMENT}']"

APP_JSON="$(az containerapp list --query "${Q} | [0].{name:name, rg:resourceGroup, image:properties.template.containers[0].image}" -o json)"
ACR_JSON="$(az acr list --query "${Q} | [0].{name:name, server:loginServer}" -o json)"

if [[ "$APP_JSON" == "null" || -z "$APP_JSON" ]]; then
  echo "No container app tagged workload=${WORKLOAD} environment=${ENVIRONMENT}. Run the infra pipeline first." >&2
  exit 1
fi

jq -r '"RESOURCE_GROUP=\(.rg)", "CONTAINER_APP=\(.name)", "CURRENT_IMAGE=\(.image)"' <<<"$APP_JSON"
jq -r 'if . == null then empty else "ACR_NAME=\(.name)", "ACR_LOGIN_SERVER=\(.server)" end' <<<"$ACR_JSON"
