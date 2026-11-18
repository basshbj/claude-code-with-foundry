# Terraform deployment

## Prerequisites

- Terraform 1.7 or later (below 2.0)
- Azure CLI.
- Install Claude Code CLI or Claude Desktop 
- Azure Roles: `Contributor` & `Role Based Access Control Administrator`
- Entra ID Roles: `Application Developer` 

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

Once Claude Code and Claude Desktop are set up, use the following sample queries to verify the logs.

1. Open Azure Application Insights
2. Left menu > Monitoring > Logs

```kusto
# Get requests to the Cluade API
requests
| where timestamp  > ago(24h)
| project timestamp, name, resultCode, success, url
```

```kusto
# Get Total tokes used per model per user
customMetrics
| where timestamp > ago(24h)
| where name == "Total Tokens"
| extend UserId = tostring(customDimensions["UserId"]), Model = tostring(customDimensions["Model"])
| summarize Tokens = sum(value) by UserId, Model, bin(timestamp, 1d)
```

## Remove Azure Resources

```powershell
cd azure_infra
terraform plan -destroy -out="destroy.tfplan"
terraform apply "destroy.tfplan"
```
