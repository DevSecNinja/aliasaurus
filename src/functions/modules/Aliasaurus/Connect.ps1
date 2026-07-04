Set-StrictMode -Version Latest

function Connect-Aliasaurus {
    <#
    .SYNOPSIS
        Connects to Exchange Online (and Microsoft Graph) using the managed identity.
    .DESCRIPTION
        No secrets are used. Requires the ExchangeOnlineManagement module and an
        Exchange RBAC role scoped to the cmdlets used (Constitution Principle III).
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][psobject]$Config
    )

    if ([string]::IsNullOrWhiteSpace($Config.Organization)) {
        throw (New-AliasError -StatusCode 500 -Message 'M365_ORGANIZATION is not configured.')
    }

    if (-not (Get-ConnectionInformation -ErrorAction SilentlyContinue)) {
        Write-AliasLog -Level Information -Message 'Connecting to Exchange Online via managed identity.'
        Connect-ExchangeOnline -ManagedIdentity -Organization $Config.Organization -ShowBanner:$false -ErrorAction Stop
    }
}
