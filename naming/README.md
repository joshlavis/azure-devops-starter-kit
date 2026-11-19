# Azure naming module (Bicep + Terraform)

Cloud Adoption Framework-style names: `<abbr>-<workload>-<env>-<region>-<instance>`, with a short suffix for globally unique resources. Bicep and Terraform return **identical** names for the same inputs.

| Key | Example (`shop`, `prod`, `westus3`, suffix `a1b2`) |
|---|---|
| resource group | `rg-shop-prod-wus3-001` |
| log analytics | `log-shop-prod-wus3-001` |
| app insights | `appi-shop-prod-wus3-001` |
| managed identity | `id-shop-prod-wus3-001` |
| container apps env / app | `cae-shop-prod-wus3-001` / `ca-shop-prod-wus3-001` |
| key vault (≤24) | `kv-shop-prod-a1b2` |
| storage (≤24, no hyphens) | `stshopproda1b2` |
| container registry | `crshopproda1b2` |

## Bicep (exported functions, so names are known at compile time and work for resource group names)

```bicep
targetScope = 'subscription'
import { resourceNames } from 'naming.bicep'

var names = resourceNames('shop', 'prod', 'westus3', '001', 'a1b2')

resource rg 'Microsoft.Resources/resourceGroups@2025-04-01' = {
  name: names.resourceGroup
  location: 'westus3'
}
```

## Terraform

```hcl
module "naming" {
  source      = "./naming/terraform"
  workload    = "shop"
  environment = "prod"
  location    = "westus3"
  suffix      = "a1b2"
}

resource "azurerm_resource_group" "this" {
  name     = module.naming.names.resource_group
  location = "westus3"
}
```
