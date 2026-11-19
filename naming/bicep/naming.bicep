// naming.bicep - exported naming functions (compile-time, so names are known
// at the start of a deployment and can be used for resource group names).
// Pattern: <abbr>-<workload>-<env>-<region>-<instance>  (Cloud Adoption Framework style)
//
// Usage:
//   import { resourceNames, regionShort } from 'modules/naming.bicep'
//   var names = resourceNames('shop', 'dev', 'westus3', '001', 'a1b2')

@export()
@description('Short code for an Azure region (falls back to the first 6 chars).')
func regionShort(location string) string =>
  {
    eastus: 'eus'
    eastus2: 'eus2'
    centralus: 'cus'
    northcentralus: 'ncus'
    southcentralus: 'scus'
    westus: 'wus'
    westus2: 'wus2'
    westus3: 'wus3'
    westcentralus: 'wcus'
    canadacentral: 'cac'
    canadaeast: 'cae'
    northeurope: 'neu'
    westeurope: 'weu'
    uksouth: 'uks'
    ukwest: 'ukw'
    francecentral: 'frc'
    germanywestcentral: 'gwc'
    swedencentral: 'sdc'
    switzerlandnorth: 'szn'
    australiaeast: 'aue'
    southeastasia: 'sea'
    eastasia: 'ea'
    japaneast: 'jpe'
    centralindia: 'inc'
    brazilsouth: 'brs'
  }[?toLower(replace(location, ' ', ''))] ?? take(toLower(replace(location, ' ', '')), 6)

@export()
@description('Every resource name for one workload/environment. suffix = 3-6 lowercase alphanumerics used for globally unique names (Key Vault, Storage, ACR).')
func resourceNames(workload string, environment string, location string, instance string, suffix string) object => {
  resourceGroup: 'rg-${toLower(workload)}-${environment}-${regionShort(location)}-${instance}'
  logAnalytics: 'log-${toLower(workload)}-${environment}-${regionShort(location)}-${instance}'
  appInsights: 'appi-${toLower(workload)}-${environment}-${regionShort(location)}-${instance}'
  managedIdentity: 'id-${toLower(workload)}-${environment}-${regionShort(location)}-${instance}'
  containerAppsEnv: 'cae-${toLower(workload)}-${environment}-${regionShort(location)}-${instance}'
  containerApp: 'ca-${toLower(workload)}-${environment}-${regionShort(location)}-${instance}'
  // Key Vault: 3-24 chars, letters/digits/hyphens
  keyVault: take('kv-${toLower(workload)}-${environment}-${toLower(suffix)}', 24)
  // Storage: 3-24 chars, lowercase letters/digits only
  storageAccount: take('st${toLower(workload)}${environment}${toLower(suffix)}', 24)
  // ACR: 5-50 chars, letters/digits only
  containerRegistry: take('cr${toLower(workload)}${environment}${toLower(suffix)}', 50)
}
