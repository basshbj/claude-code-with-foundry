locals {
  model_names = toset([for model in var.models : lower(trimspace(model))])
}

resource "azurerm_resource_group" "this" {
  name     = coalesce(var.resource_group_name, "${var.name_prefix}-rg")
  location = var.location
  tags     = var.tags
}

resource "azurerm_api_management" "this" {
  name                          = "${var.name_prefix}-apim"
  resource_group_name           = azurerm_resource_group.this.name
  location                      = azurerm_resource_group.this.location
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

resource "azurerm_cognitive_account" "this" {
  name                          = "${var.name_prefix}-foundry"
  resource_group_name           = azurerm_resource_group.this.name
  location                      = azurerm_resource_group.this.location
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

resource "azurerm_cognitive_account_project" "this" {
  name                 = "${var.name_prefix}-project"
  cognitive_account_id = azurerm_cognitive_account.this.id
  location             = azurerm_resource_group.this.location
  display_name         = "Claude Code"
  description          = "Claude Code models and observability."
  tags                 = var.tags

  identity {
    type = "SystemAssigned"
  }
}

resource "azapi_resource" "claude" {
  for_each = local.model_names

  type      = "Microsoft.CognitiveServices/accounts/deployments@2025-10-01-preview"
  name      = each.key
  parent_id = azurerm_cognitive_account.this.id
  # modelProviderData is required for Claude but absent from the published ARM schema.
  schema_validation_enabled = false
  # Foundry permits only one deployment update per account at a time.
  locks = [azurerm_cognitive_account.this.id]

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

  depends_on = [azurerm_cognitive_account_project.this]
}

resource "azurerm_log_analytics_workspace" "this" {
  name                = "${var.name_prefix}-logs"
  resource_group_name = azurerm_resource_group.this.name
  location            = azurerm_resource_group.this.location
  sku                 = "PerGB2018"
  retention_in_days   = var.log_retention_days
  tags                = var.tags
}

resource "azurerm_monitor_diagnostic_setting" "apim" {
  name                           = "platform-metrics"
  target_resource_id             = azurerm_api_management.this.id
  log_analytics_workspace_id     = azurerm_log_analytics_workspace.this.id
  log_analytics_destination_type = "Dedicated"

  enabled_log {
    category_group = "allLogs"
  }

  enabled_metric {
    category = "AllMetrics"
  }
}

resource "azurerm_monitor_diagnostic_setting" "foundry" {
  name                       = "platform-metrics"
  target_resource_id         = azurerm_cognitive_account.this.id
  log_analytics_workspace_id = azurerm_log_analytics_workspace.this.id

  enabled_log {
    category_group = "allLogs"
  }

  enabled_metric {
    category = "AllMetrics"
  }
}
