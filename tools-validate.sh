#!/usr/bin/env bash
# Offline checks for this repo (no Azure login needed).
set -euo pipefail
cd "$(dirname "$0")"
(cd app && npm run -s lint && npm test --silent)
shellcheck bootstrap/*.sh scripts/ci/*.sh tools-validate.sh
hadolint app/Dockerfile
actionlint examples/workflows/*.yml
yamllint -c .yamllint.yml .github
(cd naming/terraform && terraform fmt -check && terraform init -backend=false -input=false >/dev/null && terraform validate)
bicep lint naming/bicep/naming.bicep
echo "ALL CHECKS PASSED"
