# --------
# Identity
# --------

data "azuread_client_config" "current" {}

data "azuread_user" "allowed" {
  for_each = toset([for email in var.allowed_user_emails : lower(trimspace(email))])
  mail     = each.value
}

data "azuread_group" "allowed" {
  for_each         = toset([for name in var.allowed_group_names : trimspace(name)])
  display_name     = each.value
  security_enabled = true
}

data "azuread_application" "azure_cli" {
  display_name = "Microsoft Azure CLI"
}

locals {
  gateway_scope_id   = uuidv5("dns", "${var.tenant_id}.${var.name_prefix}.gateway.access_as_user")
  gateway_role_id    = uuidv5("dns", "${var.tenant_id}.${var.name_prefix}.gateway.Claude.Standard")
  gateway_role_value = "Claude.Standard"

  allowed_principal_ids = toset(concat(
    [for user in data.azuread_user.allowed : lower(user.object_id)],
    [for group in data.azuread_group.allowed : lower(group.object_id)],
  ))

}

# Entra ID App Registration
resource "azuread_application" "app_gateway" {
  display_name     = "${var.name_prefix}-gateway"
  sign_in_audience = "AzureADMyOrg"
  owners           = [data.azuread_client_config.current.object_id]

  api {
    requested_access_token_version = 2

    oauth2_permission_scope {
      id                         = local.gateway_scope_id
      value                      = "access_as_user"
      type                       = "User"
      enabled                    = true
      admin_consent_display_name = "Access the Claude gateway"
      admin_consent_description  = "Call the Claude gateway on behalf of an assigned user."
      user_consent_display_name  = "Access the Claude gateway"
      user_consent_description   = "Call the Claude gateway on your behalf."
    }
  }

  app_role {
    id                   = local.gateway_role_id
    value                = local.gateway_role_value
    display_name         = "Claude Standard"
    description          = "Invoke the Claude gateway within the configured request and token limits."
    allowed_member_types = ["User", "Application"]
    enabled              = true
  }

  lifecycle {
    ignore_changes = [identifier_uris]
  }
}

resource "azuread_application_identifier_uri" "gateway" {
  application_id = azuread_application.app_gateway.id
  identifier_uri = "api://${azuread_application.app_gateway.client_id}"
}

resource "azuread_service_principal" "gateway" {
  client_id                    = azuread_application.app_gateway.client_id
  app_role_assignment_required = true
  owners                       = [data.azuread_client_config.current.object_id]
}

resource "azuread_application_pre_authorized" "app_auth_azure_cli" {
  application_id = azuread_application.app_gateway.id
  authorized_client_id = data.azuread_application.azure_cli.client_id
  permission_ids       = [local.gateway_scope_id]
}


resource "azuread_app_role_assignment" "gateway" {
  for_each = local.allowed_principal_ids

  app_role_id         = local.gateway_role_id
  principal_object_id = each.value
  resource_object_id  = azuread_service_principal.gateway.object_id
}

# Role - Cognitive Services User for APIM
resource "azurerm_role_assignment" "apim_inference" {
  scope                = azurerm_cognitive_account.foundry.id
  role_definition_name = "Cognitive Services User"
  principal_id         = azurerm_api_management.apim.identity[0].principal_id
  principal_type       = "ServicePrincipal"
}

# Role - Foundry User for Allowed Users
resource "azurerm_role_assignment" "foundry_user" {
  for_each = local.allowed_principal_ids

  scope = azurerm_cognitive_account.foundry.id
  role_definition_name = "Foundry User"
  principal_id       = each.value
}

# Role - Cognitive Services User for Allowed Users
resource "azurerm_role_assignment" "cognitive_services_user" {
  for_each = local.allowed_principal_ids

  scope                = azurerm_cognitive_account.foundry.id
  role_definition_name = "Cognitive Services User"
  principal_id         = each.value
}
