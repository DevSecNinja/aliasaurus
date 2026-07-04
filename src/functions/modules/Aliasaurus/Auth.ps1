Set-StrictMode -Version Latest

function Get-ClientPrincipalName {
    <#
    .SYNOPSIS
        Returns the signed-in user's name from the Easy Auth header, or $null.
    #>
    [CmdletBinding()]
    param($Request)

    if (-not $Request -or -not $Request.Headers) { return $null }
    $headers = $Request.Headers
    foreach ($key in @('x-ms-client-principal-name', 'X-MS-CLIENT-PRINCIPAL-NAME')) {
        $value = $null
        try { $value = $headers[$key] } catch { $value = $null }
        if ($value) { return [string]$value }
    }
    return $null
}

function Test-RequestOwner {
    <#
    .SYNOPSIS
        Returns $true only if the request is from the configured owner.
    .DESCRIPTION
        Compares the Easy Auth client principal name to OWNER_UPN. When running
        locally (AZURE_FUNCTIONS_ENVIRONMENT=Development) with no principal header,
        the check is bypassed to ease local testing.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]$Request,
        [Parameter(Mandatory)][psobject]$Config
    )

    $name = Get-ClientPrincipalName -Request $Request
    if (-not $name) {
        return ([Environment]::GetEnvironmentVariable('AZURE_FUNCTIONS_ENVIRONMENT') -eq 'Development')
    }
    if ([string]::IsNullOrWhiteSpace([string]$Config.OwnerUpn)) { return $false }
    return ($name -ieq $Config.OwnerUpn)
}
