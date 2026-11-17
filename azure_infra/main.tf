# --------
# MAIN
# --------

locals {
  model_names = toset([for model in var.models : lower(trimspace(model))])
}

# Resource Group
resource "azurerm_resource_group" "rg" {
  name     = "${var.name_prefix}-rg"
  location = var.location
  tags     = var.tags
}

# API Management
resource "azurerm_api_management" "apim" {
  name                          = "${var.name_prefix}-apim"
  resource_group_name           = azurerm_resource_group.rg.name
  location                      = azurerm_resource_group.rg.location
  publisher_name                = var.publisher_name
  publisher_email               = var.publisher_email
  sku_name                      = var.apim_sku_name
  virtual_network_type          = "None"
  public_network_access_enabled = true
  tags                          = var.tags

  identity {
    type = "SystemAssigned"
  }
}

# Microsoft Foundry - Account
resource "azurerm_cognitive_account" "foundry" {
  name                          = "${var.name_prefix}-foundry"
  resource_group_name           = azurerm_resource_group.rg.name
  location                      = azurerm_resource_group.rg.location
  kind                          = "AIServices"
  sku_name                      = "S0"
  custom_subdomain_name         = "${var.name_prefix}-foundry"
  project_management_enabled    = true
  local_auth_enabled            = false
  public_network_access_enabled = true
  tags                          = var.tags

  identity {
    type = "SystemAssigned"
  }

  network_acls {
    default_action = "Allow"
    bypass         = "None"
  }
}

# Microsoft Foundry - Project
resource "azurerm_cognitive_account_project" "foundry_prj" {
  name                 = "${var.name_prefix}-project"
  cognitive_account_id = azurerm_cognitive_account.foundry.id
  location             = azurerm_resource_group.rg.location
  display_name         = "Claude Code"
  description          = "Claude Code models and observability."
  tags                 = var.tags

  identity {
    type = "SystemAssigned"
  }
}

# Microsoft Foundry - Claude model deployments
resource "azapi_resource" "claude" {
  for_each = local.model_names

  type      = "Microsoft.CognitiveServices/accounts/deployments@2025-10-01-preview"
  name      = each.key
  parent_id = azurerm_cognitive_account.foundry.id
  # modelProviderData is required for Claude but absent from the published ARM schema.
  schema_validation_enabled = false
  # Foundry permits only one deployment update per account at a time.
  locks = [azurerm_cognitive_account.foundry.id]

  body = {
    sku = {
      name     = var.model_deployment_sku_name
      capacity = var.model_deployment_capacity
    }
    properties = {
      model = {
        format  = "Anthropic"
        name    = each.value
        version = "2"
      }
      modelProviderData = {
        organizationName = trimspace(var.claude_organization_name)
        countryCode      = var.claude_country_code
        industry         = var.claude_industry
      }
      versionUpgradeOption = "NoAutoUpgrade"
    }
  }

  depends_on = [azurerm_cognitive_account_project.foundry_prj]
}

# Log Analytics workspace
resource "azurerm_log_analytics_workspace" "logana" {
  name                = "${var.name_prefix}-logs"
  resource_group_name = azurerm_resource_group.rg.name
  location            = azurerm_resource_group.rg.location
  sku                 = "PerGB2018"
  retention_in_days   = var.log_retention_days
  tags                = var.tags
}

# Application Insights
resource "azurerm_application_insights" "app_insights" {
  name                         = "${var.name_prefix}-insights"
  resource_group_name          = azurerm_resource_group.rg.name
  location                     = azurerm_resource_group.rg.location
  application_type             = "web"
  workspace_id                 = azurerm_log_analytics_workspace.logana.id
  sampling_percentage          = 100
  local_authentication_enabled = false
  tags                         = var.tags
}

# API Management diagnostics
resource "azurerm_monitor_diagnostic_setting" "apim_diagnostics" {
  name                           = "platform-metrics"
  target_resource_id             = azurerm_api_management.apim.id
  log_analytics_workspace_id     = azurerm_log_analytics_workspace.logana.id
  log_analytics_destination_type = "Dedicated"

  enabled_log {
    category_group = "allLogs"
  }

  enabled_metric {
    category = "AllMetrics"
  }
}

# Microsoft Foundry diagnostics
resource "azurerm_monitor_diagnostic_setting" "foundry_diagnostics" {
  name                       = "platform-metrics"
  target_resource_id         = azurerm_cognitive_account.foundry.id
  log_analytics_workspace_id = azurerm_log_analytics_workspace.logana.id

  enabled_log {
    category_group = "allLogs"
  }

  enabled_metric {
    category = "AllMetrics"
  }
}
