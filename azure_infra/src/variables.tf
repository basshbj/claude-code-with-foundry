variable "subscription_id" {
  description = "Azure subscription in which to create a new resource group."
  type        = string
}

variable "tenant_id" {
  description = "Entra tenant for the Azure subscription and gateway token validation."
  type        = string
}

variable "name_prefix" {
  description = "Globally unique naming prefix. Resource names are derived from this prefix."
  type        = string

  validation {
    condition     = can(regex("^[a-z][a-z0-9-]{2,29}$", var.name_prefix)) && !endswith(var.name_prefix, "-")
    error_message = "Use 3-30 lowercase letters, digits, or hyphens, beginning with a letter and not ending with a hyphen."
  }
}

variable "location" {
  description = "Azure region supporting Standard v2 APIM, Microsoft Foundry, and the selected models."
  type        = string
}

variable "resource_group_name" {
  description = "Name of the NEW resource group. Null derives <name_prefix>-rg; existing groups are not adopted."
  type        = string
  default     = null
}

variable "tags" {
  description = "Tags applied to Azure resources."
  type        = map(string)
  default     = {}
}

variable "apim_sku_name" {
  description = "Standard v2 APIM plan and capacity, for example StandardV2_1. No VNet integration is configured."
  type        = string
  default     = "StandardV2_1"

  validation {
    condition     = can(regex("^StandardV2_([1-9]|10)$", var.apim_sku_name))
    error_message = "Choose StandardV2_1 through StandardV2_10."
  }
}

variable "publisher_name" {
  description = "Organization name required by APIM."
  type        = string
}

variable "publisher_email" {
  description = "Operational contact email required by APIM."
  type        = string
}

variable "models" {
  description = "Claude catalog names, trimmed and lowercased for deployment names. Version 2 pins Hosted on Azure."
  type        = list(string)
  default = [
    "claude-opus-4-8",
    "claude-opus-5-5",
    "claude-haiku-4-5",
    "claude-sonnet-5",
    "claude-opus-5",
    "claude-sonnet-5-5",
    "claude-haiku-5-5",
  ]

  validation {
    condition = length(var.models) > 0 && alltrue([
      for model in var.models :
      can(regex("^claude-(opus|sonnet|haiku)-[0-9]+(-[0-9]+)*$", lower(trimspace(model)))) &&
      length(trimspace(model)) <= 64
    ])
    error_message = "Provide at least one Claude catalog name, for example claude-opus-5-5 (at most 64 characters)."
  }

  validation {
    condition     = length(distinct([for model in var.models : lower(trimspace(model))])) == length(var.models)
    error_message = "Model names must be unique after trimming whitespace and converting to lowercase."
  }
}

variable "model_deployment_sku_name" {
  description = "Shared Claude deployment plan. Verify model/region availability and data residency."
  type        = string
  default     = "GlobalStandard"

  validation {
    condition     = contains(["GlobalStandard", "DataZoneStandard"], var.model_deployment_sku_name)
    error_message = "Claude Hosted on Azure requires GlobalStandard or supported US DataZoneStandard."
  }
}

variable "model_deployment_capacity" {
  description = "Shared capacity per model deployment, in model/SKU-specific Azure quota units."
  type        = number
  default     = 1

  validation {
    condition     = var.model_deployment_capacity >= 1 && var.model_deployment_capacity == floor(var.model_deployment_capacity)
    error_message = "Use a positive integer deployment capacity."
  }
}

variable "claude_organization_name" {
  description = "Actual legal organization for Claude modelProviderData. Applying accepts the Anthropic Marketplace terms."
  type        = string

  validation {
    condition     = length(trimspace(var.claude_organization_name)) > 0 && !startswith(upper(trimspace(var.claude_organization_name)), "REPLACE_")
    error_message = "Supply the actual legal organization accepting the Claude Marketplace terms."
  }
}

variable "claude_country_code" {
  description = "Actual two-letter uppercase ISO country code for the Claude Marketplace attestation."
  type        = string

  validation {
    condition     = can(regex("^[A-Z]{2}$", var.claude_country_code))
    error_message = "Supply a two-letter uppercase country code, for example US."
  }
}

variable "claude_industry" {
  description = "Actual industry for Claude modelProviderData, matching the Foundry portal."
  type        = string

  validation {
    condition     = contains(["technology", "finance", "healthcare", "education", "retail", "manufacturing", "government", "media", "other"], var.claude_industry)
    error_message = "Choose technology, finance, healthcare, education, retail, manufacturing, government, media, or other."
  }
}

variable "allowed_principal_object_ids" {
  description = "Optional Entra user, security group, or service-principal IDs assigned the gateway app role plus Foundry and telemetry access."
  type        = set(string)
  default     = []

  validation {
    condition = alltrue([
      for id in var.allowed_principal_object_ids :
      can(regex("^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$", id)) &&
      id != "00000000-0000-0000-0000-000000000000"
    ])
    error_message = "Each supplied object ID must be a nonzero Entra user, security group, or service-principal GUID."
  }
}

variable "allowed_user_emails" {
  description = "Email addresses (Entra mail attribute) of users assigned the gateway app role plus Foundry inference and telemetry read access."
  type        = set(string)
  default     = []

  validation {
    condition = alltrue([
      for email in var.allowed_user_emails :
      can(regex("^[^\\s@]+@[^\\s@]+\\.[^\\s@]+$", trimspace(email)))
    ])
    error_message = "Each user email must be a valid email address."
  }
}

variable "allowed_group_names" {
  description = "Exact, unique security group names assigned the gateway app role plus Foundry/log access. Entra app-role assignment supports direct members, not nested groups."
  type        = set(string)
  default     = []

  validation {
    condition     = alltrue([for name in var.allowed_group_names : length(trimspace(name)) > 0])
    error_message = "Group names must not be empty or whitespace."
  }
}

variable "requests_per_minute" {
  description = "APIM request limit per validated tenant/user. Limits are approximate, not a billing cap."
  type        = number
  default     = 60

  validation {
    condition     = var.requests_per_minute >= 1 && var.requests_per_minute == floor(var.requests_per_minute)
    error_message = "Use a positive integer request limit."
  }
}

variable "tokens_per_minute" {
  description = "Approximate APIM prompt/completion token rate per caller across all allowed models."
  type        = number
  default     = 50000

  validation {
    condition     = var.tokens_per_minute >= 1 && var.tokens_per_minute <= 2147483647 && var.tokens_per_minute == floor(var.tokens_per_minute)
    error_message = "Use an integer token rate between 1 and 2147483647."
  }
}

variable "monthly_token_quota" {
  description = "Approximate per-caller token quota per UTC calendar month, across all allowed models; not a hard billing cap."
  type        = number
  default     = 5000000

  validation {
    condition     = var.monthly_token_quota >= 1 && var.monthly_token_quota <= 2147483647 && var.monthly_token_quota == floor(var.monthly_token_quota)
    error_message = "Use an integer monthly token quota between 1 and 2147483647."
  }
}

variable "log_retention_days" {
  description = "Log Analytics retention for platform logs, gateway requests, and workspace-based Application Insights."
  type        = number
  default     = 30

  validation {
    condition     = var.log_retention_days >= 30 && var.log_retention_days <= 730 && var.log_retention_days == floor(var.log_retention_days)
    error_message = "Use an integer retention between 30 and 730 days."
  }
}
