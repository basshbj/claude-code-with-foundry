mock_provider "azurerm" {
  mock_resource "azurerm_api_management" {
    defaults = {
      id          = "/subscriptions/11111111-1111-1111-1111-111111111111/resourceGroups/test-rg/providers/Microsoft.ApiManagement/service/test-apim"
      gateway_url = "https://test-apim.azure-api.net"
      identity = {
        type         = "SystemAssigned"
        principal_id = "22222222-2222-2222-2222-222222222222"
        tenant_id    = "33333333-3333-3333-3333-333333333333"
      }
    }
  }

  mock_resource "azurerm_cognitive_account" {
    defaults = {
      id = "/subscriptions/11111111-1111-1111-1111-111111111111/resourceGroups/test-rg/providers/Microsoft.CognitiveServices/accounts/test-foundry"
      identity = {
        type         = "SystemAssigned"
        principal_id = "44444444-4444-4444-4444-444444444444"
        tenant_id    = "33333333-3333-3333-3333-333333333333"
      }
    }
  }

  mock_resource "azurerm_cognitive_account_project" {
    defaults = {
      id = "/subscriptions/11111111-1111-1111-1111-111111111111/resourceGroups/test-rg/providers/Microsoft.CognitiveServices/accounts/test-foundry/projects/test-project"
      identity = {
        type         = "SystemAssigned"
        principal_id = "55555555-5555-5555-5555-555555555555"
        tenant_id    = "33333333-3333-3333-3333-333333333333"
      }
    }
  }

  mock_resource "azurerm_log_analytics_workspace" {
    defaults = {
      id = "/subscriptions/11111111-1111-1111-1111-111111111111/resourceGroups/test-rg/providers/Microsoft.OperationalInsights/workspaces/test-logs"
    }
  }

  mock_resource "azurerm_application_insights" {
    defaults = {
      id                = "/subscriptions/11111111-1111-1111-1111-111111111111/resourceGroups/test-rg/providers/Microsoft.Insights/components/test-insights"
      connection_string = "InstrumentationKey=66666666-6666-6666-6666-666666666666;IngestionEndpoint=https://eastus2-0.in.applicationinsights.azure.com/"
    }
  }

  mock_resource "azurerm_api_management_logger" {
    defaults = {
      id = "/subscriptions/11111111-1111-1111-1111-111111111111/resourceGroups/test-rg/providers/Microsoft.ApiManagement/service/test-apim/loggers/application-insights"
    }
  }

  mock_resource "azurerm_api_management_diagnostic" {
    defaults = {
      id = "/subscriptions/11111111-1111-1111-1111-111111111111/resourceGroups/test-rg/providers/Microsoft.ApiManagement/service/test-apim/diagnostics/applicationinsights"
    }
  }
}

mock_provider "azuread" {
  mock_data "azuread_client_config" {
    defaults = {
      object_id = "eeeeeeee-eeee-eeee-eeee-eeeeeeeeeeee"
    }
  }

  mock_resource "azuread_application" {
    defaults = {
      id        = "/applications/77777777-7777-7777-7777-777777777777"
      object_id = "77777777-7777-7777-7777-777777777777"
      client_id = "12121212-1212-1212-1212-121212121212"
    }
  }

  mock_resource "azuread_service_principal" {
    defaults = {
      id        = "/servicePrincipals/dddddddd-dddd-dddd-dddd-dddddddddddd"
      object_id = "dddddddd-dddd-dddd-dddd-dddddddddddd"
    }
  }

  mock_data "azuread_user" {
    defaults = {
      object_id = "99999999-9999-9999-9999-999999999999"
    }
  }

  mock_data "azuread_group" {
    defaults = {
      object_id = "aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa"
      members = [
        "BBBBBBBB-BBBB-BBBB-BBBB-BBBBBBBBBBBB",
        "cccccccc-cccc-cccc-cccc-cccccccccccc",
      ]
    }
  }
}

mock_provider "azapi" {}

variables {
  tags                      = {}
  apim_sku_name             = "StandardV2_1"
  allowed_user_emails       = ["developer@example.com"]
  allowed_group_names       = []
  requests_per_minute       = 60
  tokens_per_minute         = 50000
  monthly_token_quota       = 5000000
  log_retention_days        = 30
  model_deployment_sku_name = "GlobalStandard"
  model_deployment_capacity = 1
  subscription_id           = "11111111-1111-1111-1111-111111111111"
  tenant_id                 = "33333333-3333-3333-3333-333333333333"
  name_prefix               = "claude-test"
  location                  = "eastus2"
  publisher_name            = "Test"
  publisher_email           = "test@example.com"
  claude_organization_name  = "Test organization"
  claude_country_code       = "US"
  claude_industry           = "technology"
  models = [
    "claude-opus-4-8",
    "claude-opus-5-5",
    "claude-haiku-4-5",
    "claude-sonnet-5",
    "claude-opus-5",
    "claude-sonnet-5-5",
    "claude-haiku-5-5",
  ]
}

run "public_foundry_project_and_claude_models" {
  command = apply

  assert {
    condition = (
      azurerm_resource_group.rg.name == "claude-test-rg" &&
      azurerm_api_management.apim.sku_name == "StandardV2_1" &&
      azurerm_api_management.apim.virtual_network_type == "None" &&
      azurerm_api_management.apim.public_network_access_enabled &&
      !azurerm_cognitive_account.foundry.local_auth_enabled &&
      azurerm_cognitive_account.foundry.kind == "AIServices" &&
      azurerm_cognitive_account.foundry.project_management_enabled &&
      azurerm_cognitive_account.foundry.public_network_access_enabled &&
      one(azurerm_cognitive_account.foundry.network_acls).default_action == "Allow" &&
      one(azurerm_cognitive_account.foundry.network_acls).bypass == "None"
    )
    error_message = "Preserve public Standard v2/Foundry networking and disable backend key authentication."
  }

  assert {
    condition = (
      azurerm_cognitive_account_project.foundry_prj.cognitive_account_id == azurerm_cognitive_account.foundry.id &&
      azurerm_cognitive_account_project.foundry_prj.name == "claude-test-project" &&
      azurerm_cognitive_account_project.foundry_prj.identity[0].type == "SystemAssigned" &&
      azurerm_cognitive_account.foundry.identity[0].type == "SystemAssigned" &&
      output.foundry_project_id == azurerm_cognitive_account_project.foundry_prj.id
    )
    error_message = "Create a child Foundry project with its own managed identity, not just a project-enabled account."
  }

  assert {
    condition = (
      toset(keys(azapi_resource.claude)) == toset([
        "claude-opus-4-8", "claude-opus-5-5", "claude-haiku-4-5", "claude-sonnet-5",
        "claude-opus-5", "claude-sonnet-5-5", "claude-haiku-5-5",
      ]) &&
      alltrue([for name, deployment in azapi_resource.claude :
        deployment.parent_id == azurerm_cognitive_account.foundry.id &&
        deployment.body.properties.model.format == "Anthropic" &&
        deployment.body.properties.model.name == name &&
        deployment.body.properties.model.version == "2" &&
        deployment.body.properties.versionUpgradeOption == "NoAutoUpgrade" &&
        deployment.body.sku.name == "GlobalStandard" &&
        deployment.body.properties.modelProviderData.organizationName == "Test organization" &&
        deployment.body.properties.modelProviderData.countryCode == "US" &&
        deployment.body.properties.modelProviderData.industry == "technology" &&
        deployment.locks == tolist([azurerm_cognitive_account.foundry.id])
      ])
    )
    error_message = "Deploy all seven Claude models pinned to Hosted on Azure, with Marketplace attestations and serialized account updates."
  }

  assert {
    condition = (
      azurerm_role_assignment.foundry_user["99999999-9999-9999-9999-999999999999"].scope == azurerm_cognitive_account.foundry.id &&
      azurerm_role_assignment.foundry_user["99999999-9999-9999-9999-999999999999"].role_definition_name == "Foundry User" &&
      azurerm_role_assignment.cognitive_services_user["99999999-9999-9999-9999-999999999999"].scope == azurerm_cognitive_account.foundry.id &&
      azurerm_role_assignment.cognitive_services_user["99999999-9999-9999-9999-999999999999"].role_definition_name == "Cognitive Services User"
    )
    error_message = "Grant configured principals Foundry User and Cognitive Services User on the account."
  }
}

run "entra_messages_and_token_counting" {
  command = apply

  assert {
    condition = (
      !azurerm_api_management_api.apim_api.subscription_required &&
      azurerm_api_management_api.apim_api.path == "anthropic" &&
      azurerm_api_management_api.apim_api.service_url == "https://claude-test-foundry.services.ai.azure.com/anthropic" &&
      azurerm_api_management_backend.apim_backend.url == azurerm_api_management_api.apim_api.service_url &&
      azurerm_api_management_backend.apim_backend.protocol == "http" &&
      toset(keys(azurerm_api_management_api_operation.apim_api_operation)) == toset(["messages", "count-tokens", "models"]) &&
      azurerm_api_management_api_operation.apim_api_operation["messages"].url_template == "/v1/messages" &&
      azurerm_api_management_api_operation.apim_api_operation["messages"].method == "POST" &&
      azurerm_api_management_api_operation.apim_api_operation["count-tokens"].url_template == "/v1/messages/count_tokens" &&
      azurerm_api_management_api_operation.apim_api_operation["count-tokens"].method == "POST" &&
      azurerm_api_management_api_operation.apim_api_operation["models"].url_template == "/v1/models" &&
      azurerm_api_management_api_operation.apim_api_operation["models"].method == "GET"
    )
    error_message = "Expose the native Anthropic Messages, token-counting, and model-listing API paths with their expected methods and without subscription keys."
  }

  assert {
    condition = (
      strcontains(azurerm_api_management_api_policy.apim_policy.xml_content, "validate-azure-ad-token tenant-id=\"33333333-3333-3333-3333-333333333333\"") &&
      strcontains(azurerm_api_management_api_policy.apim_policy.xml_content, "<audience>12121212-1212-1212-1212-121212121212</audience>") &&
      !strcontains(azurerm_api_management_api_policy.apim_policy.xml_content, "<audience>https://ai.azure.com") &&
      !strcontains(azurerm_api_management_api_policy.apim_policy.xml_content, "<audience>https://cognitiveservices.azure.com") &&
      strcontains(azurerm_api_management_api_policy.apim_policy.xml_content, "<authentication-managed-identity resource=\"https://ai.azure.com\" ignore-error=\"false\" />") &&
      strcontains(azurerm_api_management_api_policy.apim_policy.xml_content, "<set-backend-service backend-id=\"foundry-claude\"") &&
      !strcontains(azurerm_api_management_api_policy.apim_policy.xml_content, "<set-header name=\"Authorization\"") &&
      !strcontains(azurerm_api_management_api_policy.apim_policy.xml_content, "Codex.Access") &&
      !strcontains(azurerm_api_management_api_policy.apim_policy.xml_content, "<client-application-ids>") &&
      strcontains(azurerm_api_management_api_policy.apim_policy.xml_content, "buffer-response=\"false\"") &&
      strcontains(azurerm_api_management_api_policy.apim_policy.xml_content, "preserveContent: true") &&
      strcontains(azurerm_api_management_api_policy.apim_policy.xml_content, "<set-header name=\"x-api-key\" exists-action=\"delete\"") &&
      strcontains(azurerm_api_management_api_policy.apim_policy.xml_content, "string.IsNullOrEmpty") &&
      strcontains(azurerm_api_management_api_policy.apim_policy.xml_content, "rate-limit-by-key") &&
      !strcontains(azurerm_api_management_api_policy.apim_policy.xml_content, "exists-action=\"skip\"") &&
      !strcontains(azurerm_api_management_api_policy.apim_policy.xml_content, "{{foundry-api-key}}") &&
      strcontains(azurerm_api_management_api_policy.apim_policy.xml_content, "Claims[\"roles\"].Contains(\"Claude.Standard\")") &&
      can(regex("(?s)<validate-azure-ad-token.*required Claude gateway app role is missing.*<authentication-managed-identity", azurerm_api_management_api_policy.apim_policy.xml_content))
    )
    error_message = "Validate and authorize the caller before replacing its token with APIM's managed identity; never use key auth or buffer streams."
  }

  assert {
    condition = (
      azurerm_role_assignment.apim_inference.scope == azurerm_cognitive_account.foundry.id &&
      azurerm_role_assignment.apim_inference.role_definition_name == "Cognitive Services User" &&
      azurerm_role_assignment.apim_inference.principal_type == "ServicePrincipal" &&
      azurerm_role_assignment.apim_inference.principal_id == azurerm_api_management.apim.identity[0].principal_id
    )
    error_message = "The backend identity needs Foundry data-plane access, but arbitrary tenant users must not gain access through it."
  }

  assert {
    condition = (
      output.claude_code_connection.ANTHROPIC_BASE_URL == "https://test-apim.azure-api.net/anthropic" &&
      output.claude_code_connection.CLAUDE_CODE_USE_FOUNDRY == "0" &&
      output.claude_code_connection.CLAUDE_GATEWAY_SCOPE == "api://12121212-1212-1212-1212-121212121212/.default" &&
      output.foundry_anthropic_base_url == azurerm_api_management_api.apim_api.service_url
    )
    error_message = "Claude Code handoff must use APIM's Anthropic base URL exactly once."
  }
}

run "telemetry_is_connected_and_unsampled" {
  command = apply

  assert {
    condition = (
      azurerm_application_insights.app_insights.workspace_id == azurerm_log_analytics_workspace.logana.id &&
      azurerm_application_insights.app_insights.sampling_percentage == 100 &&
      !azurerm_application_insights.app_insights.local_authentication_enabled &&
      azapi_resource.project_insights.parent_id == azurerm_cognitive_account_project.foundry_prj.id &&
      azapi_resource.project_insights.body.properties.category == "AppInsights" &&
      azapi_resource.project_insights.body.properties.authType == "ProjectManagedIdentity" &&
      azapi_resource.project_insights.body.properties.target == azurerm_application_insights.app_insights.id &&
      azapi_resource.project_insights.body.properties.metadata.ApplicationInsightsConnectionString == azurerm_application_insights.app_insights.connection_string &&
      azurerm_api_management_logger.insights.application_insights[0].identity_client_id == "SystemAssigned" &&
      azurerm_api_management_logger.insights.application_insights[0].connection_string == azurerm_application_insights.app_insights.connection_string &&
      azapi_update_resource.insights_metric_dimensions.resource_id == azurerm_application_insights.app_insights.id &&
      azapi_update_resource.insights_metric_dimensions.body.properties.CustomMetricsOptedInType == "WithDimensions" &&
      azapi_update_resource.apim_insights_metrics.resource_id == azurerm_api_management_diagnostic.all_apis["applicationinsights"].id &&
      azapi_update_resource.apim_insights_metrics.body.properties.metrics
    )
    error_message = "Connect both APIM and the child Foundry project to workspace-based Application Insights using managed identities."
  }

  assert {
    condition = (
      azurerm_role_assignment.telemetry_publisher["apim"].principal_id == azurerm_api_management.apim.identity[0].principal_id &&
      azurerm_role_assignment.telemetry_publisher["project"].principal_id == azurerm_cognitive_account_project.foundry_prj.identity[0].principal_id &&
      azurerm_role_assignment.telemetry_publisher["foundry"].principal_id == azurerm_cognitive_account.foundry.identity[0].principal_id &&
      alltrue([for assignment in azurerm_role_assignment.telemetry_publisher :
        assignment.scope == azurerm_application_insights.app_insights.id &&
        assignment.role_definition_name == "Monitoring Metrics Publisher"
      ]) &&
      azurerm_role_assignment.logs_reader["99999999-9999-9999-9999-999999999999"].scope == azurerm_log_analytics_workspace.logana.id &&
      azurerm_role_assignment.insights_reader["99999999-9999-9999-9999-999999999999"].scope == azurerm_application_insights.app_insights.id
    )
    error_message = "Telemetry identities need scoped publishing permissions and configured users/groups need log read access."
  }

  assert {
    condition = (
      one(azurerm_monitor_diagnostic_setting.apim_diagnostics.enabled_log).category_group == "allLogs" &&
      one(azurerm_monitor_diagnostic_setting.foundry_diagnostics.enabled_log).category_group == "allLogs" &&
      one(azurerm_monitor_diagnostic_setting.apim_diagnostics.enabled_metric).category == "AllMetrics" &&
      one(azurerm_monitor_diagnostic_setting.foundry_diagnostics.enabled_metric).category == "AllMetrics" &&
      azurerm_monitor_diagnostic_setting.apim_diagnostics.log_analytics_destination_type == "Dedicated" &&
      azurerm_monitor_diagnostic_setting.apim_diagnostics.log_analytics_workspace_id == azurerm_log_analytics_workspace.logana.id &&
      azurerm_monitor_diagnostic_setting.foundry_diagnostics.log_analytics_workspace_id == azurerm_log_analytics_workspace.logana.id &&
      toset(keys(azurerm_api_management_diagnostic.all_apis)) == toset(["applicationinsights"]) &&
      azurerm_api_management_diagnostic.all_apis["applicationinsights"].api_management_logger_id == azurerm_api_management_logger.insights.id
    )
    error_message = "Export all platform logs/metrics and enable both Azure Monitor and Application Insights request diagnostics."
  }

  assert {
    condition = alltrue([for diagnostic in azurerm_api_management_diagnostic.all_apis :
      diagnostic.sampling_percentage == 100 &&
      diagnostic.always_log_errors &&
      diagnostic.verbosity == "verbose" &&
      diagnostic.http_correlation_protocol == "W3C" &&
      diagnostic.frontend_request[0].body_bytes == 0 &&
      diagnostic.frontend_response[0].body_bytes == 0 &&
      diagnostic.backend_request[0].body_bytes == 0 &&
      diagnostic.backend_response[0].body_bytes == 0 &&
      length(diagnostic.frontend_request[0].headers_to_log) == 0 &&
      length(diagnostic.frontend_response[0].headers_to_log) == 0 &&
      length(diagnostic.backend_request[0].headers_to_log) == 0 &&
      length(diagnostic.backend_response[0].headers_to_log) == 0
    ])
    error_message = "Log every request and error without capturing bodies or credentials in any pipeline stage."
  }
}

run "update_builtin_azuremonitor_diagnostic" {
  command = apply

  assert {
    condition = (
      !contains(keys(azurerm_api_management_diagnostic.all_apis), "azuremonitor") &&
      azapi_update_resource.azuremonitor.type == "Microsoft.ApiManagement/service/diagnostics@2024-05-01" &&
      azapi_update_resource.azuremonitor.resource_id == "${azurerm_api_management.apim.id}/diagnostics/azuremonitor" &&
      azapi_update_resource.azuremonitor.body.properties.loggerId == "${azurerm_api_management.apim.id}/loggers/azuremonitor"
    )
    error_message = "Update APIM's pre-existing Azure Monitor diagnostic instead of creating a conflicting AzureRM resource."
  }

  assert {
    condition = (
      !contains(keys(azapi_update_resource.azuremonitor.body.properties), "httpCorrelationProtocol") &&
      azurerm_api_management_diagnostic.all_apis["applicationinsights"].http_correlation_protocol == "W3C"
    )
    error_message = "HTTP correlation is Application Insights-only; omit it entirely from the Azure Monitor diagnostic."
  }

  assert {
    condition = (
      azapi_update_resource.azuremonitor.body.properties.sampling.samplingType == "fixed" &&
      azapi_update_resource.azuremonitor.body.properties.sampling.percentage == 100 &&
      azapi_update_resource.azuremonitor.body.properties.alwaysLog == "allErrors" &&
      !azapi_update_resource.azuremonitor.body.properties.logClientIp &&
      azapi_update_resource.azuremonitor.body.properties.verbosity == "verbose" &&
      alltrue([for pipeline in [
        azapi_update_resource.azuremonitor.body.properties.frontend,
        azapi_update_resource.azuremonitor.body.properties.backend,
        ] :
        pipeline.request.body.bytes == 0 &&
        pipeline.response.body.bytes == 0 &&
        length(pipeline.request.headers) == 0 &&
        length(pipeline.response.headers) == 0
      ])
    )
    error_message = "Preserve 100% Azure Monitor request sampling, error logging, and payload/credential exclusions."
  }
}

run "normalized_models_and_capacity" {
  command = apply

  variables {
    models                    = [" Claude-Opus-5-5 ", "claude-haiku-4-5"]
    model_deployment_sku_name = "DataZoneStandard"
    model_deployment_capacity = 3
  }

  assert {
    condition = (
      length(azapi_resource.claude) == 2 &&
      azapi_resource.claude["claude-opus-5-5"].body.properties.model.name == "claude-opus-5-5" &&
      azapi_resource.claude["claude-opus-5-5"].body.sku.name == "DataZoneStandard" &&
      azapi_resource.claude["claude-haiku-4-5"].body.sku.capacity == 3 &&
      output.model_deployment_names == tolist(["claude-haiku-4-5", "claude-opus-5-5"]) &&
      strcontains(azurerm_api_management_api_policy.apim_policy.xml_content, jsonencode(jsonencode(["claude-haiku-4-5", "claude-opus-5-5"])))
    )
    error_message = "Normalize Claude deployment names and keep the gateway allowlist, capacity, and plan consistent."
  }
}

run "authorize_by_email_and_group_name" {
  command = apply

  variables {
    allowed_user_emails = [" Developer@Example.com "]
    allowed_group_names = [" Claude Developers "]
  }

  assert {
    condition = (
      data.azuread_user.allowed["developer@example.com"].mail == "developer@example.com" &&
      data.azuread_group.allowed["Claude Developers"].display_name == "Claude Developers" &&
      data.azuread_group.allowed["Claude Developers"].security_enabled &&
      toset(keys(azurerm_role_assignment.foundry_user)) == toset([
        "99999999-9999-9999-9999-999999999999",
        "aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa",
      ]) &&
      toset(keys(azurerm_role_assignment.cognitive_services_user)) == toset(keys(azurerm_role_assignment.foundry_user)) &&
      toset(keys(azuread_app_role_assignment.gateway)) == toset(keys(azurerm_role_assignment.foundry_user))
    )
    error_message = "Resolve normalized emails and security group names and assign both Foundry roles."
  }
}

run "gateway_app_registration_and_assignments" {
  command = apply

  assert {
    condition = (
      azuread_application.app_gateway.display_name == "claude-test-gateway" &&
      azuread_application.app_gateway.sign_in_audience == "AzureADMyOrg" &&
      one(azuread_application.app_gateway.api).requested_access_token_version == 2 &&
      one(one(azuread_application.app_gateway.api).oauth2_permission_scope).value == "access_as_user" &&
      one(one(azuread_application.app_gateway.api).oauth2_permission_scope).type == "User" &&
      one(one(azuread_application.app_gateway.api).oauth2_permission_scope).enabled &&
      length(azuread_application.app_gateway.password) == 0 &&
      azuread_application_identifier_uri.gateway.identifier_uri == "api://${azuread_application.app_gateway.client_id}" &&
      azuread_application_identifier_uri.gateway.application_id == azuread_application.app_gateway.id &&
      azuread_application_pre_authorized.app_auth_azure_cli.application_id == azuread_application.app_gateway.id &&
      azuread_application_pre_authorized.app_auth_azure_cli.permission_ids == toset([one(one(azuread_application.app_gateway.api).oauth2_permission_scope).id])
    )
    error_message = "Create a single-tenant gateway API registration with v2 tokens, an exposed delegated scope, Azure CLI preauthorization, and no secret."
  }

  assert {
    condition = (
      azuread_service_principal.gateway.client_id == azuread_application.app_gateway.client_id &&
      azuread_service_principal.gateway.app_role_assignment_required &&
      one(azuread_application.app_gateway.app_role).value == "Claude.Standard" &&
      one(azuread_application.app_gateway.app_role).allowed_member_types == toset(["User", "Application"]) &&
      azuread_app_role_assignment.gateway["99999999-9999-9999-9999-999999999999"].app_role_id == one(azuread_application.app_gateway.app_role).id &&
      azuread_app_role_assignment.gateway["99999999-9999-9999-9999-999999999999"].resource_object_id == azuread_service_principal.gateway.object_id &&
      azuread_app_role_assignment.gateway["99999999-9999-9999-9999-999999999999"].principal_object_id == "99999999-9999-9999-9999-999999999999" &&
      output.gateway_application_client_id == azuread_application.app_gateway.client_id &&
      output.gateway_enterprise_application_object_id == azuread_service_principal.gateway.object_id
    )
    error_message = "Create the enterprise application, require assignment, and grant the gateway app role to the configured principals."
  }
}

run "token_governance_uses_caller_identity_and_message_operation" {
  command = apply

  variables {
    tokens_per_minute   = 120000
    monthly_token_quota = 9000000
  }

  assert {
    condition = (
      strcontains(azurerm_api_management_api_policy.apim_policy.xml_content, "tokens-per-minute=\"120000\" token-quota=\"9000000\" token-quota-period=\"Monthly\"") &&
      strcontains(azurerm_api_management_api_policy.apim_policy.xml_content, "remaining-quota-tokens-header-name=\"x-token-quota-remaining\"") &&
      can(regex("(?s)context.Operation.Id == \"messages\".*<llm-token-limit.*<llm-emit-token-metric namespace=\"claudecode\">.*name=\"UserId\".*name=\"Model\".*</when>", azurerm_api_management_api_policy.apim_policy.xml_content)) &&
      length(regexall("counter-key='@\\(\\(string\\)context.Variables\\[\"caller-id\"\\]\\)'", azurerm_api_management_api_policy.apim_policy.xml_content)) == 2
    )
    error_message = "Meter and limit Messages tokens per original caller, not the shared backend identity or the count_tokens response."
  }
}

run "assign_group_ids_without_snapshotting_members" {
  command = apply

  variables {
    allowed_user_emails = []
    allowed_group_names = ["Claude Developers"]
  }

  assert {
    condition = (
      toset(keys(azuread_app_role_assignment.gateway)) == toset(["aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa"]) &&
      !strcontains(azurerm_api_management_api_policy.apim_policy.xml_content, "bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb") &&
      !strcontains(azurerm_api_management_api_policy.apim_policy.xml_content, "aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa") &&
      strcontains(azurerm_api_management_api_policy.apim_policy.xml_content, "Claims.ContainsKey(\"roles\")")
    )
    error_message = "Assign groups directly to the enterprise application; APIM must authorize the issued role, not a stale member snapshot."
  }
}

run "deduplicate_mixed_principals" {
  command = apply

  variables {
    allowed_user_emails = ["developer@example.com", " Developer@Example.com "]
    allowed_group_names = ["Claude Developers"]
  }

  assert {
    condition = (
      length(data.azuread_user.allowed) == 1 &&
      length(azurerm_role_assignment.foundry_user) == 2 &&
      length(azurerm_role_assignment.cognitive_services_user) == 2 &&
      length(azuread_app_role_assignment.gateway) == 2 &&
      length(azurerm_role_assignment.logs_reader) == 2
    )
    error_message = "Deduplicate mixed identity inputs for every role assignment."
  }
}

run "standard_v2_capacity" {
  command = plan

  variables {
    apim_sku_name = "StandardV2_10"
  }

  assert {
    condition     = azurerm_resource_group.rg.name == "claude-test-rg" && azurerm_api_management.apim.sku_name == "StandardV2_10"
    error_message = "Preserve prefix-based resource group naming and configurable Standard v2 capacity."
  }
}

run "reject_classic_standard" {
  command = plan
  variables {
    apim_sku_name = "Standard_1"
  }
  expect_failures = [var.apim_sku_name]
}

run "reject_no_models" {
  command = plan
  variables {
    models = []
  }
  expect_failures = [var.models]
}

run "reject_no_authorized_users" {
  command = plan
  variables {
    allowed_user_emails = []
    allowed_group_names = []
  }
  expect_failures = [azurerm_api_management_api.apim_api]
}

run "reject_gpt_model" {
  command = plan
  variables {
    models = ["gpt-6-sol"]
  }
  expect_failures = [var.models]
}

run "reject_duplicate_models" {
  command = plan
  variables {
    models = ["claude-opus-5", " Claude-Opus-5 "]
  }
  expect_failures = [var.models]
}

run "reject_regional_standard_model_plan" {
  command = plan
  variables {
    model_deployment_sku_name = "Standard"
  }
  expect_failures = [var.model_deployment_sku_name]
}

run "reject_fractional_model_capacity" {
  command = plan
  variables {
    model_deployment_capacity = 1.5
  }
  expect_failures = [var.model_deployment_capacity]
}

run "reject_missing_attestation" {
  command = plan
  variables {
    claude_organization_name = "REPLACE_WITH_LEGAL_ORGANIZATION"
  }
  expect_failures = [var.claude_organization_name]
}

run "reject_invalid_country_code" {
  command = plan
  variables {
    claude_country_code = "usa"
  }
  expect_failures = [var.claude_country_code]
}

run "reject_invalid_industry" {
  command = plan
  variables {
    claude_industry = "REPLACE_WITH_INDUSTRY"
  }
  expect_failures = [var.claude_industry]
}

run "reject_invalid_email" {
  command = plan
  variables {
    allowed_user_emails = ["not-an-email"]
  }
  expect_failures = [var.allowed_user_emails]
}

run "reject_blank_group" {
  command = plan
  variables {
    allowed_group_names = [" "]
  }
  expect_failures = [var.allowed_group_names]
}

run "reject_zero_token_rate" {
  command = plan
  variables {
    tokens_per_minute = 0
  }
  expect_failures = [var.tokens_per_minute]
}

run "reject_fractional_token_rate" {
  command = plan
  variables {
    tokens_per_minute = 1.5
  }
  expect_failures = [var.tokens_per_minute]
}

run "reject_negative_monthly_quota" {
  command = plan
  variables {
    monthly_token_quota = -1
  }
  expect_failures = [var.monthly_token_quota]
}

run "reject_oversize_monthly_quota" {
  command = plan
  variables {
    monthly_token_quota = 2147483648
  }
  expect_failures = [var.monthly_token_quota]
}
