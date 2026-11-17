# Terraform deployment

Review the [architecture and acceptance checklist](./README.md) first. Commands below use PowerShell. Validation does not deploy resources; applying creates billable Azure resources and accepts Marketplace terms.

## Prerequisites

- Terraform 1.7 or later (below 2.0)
- Azure CLI.
- Install Claude Code CLI or Claude Desktop 
- Permission to create resources and assign roles, such as Contributor plus Role Based Access Control Administrator at the appropriate scope.
- Entra permissions to create/manage the gateway app registration, enterprise application, exposed API scope, Azure CLI preauthorization, and app-role assignments. Azure subscription Contributor/Owner alone does **not** grant these directory permissions. For interactive Terraform, use an approved directory administrator such as Application Administrator. For automation, arrange admin-approved Graph application-management permissions (for example `Application.ReadWrite.All`, or an approved owned-application setup) plus `AppRoleAssignment.ReadWrite.All` and `Application.Read.All`. Terraform assigns its executing principal as app/service-principal owner; it never creates a client secret.
- Directory read access when resolving email addresses or group names: automated lookups require `User.Read.All` and/or `Group.Read.All` (or applicable broader permissions). Raw object IDs don't require the previous directory-object classification or group-member expansion.
- Group-based enterprise-application assignment requires appropriate Entra licensing. Only direct group members inherit app roles; nested group membership is not supported.


## Configure

From this directory:

```powershell
cd .\azure_infra
Copy-Item .\terraform.tfvars.example .\terraform.tfvars
```

Configure the following parameters in the created `terraform.tfvars` file

| Input | Meaning | Example value |
| --- | --- | --- |
| `subscription_id`, `tenant_id` | Explicit target subscription and tenant; replace both placeholders | `REPLACE_WITH_SUBSCRIPTION_ID`, `REPLACE_WITH_TENANT_ID` |
| `name_prefix` | Globally unique prefix for APIM and Foundry hostnames | `claude-demo-unique` |
| `location` | Region supporting the selected services/models | `eastus2` |
| `apim_sku_name` | APIM SKU and unit count | `StandardV2_1` |
| `publisher_name`, `publisher_email` | APIM publisher and operational contact | `Example organization`, `azure-admin@example.com` |
| `requests_per_minute` | Approximate per-caller APIM request limit, not a billing cap | `60` |
| `tokens_per_minute` | Approximate per-caller Messages token rate across models | `50000` |
| `monthly_token_quota` | Approximate per-caller Messages token quota per UTC calendar month | `5000000` |
| `log_retention_days` | Workspace log retention in days | `30` |
| `allowed_user_emails` | Existing users resolved by their Entra `mail` attribute, not UPN or aliases | `["developer@example.com"]` |
| `allowed_group_names` | Exact display names of existing Entra security groups | `[]` |
| `claude_organization_name` | Actual legal organization accepting the Claude Marketplace terms; replace the placeholder | `REPLACE_WITH_COMPANY_NAME` |
| `claude_country_code` | Actual country code for the Marketplace attestation | `JP` |
| `claude_industry` | Actual industry for the Marketplace attestation | `technology` |
| `models` | Claude catalog IDs to deploy; the example selects six models | `claude-opus-5-5`, `claude-haiku-4-5`, `claude-sonnet-5`, `claude-opus-5`, `claude-sonnet-5-5`, `claude-haiku-5-5` |
| `model_deployment_sku_name` | Deployment type supported by the selected models and region | `GlobalStandard` |
| `model_deployment_capacity` | Positive integer capacity per model, in model/SKU-specific quota units | `1` |
| `tags` | Resource tags | `environment = "dev"`, `workload = "claude-foundry"` |

## Validate and plan

Run the following commands to validate and deploy the terraform templates.

```powershell
az login --tenant <tenant-id>
az account set --subscription <subscription-id>

terraform init
terraform fmt -check -recursive
terraform validate
terraform test
terraform plan -out="deployment.tfplan"
terraform apply "deployment.tfplan"
terraform output -json > outputs.json
```


## Apply and configure Claude Code

After deploying the terraform templates, create the configuration files for `Claude Code` and `Claude Desktop`.

```powershell
cd ..
.\claude_config\prepare_claude_config.ps1
```

The script creates the `.\claude_config\output` folder if needed and saves the following files there. Rerunning the script overwrites the generated files in that folder.

| File Name | Description |
| - | - |
| `.\claude_config\output\claude_desktop_config.json` | Claude Desktop config file. |
| `.\claude_config\output\settings.json` | Claude Code config file. |
| `.\claude_config\output\get_entra_id_token.ps1` | Helper script for Claude Code & Desktop retrieve the Entra ID auth token |

### Configure Claude Code
1. Copy `.\claude_config\output\settings.json` to `C:\Users\%USERPROFILE%\.claude`
2. Copy `.\claude_config\output\get_entra_id_token.ps1` to `C:\Users\%USERPROFILE%\.claude`
3. Open Powershell and run `claude` and verify it is working

### Configure Claude Desktop
1. Open Claude Desktop, then select Help > Troubleshooting > Enable Developer Mode
2. Select Developer > Configure third-party inference
3. Select `Default` in the right-top corner. And select `Import configuration`
4. Select `.\claude_config\output\claude_desktop_config.json`
5. Restart Claude Desktop and verify it is working

## Verify inference and logging

Once Claude Code and Claude Desktop are set up, use the following sample queries on Log Analytics to monitor Claude usage

After allowing ingestion delay, query the workspace:

```kusto
# Get APIM logs
ApiManagementGatewayLogs
| where TimeGenerated > ago(1h)
| project TimeGenerated, ApiId, OperationId, ResponseCode, BackendResponseCode, TotalTime, CorrelationId
| order by TimeGenerated desc
```

```kusto
# Get requests to the Cluade API
AppRequests
| where TimeGenerated > ago(1h)
| project TimeGenerated, Name, ResultCode, Success, DurationMs, OperationId
| order by TimeGenerated desc
```

```kusto
# Get Total tokes used per model per user
AppMetrics
| where TimeGenerated > ago(1d)
| where Name == "Total Tokens"
| extend UserId = tostring(Properties["UserId"]), Model = tostring(Properties["Model"])
| summarize Tokens = sum(Sum) by UserId, Model, bin(TimeGenerated, 1d)
```

## Remove Azure Resources

```powershell
cd azure_infra
terraform plan -destroy -out="destroy.tfplan"
terraform apply "destroy.tfplan"
```
