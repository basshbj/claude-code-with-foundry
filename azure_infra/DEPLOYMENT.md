# Terraform deployment

Review the [architecture and acceptance checklist](./README.md) first. Commands below use PowerShell. Validation does not deploy resources; applying creates billable Azure resources and accepts Marketplace terms.

## Prerequisites

- Terraform 1.7 or later (below 2.0) and Azure CLI.
- AzureRM >= 4.81.0, AzureAD >= 3.10.0, and AzAPI >= 2.5.0, within the major-version limits in [versions.tf](./src/versions.tf). Commit the generated [provider lock file](./src/.terraform.lock.hcl).
- A paid, Claude-eligible subscription and a region supporting APIM Standard v2 and all selected **Hosted on Azure** model versions, with sufficient quota. The example uses `eastus2`; confirm current availability rather than treating this as a quota guarantee.
- Permission to create resources and assign roles, such as Contributor plus Role Based Access Control Administrator at the appropriate scope.
- Entra permissions to create/manage the gateway app registration, enterprise application, exposed API scope, Azure CLI preauthorization, and app-role assignments. Azure subscription Contributor/Owner alone does **not** grant these directory permissions. For interactive Terraform, use an approved directory administrator such as Application Administrator. For automation, arrange admin-approved Graph application-management permissions (for example `Application.ReadWrite.All`, or an approved owned-application setup) plus `AppRoleAssignment.ReadWrite.All` and `Application.Read.All`. Terraform assigns its executing principal as app/service-principal owner; it never creates a client secret.
- Directory read access when resolving email addresses or group names: automated lookups require `User.Read.All` and/or `Group.Read.All` (or applicable broader permissions). Raw object IDs don't require the previous directory-object classification or group-member expansion.
- Group-based enterprise-application assignment requires appropriate Entra licensing. Only direct group members inherit app roles; nested group membership is not supported.

AzAPI is required because Claude deployment `modelProviderData`, the Foundry `ProjectManagedIdentity` connection, and the installed AzureRM provider's custom-metrics settings aren't exposed by AzureRM. The two Foundry declarations disable embedded schema validation because those service-supported properties are missing from the published ARM schema. AzAPI updates also configure Application Insights' preview `CustomMetricsOptedInType` property and the APIM diagnostic's `metrics` flag. Azure validates all requests. Project-managed-identity trace ingestion and dimensional custom metrics are currently preview. The [Azure team documents the custom-metrics property here](https://github.com/Azure/bicep-types-az/issues/2048).

## Configure

From this directory:

```powershell
Set-Location .\src
Copy-Item .\terraform.tfvars.example .\terraform.tfvars
```

Don't overwrite an existing parameter file without reviewing it. Edit the [example's local copy](./src/terraform.tfvars.example):

| Input | Meaning |
| --- | --- |
| `subscription_id`, `tenant_id` | Explicit target subscription and tenant |
| `name_prefix` | Globally unique prefix for APIM and Foundry hostnames |
| `resource_group_name` | Optional name of a **new** group; null derives `<prefix>-rg` |
| `location` | Region supporting the selected services/models |
| `publisher_name`, `publisher_email` | APIM publisher and operational contact |
| `apim_sku_name` | `StandardV2_1` through `StandardV2_10` |
| `models` | Claude catalog IDs; defaults to all seven requested models; optionally select a subset |
| `model_deployment_sku_name` | `GlobalStandard` (default) or supported US `DataZoneStandard` |
| `model_deployment_capacity` | Positive integer capacity per model, in model/SKU-specific quota units |
| `claude_organization_name` | Actual legal organization accepting the Claude Marketplace terms |
| `claude_country_code`, `claude_industry` | Actual country and industry for the Marketplace attestation |
| `allowed_user_emails` | Existing users resolved by their Entra `mail` attribute, not UPN or aliases |
| `allowed_group_names` | Exact unique names of existing Entra security groups |
| `requests_per_minute` | Approximate per-caller APIM request limit, not a billing cap |
| `tokens_per_minute` | Approximate per-caller Messages token rate across models (default 50,000) |
| `monthly_token_quota` | Approximate per-caller Messages token quota per UTC calendar month (default 5,000,000) |
| `log_retention_days`, `tags` | Workspace retention (30-730 days) and resource tags |

Supply at least one authorized user/group across the three identity inputs. Resolved IDs are deduplicated. Both Foundry roles are assigned at **account scope**, so they cover child projects and allow direct account inference. Log-reader roles are also assigned on Application Insights and the workspace.

APIM separately receives `Cognitive Services User` on Foundry for backend inference. **The gateway enforces the gateway application's `Claude.Standard` app role**, before replacing the caller's token with its managed-identity token. Configured users/groups/service principals receive this role on the enterprise application; membership is not copied into APIM policy. Entra evaluates assignments at token issuance, subject to propagation and existing token lifetimes. Direct group membership changes don't require Terraform; changing which groups/users are assigned does.

### Gateway app registration

[identity.tf](./src/identity.tf) creates the following tenant resources:

- `azuread_application.gateway`: `<name_prefix>-gateway`, single tenant, v2 access tokens, delegated `access_as_user` scope, and `Claude.Standard` app role.
- `azuread_application_identifier_uri.gateway`: `api://<gateway-client-id>`.
- `azuread_service_principal.gateway`: the enterprise application, with **assignment required**.
- `azuread_app_role_assignment.gateway`: assigns the role to the deduplicated configured users/groups/service principals.
- `azuread_application_pre_authorized.azure_cli`: preauthorizes Microsoft's Azure CLI client for this scope, so developers use their existing `az login` session without a custom client app or secret.

After applying, locate `<name_prefix>-gateway` under **Entra ID > App registrations** and **Enterprise applications**. **Expose an API** shows the scope; **Enterprise applications > Users and groups** shows the role assignments. Use `gateway_application_client_id`, `gateway_application_id_uri`, and `gateway_enterprise_application_object_id` outputs to identify the exact objects.

Clients request `api://<gateway-client-id>/.default`. Because the API explicitly requests **v2 tokens**, their `aud` is the client-ID GUID; APIM validates that GUID, not the URI. Do not substitute the Foundry audience or accept arbitrary tenant tokens.

Names in `models` are trimmed and lowercased for catalog lookup, deployment naming, and the APIM allowlist. Use exact catalog IDs, not display names. All deployments explicitly request `Anthropic` **version `"2"`**, never an Azure-selected default that might select Anthropic-hosted inference. `NoAutoUpgrade` prevents automatic version changes. AzAPI locks serialize model changes within this account to avoid concurrent deployment conflicts.

### Marketplace terms

Each model deployment sends `modelProviderData` with the actual organization, country, and industry. This can automatically accept the Anthropic Marketplace offer on your behalf. Review the [official starter's terms guidance](https://github.com/Azure-Samples/claude#terms-of-use), the selected model card, and your organization's approval requirements **before applying**. Don't use fictitious attestations. No Azure operations or terms acceptance are performed by local validation or mocked tests.

## Validate and plan

```powershell
terraform init
terraform fmt -check -recursive
terraform validate
terraform test

az login --tenant <tenant-id>
az account set --subscription <subscription-id>
terraform plan -out="deployment.tfplan"
```

The [tests](./src/tests/infrastructure.tftest.hcl) mock all providers and explicitly override local parameters. They check model hosting/version, roles, project/telemetry linkage, log categories/sampling, Entra caller authorization, managed-identity backend authentication, token governance/metrics, and native Anthropic routes. They don't prove live availability, policy execution, RBAC propagation, or telemetry ingestion.

Before applying, confirm current model/version/SKU availability and quota in the selected subscription/region. Review the real plan, including costs, new resources, and any destruction/replacement. Don't reuse plans made before configuration changes.

### Recovering from `diagnostics/azuremonitor already exists`

Enabling APIM's Azure Monitor platform diagnostic setting automatically creates its built-in `azuremonitor` API diagnostic. The configuration updates that existing diagnostic with `azapi_update_resource.azuremonitor`, after the platform export is enabled, rather than trying to create it through AzureRM. The Application Insights diagnostic remains separately managed by AzureRM. No manual import is needed for a new deployment or an apply that failed with this conflict.

The Azure Monitor update must omit `httpCorrelationProtocol`: APIM accepts that property only for Application Insights diagnostics, where W3C correlation remains enabled. If an earlier apply failed with this property's validation error, use the same replan/reapply steps below; no import, deletion, or state removal is needed for that error.

After updating the configuration, keep the same backend/workspace and regenerate the plan:

```powershell
terraform validate
terraform test
terraform plan -out="deployment.tfplan"
# Review the new plan, then apply it:
terraform apply "deployment.tfplan"
```

Don't delete the existing Azure diagnostic or reuse the failed apply's saved plan. Successful resources from the partial apply remain in state.

If you already imported or successfully managed `azurerm_api_management_diagnostic.all_apis["azuremonitor"]` with the previous configuration, back up your state and remove **only that old binding** before planning with this revision:

```powershell
# Only if terraform state list contains this exact address:
terraform state rm 'azurerm_api_management_diagnostic.all_apis["azuremonitor"]'
```

This state-only operation doesn't delete the Azure diagnostic. Do not remove the Application Insights diagnostic or platform diagnostic-setting bindings. The AzAPI update doesn't delete or reset the built-in diagnostic when removed; its lifecycle belongs to APIM/the platform export.

### Migrating an existing deployment

Back up state and inspect the real plan. **Do not blindly apply this revision to an existing stack.**

- This revision adds the missing gateway app registration, exposed scope, enterprise application, preauthorization, and app-role assignments. APIM now accepts **only gateway-app tokens with `Claude.Standard`**, not tokens for `https://ai.azure.com` or `https://cognitiveservices.azure.com`. Existing Foundry access alone doesn't grant gateway access. Existing configured user/group Foundry Azure role assignments are retained as originally requested, but aren't used to authorize the gateway backend call.
- **Client configuration must change with the APIM policy**: disable native Foundry mode, use `ANTHROPIC_BASE_URL`, and configure the Entra token helper below. The `claude_code_connection` output now contains `ANTHROPIC_BASE_URL` and `CLAUDE_GATEWAY_SCOPE`, not `ANTHROPIC_FOUNDRY_BASE_URL`. The API name, `/anthropic` path, deployments, and managed-identity backend remain unchanged. Coordinate deployment/client rollout to avoid interrupting existing callers.
- Removes the previous Terraform-expanded caller membership snapshots. Entra app-role assignments replace them. Group access now follows enterprise-application semantics: **direct membership only**, not nested membership, and authorization changes require token renewal/propagation.
- New default per-caller token limits/quotas can reject requests previously allowed by request-only limits. Review `tokens_per_minute` and `monthly_token_quota` before applying. These aren't monetary budget caps; test with controlled low limits in a nonproduction stack.
- Terraform enables Application Insights custom-metric dimensions and APIM diagnostic custom metrics with AzAPI updates. Each update is reapplied if its AzureRM-managed parent changes, avoiding a parent update silently undoing these unexposed settings.
- Older Codex registrations/clients may still appear in state. Review all proposed changes against their actual IDs and dependent clients; don't blindly delete or reuse them as the new gateway registration. Import an existing compatible gateway app only through a separately reviewed migration. No state modifications are performed automatically.
- Remove `oauth_redirect_port` from the local parameter file, replace the GPT `models` list, and supply all three `claude_*` attestation inputs. Existing local parameter/state/plan files are not changed automatically.
- GPT deployments managed by the previous AzureRM resource are removed; Claude deployments use new AzAPI addresses. This intentionally changes the deployed models. If retaining existing deployments, move them to separately managed configuration/state with a reviewed migration; don't destroy them accidentally.
- The Responses API is replaced by the Claude Messages API. Existing Codex clients and old outputs (`codex_connection`, `foundry_openai_base_url`) are no longer supported.
- The account and APIM resource addresses/names are retained; all-log diagnostics reuse the existing diagnostic-setting addresses and names. The legacy `platform-metrics` Azure setting name now covers logs **and** metrics.
- Classic APIM cannot be upgraded in place to Standard v2. Earlier `<prefix>-openai` resources also require a separate migration review.

## Apply and configure Claude Code

Only after explicit approval of the real plan, Marketplace terms, costs, and permissions:

```powershell
terraform apply "deployment.tfplan"
terraform output claude_code_connection
terraform output model_deployment_names
terraform output foundry_project_endpoint
terraform output application_insights_id
terraform output gateway_application_client_id
terraform output gateway_application_id_uri
```

In the user's shell, sign in and load the non-secret connection output (from the Terraform source directory):

```powershell
az login --tenant <tenant-id>
az account set --subscription <subscription-id>
$connection = terraform output -json claude_code_connection | ConvertFrom-Json
$env:CLAUDE_CODE_USE_FOUNDRY = $connection.CLAUDE_CODE_USE_FOUNDRY
$env:ANTHROPIC_BASE_URL = $connection.ANTHROPIC_BASE_URL
$env:AZURE_TENANT_ID = $connection.AZURE_TENANT_ID
$env:CLAUDE_GATEWAY_SCOPE = $connection.CLAUDE_GATEWAY_SCOPE
Remove-Item Env:\ANTHROPIC_FOUNDRY_API_KEY -ErrorAction SilentlyContinue
Remove-Item Env:\ANTHROPIC_FOUNDRY_AUTH_TOKEN -ErrorAction SilentlyContinue
Remove-Item Env:\ANTHROPIC_FOUNDRY_RESOURCE -ErrorAction SilentlyContinue
Remove-Item Env:\ANTHROPIC_FOUNDRY_BASE_URL -ErrorAction SilentlyContinue
Remove-Item Env:\ANTHROPIC_AUTH_TOKEN -ErrorAction SilentlyContinue
Remove-Item Env:\ANTHROPIC_API_KEY -ErrorAction SilentlyContinue

# Review the helper before copying it; do not overwrite a customized copy blindly.
New-Item -ItemType Directory -Path "$env:USERPROFILE\.claude" -Force | Out-Null
Copy-Item ..\client\get-claude-gateway-token.ps1 "$env:USERPROFILE\.claude\get-claude-gateway-token.ps1"
```

Remove old Foundry-mode and explicit token/API-key overrides wherever they were persisted, not just from the current shell. Don't point Claude Code at the project endpoint.

Merge the following into `%USERPROFILE%\.claude\settings.json` (Claude Code settings, **not** VS Code settings). Preserve unrelated settings. Replace the hostname, tenant, gateway app client ID, and helper's absolute path; use models actually deployed:

```json
{
  "model": "claude-sonnet-5-5",
  "env": {
    "CLAUDE_CODE_USE_FOUNDRY": "0",
    "ANTHROPIC_BASE_URL": "https://YOUR-APIM.azure-api.net/anthropic",
    "AZURE_TENANT_ID": "YOUR-TENANT-ID",
    "CLAUDE_GATEWAY_SCOPE": "api://YOUR-GATEWAY-APP-CLIENT-ID/.default",
    "CLAUDE_CODE_API_KEY_HELPER_TTL_MS": "300000",
    "ANTHROPIC_DEFAULT_OPUS_MODEL": "claude-opus-5-5",
    "ANTHROPIC_DEFAULT_SONNET_MODEL": "claude-sonnet-5-5",
    "ANTHROPIC_DEFAULT_HAIKU_MODEL": "claude-haiku-5-5"
  },
  "apiKeyHelper": "powershell -NoProfile -File \"C:\\Users\\YOUR-USER\\.claude\\get-claude-gateway-token.ps1\""
}
```

The helper silently obtains a short-lived Entra token from Azure CLI and prints only that token to Claude Code. `apiKeyHelper` is Claude Code's setting name; **this is not API-key authentication**. Claude sends the token in `Authorization: Bearer` (and duplicates it in `x-api-key`); APIM validates only the bearer token and strips key headers before backend forwarding. The helper doesn't start interactive login, write tokens to disk, or change execution policy. If tenant policy blocks local scripts, use your approved signing/execution-policy process instead of bypassing it.

Run `claude` after configuring the helper. `/status` should show the APIM **Anthropic base URL** and helper credential source, not native Microsoft Foundry mode. When sign-in/MFA renewal is needed, rerun `az login --tenant <tenant-id>`. Run Azure CLI sign-in in the same Windows/WSL/container environment where Claude runs. Fully restart VS Code after removing inherited credential overrides; its Claude process reads the helper from Claude settings. For extension-specific sign-in prompts, follow the [gateway extension setup](https://code.claude.com/docs/en/llm-gateway-connect#vs-code-extension); don't insert a static expiring token into settings.

## Verify inference and logging

Wait for Azure RBAC propagation and generate test traffic. This PowerShell smoke request uses a short-lived Entra token; never print or save it:

```powershell
$token = az account get-access-token --tenant $connection.AZURE_TENANT_ID --scope $connection.CLAUDE_GATEWAY_SCOPE --query accessToken -o tsv
if ($LASTEXITCODE -ne 0 -or [string]::IsNullOrWhiteSpace($token)) {
    throw "Failed to acquire the gateway Entra token. Check Azure CLI's error, app assignment, consent, and tenant sign-in."
}
$headers = @{
    Authorization = "Bearer $token"
    "anthropic-version" = "2023-06-01"
}
$body = @{
    model = "claude-haiku-4-5"
    max_tokens = 128
    messages = @(@{ role = "user"; content = "Reply with OK." })
} | ConvertTo-Json -Depth 5
try {
    Invoke-RestMethod -Method Post -Uri "$($connection.ANTHROPIC_BASE_URL)/v1/messages" -Headers $headers -ContentType "application/json" -Body $body
    $countBody = @{
        model = "claude-haiku-4-5"
        messages = @(@{ role = "user"; content = "Reply with OK." })
    } | ConvertTo-Json -Depth 5
    Invoke-RestMethod -Method Post -Uri "$($connection.ANTHROPIC_BASE_URL)/v1/messages/count_tokens" -Headers $headers -ContentType "application/json" -Body $countBody
} finally {
    $headers.Clear()
    Remove-Variable token
}
```

Use an actually deployed model if testing a subset. Also test a real streamed Claude Code task and the negative authentication/authorization cases in the [checklist](./README.md#acceptance-checklist).

The Python smoke test also reads `CLAUDE_GATEWAY_SCOPE` and `ANTHROPIC_BASE_URL` from this shell. It no longer requests a Foundry-audience token for gateway calls. Missing scope configuration fails before overwriting its existing CSV results.

Verify a key-only request is rejected (401), Foundry-audience tokens are rejected (401), a valid gateway token without the role is rejected (403), and an assigned caller reaches Foundry using APIM's identity. Assignment-required can reject an unassigned user during token acquisition before APIM is reached. For token failures, check Azure CLI's actual AADSTS error, tenant, enterprise-app assignment, delegated scope, and preauthorization/tenant consent policy. Backend 401/403 errors require checking the `apim_managed_identity_principal_id` output, its `Cognitive Services User` assignment, propagation, and the policy's Cognitive Services token audience. Don't re-enable Foundry local authentication or fall back to keys.

The Messages response should include `x-ratelimit-remaining`, `x-tokens-remaining`, and `x-token-quota-remaining`. Request/token rate exhaustion returns 429; monthly token quota exhaustion returns 403. Counters span the allowed models for each original caller, not all callers combined. `/count_tokens` is request-limited but intentionally excluded from inference token accounting. Streaming estimates, concurrent requests, and per-region counters mean these controls aren't hard spend limits.

After allowing ingestion delay, query the workspace:

```kusto
ApiManagementGatewayLogs
| where TimeGenerated > ago(1h)
| project TimeGenerated, ApiId, OperationId, ResponseCode, BackendResponseCode, TotalTime, CorrelationId
| order by TimeGenerated desc
```

```kusto
AppRequests
| where TimeGenerated > ago(1h)
| project TimeGenerated, Name, ResultCode, Success, DurationMs, OperationId
| order by TimeGenerated desc
```

For per-user/model token totals in the workspace (use `customMetrics` with `timestamp`, `name`, `customDimensions`, and `valueSum` in the Application Insights query scope):

```kusto
AppMetrics
| where TimeGenerated > ago(1d)
| where Name == "Total Tokens"
| extend UserId = tostring(Properties["UserId"]), Model = tostring(Properties["Model"])
| summarize Tokens = sum(Sum) by UserId, Model, bin(TimeGenerated, 1d)
```

Custom metrics have dimensional/cardinality limits and can omit excess time series; don't use them as a billing ledger. Allow ingestion delay and inspect the `claudecode` namespace and emitted metric names after live traffic. Verify **Usage and estimated costs > Custom metrics > With dimensions** on Application Insights and `metrics: true` on the APIM Application Insights diagnostic if dimensions are missing.

Foundry platform logs are also sent to this workspace (typically `AzureDiagnostics`, depending on category). Project telemetry is connected to the same Application Insights resource. Direct Claude inference does not create Foundry Agent traces or Claude Code tool spans automatically.

If data is missing, verify **both** the Azure diagnostic export and the APIM all-APIs diagnostic (`azuremonitor`/`applicationinsights`), the logger's managed identity, publishing-role propagation, and any per-API overrides. These templates use 100% sampling in APIM and Application Insights and always log errors, but delivery remains best-effort. Gateway bodies and headers are explicitly excluded; review any other configured telemetry sources separately.

## State and teardown

Local parameters, state, and saved plans can contain sensitive data. Use a protected, locking Azure Storage backend with Entra authentication for shared/automated use; bootstrap it separately and migrate state with a reviewed process. Don't commit state, tokens, or saved plans.

**Destructive:** use the original state/backend/workspace and review a destroy plan before approval:

```powershell
terraform workspace show
terraform state list
terraform plan -destroy -out="destroy.tfplan"
# Only after reviewing and approving all deletions:
terraform apply "destroy.tfplan"
terraform state list
```

Teardown removes the managed resource group, APIM, Foundry account/project/models, Application Insights, workspace, connection, and role assignments. Group deletion can also remove resources added outside Terraform; inspect contents first. Don't delete the group or state manually ahead of Terraform. Existing external users/groups and independently bootstrapped backend storage aren't deleted. If teardown fails, resolve the error and regenerate the plan from remaining state.
