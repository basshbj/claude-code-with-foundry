output "resource_group_name" {
  description = "Newly created resource group."
  value       = azurerm_resource_group.rg.name
}

output "foundry_resource_name" {
  description = "Microsoft Foundry resource hosting the Claude deployments."
  value       = azurerm_cognitive_account.foundry.name
}

output "foundry_project_id" {
  description = "Child Foundry project connected to Application Insights."
  value       = azurerm_cognitive_account_project.foundry_prj.id
}

output "foundry_project_endpoint" {
  description = "Foundry project endpoint; Claude inference uses the separate Anthropic endpoint."
  value       = "https://${azurerm_cognitive_account.foundry.custom_subdomain_name}.services.ai.azure.com/api/projects/${azurerm_cognitive_account_project.foundry_prj.name}"
}

output "foundry_anthropic_base_url" {
  description = "Direct Foundry Anthropic endpoint used by APIM."
  value       = azurerm_api_management_api.apim_api.service_url
}

output "model_deployment_names" {
  description = "Allowed Claude Code model deployment names."
  value       = sort(tolist(local.model_names))
}

output "claude_code_connection" {
  description = "Non-secret gateway environment settings. Configure the Entra token helper; native Foundry mode cannot request the gateway app audience."
  value = {
    CLAUDE_CODE_USE_FOUNDRY = "0"
    ANTHROPIC_BASE_URL      = "${azurerm_api_management.apim.gateway_url}/anthropic"
    AZURE_TENANT_ID         = var.tenant_id
    CLAUDE_GATEWAY_SCOPE    = "${azuread_application_identifier_uri.gateway.identifier_uri}/.default"
  }
}

output "gateway_application_client_id" {
  description = "Gateway Entra app registration's client ID; also the audience of its v2 access tokens."
  value       = azuread_application.app_gateway.client_id
}

output "gateway_application_id_uri" {
  description = "Gateway Expose an API identifier URI. Its delegated permission is access_as_user."
  value       = azuread_application_identifier_uri.gateway.identifier_uri
}

output "gateway_enterprise_application_object_id" {
  description = "Gateway enterprise application (service principal) carrying the caller app-role assignments."
  value       = azuread_service_principal.gateway.object_id
}

output "apim_managed_identity_principal_id" {
  description = "APIM system-assigned identity used to authenticate to Foundry and publish telemetry."
  value       = azurerm_api_management.apim.identity[0].principal_id
}

output "application_insights_id" {
  description = "Application Insights shared by APIM and the Foundry project."
  value       = azurerm_application_insights.app_insights.id
}

output "log_analytics_workspace_id" {
  description = "Workspace containing platform logs and Application Insights telemetry."
  value       = azurerm_log_analytics_workspace.logana.id
}
