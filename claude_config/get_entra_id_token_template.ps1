# Returns a short-lived Entra access token for the APIM gateway audience.
# Supports CLAUDE_HELPER_CONTEXT for Claude Desktop Cowork/Code silent refresh.

$context = $env:CLAUDE_HELPER_CONTEXT

# For non-interactive contexts, try silent token acquisition only.
# If it fails, exit non-zero so Cowork prompts the user instead of blocking.
if ($context -and $context -ne 'interactive' -and $context -ne 'setup-test') {
    try {
        $token = az account get-access-token `
            --resource "api://__GATEWAY_ID__" `
            --query accessToken -o tsv 2>$null
        if ($LASTEXITCODE -ne 0 -or -not $token) {
            Write-Error "Silent token refresh failed (context: $context)"
            exit 1
        }
        Write-Output $token
        exit 0
    } catch {
        Write-Error "Silent token refresh failed: $_"
        exit 1
    }
}

# Interactive or setup-test context: allow az CLI to prompt if needed.
$token = az account get-access-token `
    --resource "api://__GATEWAY_ID__" `
    --query accessToken -o tsv

if ($LASTEXITCODE -ne 0 -or -not $token) {
    Write-Error "Token acquisition failed. Run 'az login' first."
    exit 1
}

Write-Output $token
exit 0