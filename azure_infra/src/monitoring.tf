resource "azurerm_application_insights" "this" {
  name                         = "${var.name_prefix}-insights"
  resource_group_name          = azurerm_resource_group.this.name
  location                     = azurerm_resource_group.this.location
  application_type             = "web"
  workspace_id                 = azurerm_log_analytics_workspace.this.id
  sampling_percentage          = 100
  local_authentication_enabled = false
  tags                         = var.tags
}

resource "azapi_update_resource" "insights_metric_dimensions" {
  type        = "Microsoft.Insights/components@2020-02-02"
  resource_id = azurerm_application_insights.this.id

  body = {
    properties = {
      CustomMetricsOptedInType = "WithDimensions"
    }
  }

  lifecycle {
    replace_triggered_by = [azurerm_application_insights.this]
  }
}

resource "azurerm_role_assignment" "telemetry_publisher" {
  for_each = {
    apim    = azurerm_api_management.this.identity[0].principal_id
    foundry = azurerm_cognitive_account.this.identity[0].principal_id
    project = azurerm_cognitive_account_project.this.identity[0].principal_id
  }

  scope                = azurerm_application_insights.this.id
  role_definition_name = "Monitoring Metrics Publisher"
  principal_id         = each.value
  principal_type       = "ServicePrincipal"
}

resource "azurerm_role_assignment" "insights_reader" {
  for_each = local.allowed_principal_ids

  scope                = azurerm_application_insights.this.id
  role_definition_name = "Log Analytics Reader"
  principal_id         = each.value
}

resource "azurerm_role_assignment" "logs_reader" {
  for_each = local.allowed_principal_ids

  scope                = azurerm_log_analytics_workspace.this.id
  role_definition_name = "Log Analytics Reader"
  principal_id         = each.value
}

resource "azapi_resource" "project_insights" {
  type      = "Microsoft.CognitiveServices/accounts/projects/connections@2025-09-01"
  name      = "application-insights"
  parent_id = azurerm_cognitive_account_project.this.id
  # ProjectManagedIdentity is supported by Foundry but absent from the ARM schema.
  schema_validation_enabled = false

  body = {
    properties = {
      category      = "AppInsights"
      target        = azurerm_application_insights.this.id
      authType      = "ProjectManagedIdentity"
      isSharedToAll = false
      metadata = {
        ApiType                             = "Azure"
        ResourceId                          = azurerm_application_insights.this.id
        ApplicationInsightsConnectionString = azurerm_application_insights.this.connection_string
      }
    }
  }

  depends_on = [azurerm_role_assignment.telemetry_publisher]
}

resource "azurerm_api_management_logger" "insights" {
  name                = "application-insights"
  api_management_name = azurerm_api_management.this.name
  resource_group_name = azurerm_resource_group.this.name
  resource_id         = azurerm_application_insights.this.id

  application_insights {
    connection_string  = azurerm_application_insights.this.connection_string
    identity_client_id = "SystemAssigned"
  }

  depends_on = [azurerm_role_assignment.telemetry_publisher]
}

resource "azurerm_api_management_diagnostic" "all_apis" {
  for_each = {
    applicationinsights = azurerm_api_management_logger.insights.id
  }

  identifier               = each.key
  api_management_name      = azurerm_api_management.this.name
  resource_group_name      = azurerm_resource_group.this.name
  api_management_logger_id = each.value

  sampling_percentage       = 100
  always_log_errors         = true
  log_client_ip             = false
  verbosity                 = "verbose"
  http_correlation_protocol = "W3C"

  frontend_request {
    body_bytes     = 0
    headers_to_log = []
  }
  frontend_response {
    body_bytes     = 0
    headers_to_log = []
  }
  backend_request {
    body_bytes     = 0
    headers_to_log = []
  }
  backend_response {
    body_bytes     = 0
    headers_to_log = []
  }
}

# The installed AzureRM provider does not expose the diagnostic's metrics flag.
resource "azapi_update_resource" "apim_insights_metrics" {
  type        = "Microsoft.ApiManagement/service/diagnostics@2024-05-01"
  resource_id = azurerm_api_management_diagnostic.all_apis["applicationinsights"].id

  body = {
    properties = {
      metrics = true
    }
  }

  depends_on = [azapi_update_resource.insights_metric_dimensions]

  lifecycle {
    replace_triggered_by = [azurerm_api_management_diagnostic.all_apis["applicationinsights"]]
  }
}

# Enabling the platform diagnostic setting creates this built-in APIM diagnostic.
# Update it after the export is enabled rather than trying to create it again.
resource "azapi_update_resource" "azuremonitor" {
  type        = "Microsoft.ApiManagement/service/diagnostics@2024-05-01"
  resource_id = "${azurerm_api_management.this.id}/diagnostics/azuremonitor"

  body = {
    properties = {
      loggerId    = "${azurerm_api_management.this.id}/loggers/azuremonitor"
      alwaysLog   = "allErrors"
      logClientIp = false
      verbosity   = "verbose"
      sampling = {
        samplingType = "fixed"
        percentage   = 100
      }
      frontend = {
        request = {
          body    = { bytes = 0 }
          headers = []
        }
        response = {
          body    = { bytes = 0 }
          headers = []
        }
      }
      backend = {
        request = {
          body    = { bytes = 0 }
          headers = []
        }
        response = {
          body    = { bytes = 0 }
          headers = []
        }
      }
    }
  }

  depends_on = [azurerm_monitor_diagnostic_setting.apim]
}
