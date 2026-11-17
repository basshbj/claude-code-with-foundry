[CmdletBinding()]
param(
    [string]$TenantId = $env:AZURE_TENANT_ID,
    [string]$Scope = $env:CLAUDE_GATEWAY_SCOPE
)

$ErrorActionPreference = 'Stop'

if ([string]::IsNullOrWhiteSpace($TenantId) -or [string]::IsNullOrWhiteSpace($Scope)) {
    throw 'Set AZURE_TENANT_ID and CLAUDE_GATEWAY_SCOPE from the Terraform claude_code_connection output.'
}

Get-Command az -ErrorAction Stop | Out-Null
$token = @(az account get-access-token `
    --tenant $TenantId `
    --scope $Scope `
    --query accessToken `
    --output tsv `
    --only-show-errors)
$tokenExitCode = $LASTEXITCODE

if ($tokenExitCode -ne 0 -or $token.Count -ne 1 -or [string]::IsNullOrWhiteSpace([string]$token[0])) {
    throw "Gateway token acquisition failed (Azure CLI exit $tokenExitCode). Check the Azure CLI error and run 'az login --tenant $TenantId' if sign-in is required."
}

Write-Output ([string]$token[0]).Trim()
