Set-StrictMode -Version Latest

function Get-AliasaurusConfig {
    <#
    .SYNOPSIS
        Loads aliasaurus configuration from environment variables (app settings).
    .DESCRIPTION
        No secrets are read here; authentication uses the managed identity.
        Mailbox lists are comma-separated UPNs.
    #>
    [CmdletBinding()]
    param(
        [hashtable]$Environment = @{}
    )

    function Get-Setting([string]$Name, [string]$Default) {
        if ($Environment.ContainsKey($Name)) { return [string]$Environment[$Name] }
        $value = [Environment]::GetEnvironmentVariable($Name)
        if ([string]::IsNullOrWhiteSpace($value)) { return $Default }
        return $value
    }

    function Split-List([string]$Value) {
        if ([string]::IsNullOrWhiteSpace($Value)) { return @() }
        return @($Value -split ',' | ForEach-Object { $_.Trim() } | Where-Object { $_ })
    }

    $domain = Get-Setting 'ALIAS_DOMAIN' ''
    if ([string]::IsNullOrWhiteSpace($domain)) {
        throw (New-AliasError -StatusCode 500 -Message 'ALIAS_DOMAIN is not configured.')
    }

    [pscustomobject]@{
        Domain               = $domain
        Organization         = Get-Setting 'M365_ORGANIZATION' ''
        PrimaryMailbox       = Get-Setting 'PRIMARY_MAILBOX' ''
        IntakeMailboxes      = Split-List (Get-Setting 'INTAKE_MAILBOXES' '')
        GraveyardMailboxes   = Split-List (Get-Setting 'GRAVEYARD_MAILBOXES' '')
        StorageAccount       = Get-Setting 'LEDGER_STORAGE_ACCOUNT' ''
        LedgerTable          = Get-Setting 'LEDGER_TABLE' 'aliases'
        PoolTarget           = [int](Get-Setting 'POOL_TARGET' '25')
        PoolLowWater         = [int](Get-Setting 'POOL_LOW_WATER' '10')
        MaxProxiesPerMailbox = [int](Get-Setting 'MAX_PROXIES_PER_MAILBOX' '300')
    }
}
