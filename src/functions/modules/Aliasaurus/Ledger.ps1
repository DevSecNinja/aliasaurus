Set-StrictMode -Version Latest

# ---------------------------------------------------------------------------
# Pure logic (unit-tested; no I/O)
# ---------------------------------------------------------------------------

$script:AliasStates = @('pool', 'active', 'disabled')

$script:AliasTransitions = @{
    'pool'     = @('pool', 'active')
    'active'   = @('active', 'disabled')
    'disabled' = @('disabled', 'active')
}

function New-AliasRecord {
    <#
    .SYNOPSIS
        Creates a new alias ledger record (in-memory).
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][string]$Address,
        [Parameter(Mandatory)][string]$HostMailbox,
        [ValidateSet('pool', 'active', 'disabled')]
        [string]$Status = 'pool',
        [string]$Site,
        [string]$Note
    )

    $domain = ($Address -split '@', 2)[1]

    [pscustomobject]@{
        PartitionKey = $domain
        RowKey       = $Address
        address      = $Address
        site         = if ($Site) { $Site } else { $null }
        status       = $Status
        hostMailbox  = $HostMailbox
        createdUtc   = [DateTime]::UtcNow.ToString('o')
        assignedUtc  = $null
        disabledUtc  = $null
        note         = if ($Note) { $Note } else { $null }
    }
}

function Set-AliasRecordState {
    <#
    .SYNOPSIS
        Applies a state transition to an alias record, enforcing rules.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][psobject]$Record,
        [Parameter(Mandatory)][ValidateSet('pool', 'active', 'disabled')][string]$State,
        [string]$Site,
        [string]$Note,
        [string]$HostMailbox
    )

    if ($State -notin $script:AliasTransitions[$Record.status]) {
        throw (New-AliasError -StatusCode 409 -Message "Invalid alias transition '$($Record.status)' -> '$State'.")
    }

    $now = [DateTime]::UtcNow.ToString('o')

    if ($PSBoundParameters.ContainsKey('Site') -and $Site) { $Record.site = $Site }
    if ($PSBoundParameters.ContainsKey('Note')) { $Record.note = $Note }
    if ($PSBoundParameters.ContainsKey('HostMailbox') -and $HostMailbox) { $Record.hostMailbox = $HostMailbox }

    switch ($State) {
        'active' {
            if ($Record.status -eq 'pool') { $Record.assignedUtc = $now }
            if ([string]::IsNullOrWhiteSpace([string]$Record.site)) {
                throw (New-AliasError -StatusCode 400 -Message 'An active alias must have an associated site.')
            }
        }
        'disabled' {
            $Record.disabledUtc = $now
        }
    }

    $Record.status = $State
    return $Record
}

function Select-PoolAlias {
    <#
    .SYNOPSIS
        Returns the first available warm-pool alias, or $null.
    #>
    [CmdletBinding()]
    param([Parameter(Mandatory)][AllowEmptyCollection()][psobject[]]$Records)

    return ($Records | Where-Object { $_.status -eq 'pool' } | Select-Object -First 1)
}

function Get-AliasInventory {
    <#
    .SYNOPSIS
        Projects active/disabled aliases for the inventory view (excludes pool).
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][AllowEmptyCollection()][psobject[]]$Records,
        [ValidateSet('active', 'disabled')]
        [string]$Status
    )

    $filtered = $Records | Where-Object { $_.status -in @('active', 'disabled') }
    if ($Status) { $filtered = $filtered | Where-Object { $_.status -eq $Status } }

    return @($filtered | ForEach-Object {
            [pscustomobject]@{
                address     = $_.address
                site        = $_.site
                status      = $_.status
                createdUtc  = $_.createdUtc
                assignedUtc = $_.assignedUtc
                note        = $_.note
            }
        })
}

function Get-AliasSite {
    <#
    .SYNOPSIS
        Attribution: returns the site a given alias address belongs to (FR-009).
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][AllowEmptyCollection()][psobject[]]$Records,
        [Parameter(Mandatory)][string]$Address
    )

    $match = $Records | Where-Object { $_.address -eq $Address } | Select-Object -First 1
    if (-not $match) { return $null }
    return $match.site
}

function Get-PoolHealth {
    <#
    .SYNOPSIS
        Computes, per intake mailbox, how many warm aliases to create to reach target.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][AllowEmptyCollection()][psobject[]]$Records,
        [Parameter(Mandatory)][psobject]$Config
    )

    $poolByMailbox = @{}
    foreach ($m in $Config.IntakeMailboxes) { $poolByMailbox[$m] = 0 }
    foreach ($r in ($Records | Where-Object { $_.status -eq 'pool' })) {
        if ($poolByMailbox.ContainsKey($r.hostMailbox)) { $poolByMailbox[$r.hostMailbox]++ }
    }

    return @($Config.IntakeMailboxes | ForEach-Object {
            $current = $poolByMailbox[$_]
            [pscustomobject]@{
                mailbox     = $_
                poolCount   = $current
                belowLow    = $current -lt $Config.PoolLowWater
                needed      = [Math]::Max(0, $Config.PoolTarget - $current)
            }
        })
}

# ---------------------------------------------------------------------------
# Storage I/O (Azure Table Storage via managed-identity bearer token; REST)
# ---------------------------------------------------------------------------

function Get-LedgerAccessToken {
    [CmdletBinding()]
    param()

    # Azure Functions managed-identity endpoint (no secrets stored).
    $endpoint = [Environment]::GetEnvironmentVariable('IDENTITY_ENDPOINT')
    $header = [Environment]::GetEnvironmentVariable('IDENTITY_HEADER')
    $resource = 'https://storage.azure.com/'

    if ([string]::IsNullOrWhiteSpace($endpoint)) {
        throw (New-AliasError -StatusCode 500 -Message 'Managed identity endpoint not available.')
    }

    $uri = "$endpoint`?resource=$([Uri]::EscapeDataString($resource))&api-version=2019-08-01"
    $resp = Invoke-RestMethod -Method Get -Uri $uri -Headers @{ 'X-IDENTITY-HEADER' = $header }
    return $resp.access_token
}

function Invoke-LedgerRequest {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][psobject]$Config,
        [Parameter(Mandatory)][ValidateSet('GET', 'PUT', 'DELETE')][string]$Method,
        [Parameter(Mandatory)][string]$Path,
        [object]$Body
    )

    $token = Get-LedgerAccessToken
    $base = "https://$($Config.StorageAccount).table.core.windows.net"
    $headers = @{
        Authorization  = "Bearer $token"
        'x-ms-version' = '2019-02-02'
        'x-ms-date'    = [DateTime]::UtcNow.ToString('R')
        Accept         = 'application/json;odata=nometadata'
    }

    $params = @{ Method = $Method; Uri = "$base$Path"; Headers = $headers }
    if ($Body) {
        $params.Body = ($Body | ConvertTo-Json -Depth 6 -Compress)
        $params.ContentType = 'application/json'
        $headers['If-Match'] = '*'
    }
    return Invoke-RestMethod @params
}

function ConvertTo-LedgerEntity {
    [CmdletBinding()]
    param([Parameter(Mandatory)][psobject]$Record)

    $entity = [ordered]@{}
    foreach ($p in $Record.PSObject.Properties) {
        if ($null -ne $p.Value) { $entity[$p.Name] = $p.Value }
    }
    return $entity
}

function Get-AliasRecord {
    <#
    .SYNOPSIS
        Reads all alias records for the configured domain from Table Storage.
    #>
    [CmdletBinding()]
    param([Parameter(Mandatory)][psobject]$Config)

    $filter = [Uri]::EscapeDataString("PartitionKey eq '$($Config.Domain)'")
    $result = Invoke-LedgerRequest -Config $Config -Method GET -Path "/$($Config.LedgerTable)()?`$filter=$filter"
    return @($result.value)
}

function Save-AliasRecord {
    <#
    .SYNOPSIS
        Upserts an alias record into Table Storage.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][psobject]$Config,
        [Parameter(Mandatory)][psobject]$Record
    )

    $pk = [Uri]::EscapeDataString($Record.PartitionKey)
    $rk = [Uri]::EscapeDataString($Record.RowKey)
    $path = "/$($Config.LedgerTable)(PartitionKey='$pk',RowKey='$rk')"
    $entity = ConvertTo-LedgerEntity -Record $Record
    Invoke-LedgerRequest -Config $Config -Method PUT -Path $path -Body $entity | Out-Null
    return $Record
}
