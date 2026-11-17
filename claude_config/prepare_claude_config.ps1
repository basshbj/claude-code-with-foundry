#Requires -Version 5.1
[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'

$outputsPath = Join-Path (Split-Path -Parent $PSScriptRoot) 'azure_infra\outputs.json'
if (-not (Test-Path -LiteralPath $outputsPath -PathType Leaf)) {
    throw "Terraform outputs not found at '$outputsPath'. Export them with 'terraform output -json' first."
}

$outputs = Get-Content -LiteralPath $outputsPath -Raw -Encoding UTF8 | ConvertFrom-Json
$replacements = [ordered]@{
    '__APIM_BASE_URL__' = $outputs.claude_code_connection.value.ANTHROPIC_BASE_URL
    '__USERNAME__' = $env:USERNAME
    '__TENANT_ID__' = $outputs.claude_code_connection.value.AZURE_TENANT_ID
    '__GATEWAY_ID__' = $outputs.gateway_application_client_id.value
}

foreach ($replacement in $replacements.GetEnumerator()) {
    if ($replacement.Value -isnot [string] -or [string]::IsNullOrWhiteSpace($replacement.Value)) {
        throw "Missing or invalid value for '$($replacement.Key)'. Check '$outputsPath' and the USERNAME environment variable."
    }
}

$templates = [ordered]@{
    'claude_desktop_config_template.json' = 'claude_desktop_config.json'
    'get_entra_id_token_template.ps1' = 'get_entra_id_token.ps1'
    'claude_code_settings_template.json' = 'settings.json'
}

$generatedFiles = [ordered]@{}
foreach ($template in $templates.GetEnumerator()) {
    $templatePath = Join-Path $PSScriptRoot $template.Key
    $content = Get-Content -LiteralPath $templatePath -Raw -Encoding UTF8
    $isJson = $template.Key.EndsWith('.json')

    foreach ($replacement in $replacements.GetEnumerator()) {
        $value = $replacement.Value
        if ($isJson) {
            # Placeholders are inside JSON strings, so escape replacement values without their outer quotes.
            $jsonValue = ConvertTo-Json -InputObject $value -Compress
            $value = $jsonValue.Substring(1, $jsonValue.Length - 2)
        }
        $content = $content.Replace($replacement.Key, $value)
    }

    if ($content -match '__[A-Z][A-Z0-9_]*__') {
        throw "Unresolved placeholder '$($Matches[0])' in '$templatePath'."
    }

    if ($isJson) {
        $content | ConvertFrom-Json | Out-Null
    }
    else {
        $tokens = $null
        $parseErrors = $null
        [System.Management.Automation.Language.Parser]::ParseInput($content, [ref]$tokens, [ref]$parseErrors) | Out-Null
        if ($parseErrors.Count -gt 0) {
            throw "Generated PowerShell from '$templatePath' is invalid: $($parseErrors.Message -join '; ')"
        }
    }

    $generatedFiles[$template.Value] = $content
}

$encoding = New-Object System.Text.UTF8Encoding($false)
foreach ($file in $generatedFiles.GetEnumerator()) {
    $destinationPath = Join-Path $PSScriptRoot $file.Key
    [System.IO.File]::WriteAllText($destinationPath, $file.Value, $encoding)
    Write-Host "Created '$destinationPath'."
}
