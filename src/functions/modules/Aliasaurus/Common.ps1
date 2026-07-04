Set-StrictMode -Version Latest

function Write-AliasLog {
    <#
    .SYNOPSIS
        Emits a structured log line for aliasaurus operations.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [ValidateSet('Debug', 'Information', 'Warning', 'Error')]
        [string]$Level,

        [Parameter(Mandatory)]
        [string]$Message,

        [hashtable]$Data
    )

    $entry = [ordered]@{
        timestamp = [DateTime]::UtcNow.ToString('o')
        level     = $Level
        message   = $Message
    }
    if ($Data) { $entry.data = $Data }

    $json = ($entry | ConvertTo-Json -Compress -Depth 6)

    switch ($Level) {
        'Warning' { Write-Warning $json }
        'Error' { Write-Error $json -ErrorAction Continue }
        default { Write-Information $json -InformationAction Continue }
    }
}

function New-AliasError {
    <#
    .SYNOPSIS
        Builds a control-plane error carrying an HTTP status code.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][int]$StatusCode,
        [Parameter(Mandatory)][string]$Message
    )
    $ex = [System.Exception]::new($Message)
    $ex.Data['StatusCode'] = $StatusCode
    return $ex
}

function Resolve-AliasErrorStatus {
    <#
    .SYNOPSIS
        Extracts an HTTP status code from an error, defaulting to 500.
    #>
    [CmdletBinding()]
    param([Parameter(Mandatory)]$ErrorRecord)

    $ex = if ($ErrorRecord -is [System.Management.Automation.ErrorRecord]) { $ErrorRecord.Exception } else { $ErrorRecord }
    if ($ex -and $ex.Data -and $ex.Data['StatusCode']) { return [int]$ex.Data['StatusCode'] }
    return 500
}

function Get-BodyProperty {
    <#
    .SYNOPSIS
        Null-safe read of a property from an HTTP request body (dictionary or object).
    .DESCRIPTION
        The Functions worker may deliver a JSON body as a hashtable or a
        PSCustomObject; under StrictMode, accessing a missing member on the latter
        throws. This returns $null for absent properties in either case.
    #>
    [CmdletBinding()]
    param($Body, [Parameter(Mandatory)][string]$Name)

    if ($null -eq $Body) { return $null }
    if ($Body -is [System.Collections.IDictionary]) {
        if ($Body.Contains($Name)) { return $Body[$Name] }
        return $null
    }
    $prop = $Body.PSObject.Properties[$Name]
    if ($prop) { return $prop.Value }
    return $null
}

function ConvertTo-AliasResponse {
    [CmdletBinding()]
    param([Parameter(Mandatory)][psobject]$Record)

    [pscustomobject]@{
        address     = $Record.address
        site        = $Record.site
        status      = $Record.status
        createdUtc  = $Record.createdUtc
        assignedUtc = $Record.assignedUtc
        note        = $Record.note
    }
}
