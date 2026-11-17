# -------------
# APIM - Set up
# -------------

# API Backend
resource "azurerm_api_management_backend" "apim_backend" {
  name                = "foundry-claude"
  resource_group_name = azurerm_resource_group.rg.name
  api_management_name = azurerm_api_management.apim.name
  protocol            = "http"
  url                 = azurerm_api_management_api.apim_api.service_url
}

# Claude API
resource "azurerm_api_management_api" "apim_api" {
  name                  = "claude-messages"
  resource_group_name   = azurerm_resource_group.rg.name
  api_management_name   = azurerm_api_management.apim.name
  revision              = "1"
  display_name          = "Claude Messages API"
  path                  = "anthropic"
  protocols             = ["https"]
  subscription_required = false
  service_url           = "https://${azurerm_cognitive_account.foundry.custom_subdomain_name}.services.ai.azure.com/anthropic"

  lifecycle {
    precondition {
      condition     = length(var.allowed_user_emails) + length(var.allowed_group_names) > 0
      error_message = "Authorize at least one user email or security group name"
    }
  }
}

# Claude API - Methods
resource "azurerm_api_management_api_operation" "apim_api_operation" {
  for_each = {
    messages = {
      path   = "/v1/messages"
      method = "POST"
    }
    count-tokens = {
      path   = "/v1/messages/count_tokens"
      method = "POST"
    }
  }

  operation_id        = each.key
  api_name            = azurerm_api_management_api.apim_api.name
  api_management_name = azurerm_api_management.apim.name
  resource_group_name = azurerm_resource_group.rg.name
  display_name        = each.key
  method              = each.value.method
  url_template        = each.value.path
}

# Claude API Policy
resource "azurerm_api_management_api_policy" "apim_policy" {
  api_name            = azurerm_api_management_api.apim_api.name
  api_management_name = azurerm_api_management.apim.name
  resource_group_name = azurerm_resource_group.rg.name
  xml_content = templatefile("${path.module}/policies/claude.xml.tftpl", {
    tenant_id           = var.tenant_id
    gateway_client_id   = azuread_application.app_gateway.client_id
    gateway_role        = local.gateway_role_value
    allowed_models      = jsonencode(jsonencode(sort(tolist(local.model_names))))
    requests_per_minute = var.requests_per_minute
    tokens_per_minute   = var.tokens_per_minute
    monthly_token_quota = var.monthly_token_quota
    backend_id          = azurerm_api_management_backend.apim_backend.name
  })

  depends_on = [
    azuread_application_identifier_uri.gateway,
    azuread_application_pre_authorized.app_auth_azure_cli,
    azuread_app_role_assignment.gateway,
    azurerm_api_management_api_operation.apim_api_operation,
    azurerm_role_assignment.apim_inference,
    azurerm_role_assignment.foundry_user,
    azurerm_role_assignment.cognitive_services_user,
    azapi_update_resource.apim_insights_metrics,
    azapi_resource.claude,
  ]
}
