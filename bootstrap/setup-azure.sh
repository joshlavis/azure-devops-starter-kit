#!/usr/bin/env bash
# setup-azure.sh - one-time setup for this repo's Container Apps pipeline.
#
# Creates (all tagged workload=<w> environment=dev):
#   resource group, Log Analytics, Container Registry (admin off), Container Apps environment,
#   a Container App running a placeholder image, an app identity with AcrPull,
#   and a CI identity that GitHub Actions signs in as with OIDC (no secrets).
#
# Usage: ./bootstrap/setup-azure.sh -w demo -g <github-owner>/<repo> [-l westus3]
# Requires: az CLI logged in with Owner on the subscription.

set -euo pipefail
WORKLOAD="" REPO="" LOCATION="westus3"
while getopts "w:g:l:" opt; do
  case "$opt" in
    w) WORKLOAD="$OPTARG" ;;
    g) REPO="$OPTARG" ;;
    l) LOCATION="$OPTARG" ;;
    *) echo "usage: $0 -w workload -g owner/repo [-l location]" >&2; exit 1 ;;
  esac
done
[[ -z "$WORKLOAD" || -z "$REPO" ]] && { echo "usage: $0 -w workload -g owner/repo [-l location]" >&2; exit 1; }

ENV=dev
SUB_ID="$(az account show --query id -o tsv)"
TENANT_ID="$(az account show --query tenantId -o tsv)"
SFX="$(printf '%s' "${SUB_ID}${WORKLOAD}" | sha1sum | cut -c1-4)"
TAGS=(workload="$WORKLOAD" environment="$ENV" managedBy=setup-azure)

# Same convention as naming/ : <abbr>-<workload>-<env>-<region>-<instance>
case "$LOCATION" in
  eastus) REGION=eus ;; eastus2) REGION=eus2 ;; centralus) REGION=cus ;;
  westus) REGION=wus ;; westus2) REGION=wus2 ;; westus3) REGION=wus3 ;;
  northeurope) REGION=neu ;; westeurope) REGION=weu ;; uksouth) REGION=uks ;;
  *) REGION="${LOCATION:0:6}" ;;
esac
BASE="${WORKLOAD}-${ENV}-${REGION}-001"
RG="rg-${BASE}"
LAW="log-${BASE}"
ACR="cr${WORKLOAD}${ENV}${SFX}"
CAE="cae-${BASE}"
APP="ca-${BASE}"
APP_ID="id-${BASE}"
CI_ID="id-cicd-${WORKLOAD}-${ENV}"

for ns in Microsoft.App Microsoft.ContainerRegistry Microsoft.OperationalInsights Microsoft.ManagedIdentity; do
  az provider register -n "$ns" --wait
done

az group create -n "$RG" -l "$LOCATION" --tags "${TAGS[@]}" -o none
az monitor log-analytics workspace create -g "$RG" -n "$LAW" -l "$LOCATION" --retention-time 30 --tags "${TAGS[@]}" -o none
az acr create -g "$RG" -n "$ACR" --sku Basic --admin-enabled false --tags "${TAGS[@]}" -o none

LAW_ID="$(az monitor log-analytics workspace show -g "$RG" -n "$LAW" --query customerId -o tsv)"
LAW_KEY="$(az monitor log-analytics workspace get-shared-keys -g "$RG" -n "$LAW" --query primarySharedKey -o tsv)"
az containerapp env create -g "$RG" -n "$CAE" -l "$LOCATION" \
  --logs-workspace-id "$LAW_ID" --logs-workspace-key "$LAW_KEY" --tags "${TAGS[@]}" -o none

# App identity: pulls images from ACR - no registry password.
az identity create -g "$RG" -n "$APP_ID" -l "$LOCATION" --tags "${TAGS[@]}" -o none
APP_ID_RES="$(az identity show -g "$RG" -n "$APP_ID" --query id -o tsv)"
APP_ID_PRINCIPAL="$(az identity show -g "$RG" -n "$APP_ID" --query principalId -o tsv)"
ACR_RES="$(az acr show -n "$ACR" --query id -o tsv)"
sleep 20
az role assignment create --assignee-object-id "$APP_ID_PRINCIPAL" --assignee-principal-type ServicePrincipal \
  --role AcrPull --scope "$ACR_RES" -o none

az containerapp create -g "$RG" -n "$APP" --environment "$CAE" \
  --image mcr.microsoft.com/k8se/quickstart:latest --target-port 80 --ingress external \
  --min-replicas 0 --max-replicas 2 --cpu 0.25 --memory 0.5Gi \
  --user-assigned "$APP_ID_RES" --registry-server "${ACR}.azurecr.io" --registry-identity "$APP_ID_RES" \
  --tags "${TAGS[@]}" -o none

# CI identity: GitHub Actions signs in with OIDC. Scoped to this resource group only.
az identity create -g "$RG" -n "$CI_ID" -l "$LOCATION" --tags "${TAGS[@]}" -o none
CI_CLIENT="$(az identity show -g "$RG" -n "$CI_ID" --query clientId -o tsv)"
CI_PRINCIPAL="$(az identity show -g "$RG" -n "$CI_ID" --query principalId -o tsv)"
sleep 20
az role assignment create --assignee-object-id "$CI_PRINCIPAL" --assignee-principal-type ServicePrincipal \
  --role Contributor --scope "$(az group show -n "$RG" --query id -o tsv)" -o none
az role assignment create --assignee-object-id "$CI_PRINCIPAL" --assignee-principal-type ServicePrincipal \
  --role AcrPush --scope "$ACR_RES" -o none
az identity federated-credential create -g "$RG" --identity-name "$CI_ID" --name gh-env-dev \
  --issuer https://token.actions.githubusercontent.com \
  --subject "repo:${REPO}:environment:dev" --audiences api://AzureADTokenExchange -o none

cat <<OUT

Done. In GitHub: Settings > Environments > New environment "dev", then add these
environment *variables* (identifiers, not secrets):
  AZURE_CLIENT_ID       = $CI_CLIENT
  AZURE_TENANT_ID       = $TENANT_ID
  AZURE_SUBSCRIPTION_ID = $SUB_ID
And set WORKLOAD: $WORKLOAD at the top of .github/workflows/container-app.yml (copy it from examples/workflows/ first).

Placeholder URL: https://$(az containerapp show -g "$RG" -n "$APP" --query properties.configuration.ingress.fqdn -o tsv)
Tear down later: az group delete -n $RG
OUT
