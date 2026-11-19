# naming module - Cloud Adoption Framework style names, identical pattern to
# infra/bicep/modules/naming.bicep:  <abbr>-<workload>-<env>-<region>-<instance>

terraform {
  required_version = ">= 1.9.0"
}

variable "workload" {
  description = "Short workload name, 2-10 lowercase letters/digits."
  type        = string
  validation {
    condition     = can(regex("^[a-z0-9]{2,10}$", var.workload))
    error_message = "workload must be 2-10 lowercase letters or digits."
  }
}

variable "environment" {
  description = "dev, test or prod."
  type        = string
  validation {
    condition     = contains(["dev", "test", "prod"], var.environment)
    error_message = "environment must be dev, test or prod."
  }
}

variable "location" {
  description = "Azure region, e.g. westus3."
  type        = string
}

variable "instance" {
  description = "Zero-padded instance number."
  type        = string
  default     = "001"
}

variable "suffix" {
  description = "3-6 lowercase alphanumerics for globally unique names (Key Vault, Storage, ACR)."
  type        = string
  validation {
    condition     = can(regex("^[a-z0-9]{3,6}$", var.suffix))
    error_message = "suffix must be 3-6 lowercase letters or digits."
  }
}

locals {
  region_short_map = {
    eastus             = "eus"
    eastus2            = "eus2"
    centralus          = "cus"
    northcentralus     = "ncus"
    southcentralus     = "scus"
    westus             = "wus"
    westus2            = "wus2"
    westus3            = "wus3"
    westcentralus      = "wcus"
    canadacentral      = "cac"
    canadaeast         = "cae"
    northeurope        = "neu"
    westeurope         = "weu"
    uksouth            = "uks"
    ukwest             = "ukw"
    francecentral      = "frc"
    germanywestcentral = "gwc"
    swedencentral      = "sdc"
    switzerlandnorth   = "szn"
    australiaeast      = "aue"
    southeastasia      = "sea"
    eastasia           = "ea"
    japaneast          = "jpe"
    centralindia       = "inc"
    brazilsouth        = "brs"
  }
  loc    = lower(replace(var.location, " ", ""))
  region = lookup(local.region_short_map, local.loc, substr(local.loc, 0, 6))
  base   = "${var.workload}-${var.environment}-${local.region}-${var.instance}"
}

output "region_short" {
  value = local.region
}

output "names" {
  description = "All generated resource names."
  value = {
    resource_group     = "rg-${local.base}"
    log_analytics      = "log-${local.base}"
    app_insights       = "appi-${local.base}"
    managed_identity   = "id-${local.base}"
    container_apps_env = "cae-${local.base}"
    container_app      = "ca-${local.base}"
    key_vault          = substr("kv-${var.workload}-${var.environment}-${var.suffix}", 0, 24)
    storage_account    = substr("st${var.workload}${var.environment}${var.suffix}", 0, 24)
    container_registry = substr("cr${var.workload}${var.environment}${var.suffix}", 0, 50)
  }
}
