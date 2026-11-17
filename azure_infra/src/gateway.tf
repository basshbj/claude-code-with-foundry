resource "azurerm_api_management_backend" "claude" {
  name                = "foundry-claude"
  resource_group_name = azurerm_resource_group.this.name
  api_management_name = azurerm_api_management.this.name
  protocol            = "http"
  url                 = azurerm_api_management_api.claude.service_url
}

resource "azurerm_api_management_api" "claude" {
  name                  = "claude-messages"
  resource_group_name   = azurerm_resource_group.this.name
  api_management_name   = azurerm_api_management.this.name
  revision              = "1"
  display_name          = "Claude Messages API"
  path                  = "anthropic"
  protocols             = ["https"]
  subscription_required = false
  service_url           = "https://${azurerm_cognitive_account.this.custom_subdomain_name}.services.ai.azure.com/anthropic"

  lifecycle {
    precondition {
      condition     = length(var.allowed_user_emails) + length(var.allowed_group_names) + length(var.allowed_principal_object_ids) > 0
      error_message = "Authorize at least one user email, security group name, or principal object ID."
    }
  }
}

resource "azurerm_api_management_api_operation" "claude" {
  for_each = {
    messages     = "/v1/messages"
    count-tokens = "/v1/messages/count_tokens"
  }

  operation_id        = each.key
  api_name            = azurerm_api_management_api.claude.name
  api_management_name = azurerm_api_management.this.name
  resource_group_name = azurerm_resource_group.this.name
  display_name        = each.key
  method              = "POST"
  url_template        = each.value
}

resource "azurerm_api_management_api_policy" "claude" {
  api_name            = azurerm_api_management_api.claude.name
  api_management_name = azurerm_api_management.this.name
  resource_group_name = azurerm_resource_group.this.name
  xml_content = templatefile("${path.module}/policies/claude.xml.tftpl", {
    tenant_id           = var.tenant_id
    gateway_client_id   = azuread_application.gateway.client_id
    gateway_role        = local.gateway_role_value
    allowed_models      = jsonencode(jsonencode(sort(tolist(local.model_names))))
    requests_per_minute = var.requests_per_minute
    tokens_per_minute   = var.tokens_per_minute
    monthly_token_quota = var.monthly_token_quota
    backend_id          = azurerm_api_management_backend.claude.name
  })

  depends_on = [
    azuread_application_identifier_uri.gateway,
    azuread_application_pre_authorized.azure_cli,
    azuread_app_role_assignment.gateway,
    azurerm_api_management_api_operation.claude,
    azurerm_role_assignment.apim_inference,
    azurerm_role_assignment.foundry_user,
    azurerm_role_assignment.cognitive_services_user,
    azapi_update_resource.apim_insights_metrics,
    azapi_resource.claude,
  ]
}
