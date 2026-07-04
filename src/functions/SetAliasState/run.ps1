using namespace System.Net

param($Request, $TriggerMetadata)

try {
    $config = Get-AliasaurusConfig

    if (-not (Test-RequestOwner -Request $Request -Config $config)) {
        throw (New-AliasError -StatusCode 403 -Message 'Forbidden.')
    }

    Connect-Aliasaurus -Config $config

    $address = [string]$Request.Params.address
    $action = ([string]$Request.Params.action).ToLowerInvariant()
    if ($action -notin @('disable', 'enable')) {
        throw (New-AliasError -StatusCode 400 -Message 'action must be "disable" or "enable".')
    }

    $records = Get-AliasRecord -Config $config
    $alias = $records | Where-Object { $_.address -eq $address } | Select-Object -First 1
    if (-not $alias) {
        throw (New-AliasError -StatusCode 404 -Message "Alias '$address' not found.")
    }

    if ($action -eq 'disable') {
        $target = Get-GraveyardMailbox -Config $config
        Move-AliasProxy -Address $address -From $alias.hostMailbox -To $target
        $alias = Set-AliasRecordState -Record $alias -State 'disabled' -HostMailbox $target
    }
    else {
        $target = Select-IntakeMailboxWithCapacity -Config $config
        Move-AliasProxy -Address $address -From $alias.hostMailbox -To $target
        $alias = Set-AliasRecordState -Record $alias -State 'active' -HostMailbox $target
    }

    Save-AliasRecord -Config $config -Record $alias | Out-Null
    Write-AliasLog -Level Information -Message "Alias $action succeeded." -Data @{ address = $address }

    Push-OutputBinding -Name Response -Value ([HttpResponseContext]@{
            StatusCode  = [HttpStatusCode]::OK
            Headers     = @{ 'Content-Type' = 'application/json' }
            Body        = (ConvertTo-AliasResponse -Record $alias | ConvertTo-Json -Depth 6)
        })
}
catch {
    $status = Resolve-AliasErrorStatus -ErrorRecord $_
    Write-AliasLog -Level Error -Message "SetAliasState failed: $($_.Exception.Message)" -Data @{ status = $status }
    Push-OutputBinding -Name Response -Value ([HttpResponseContext]@{
            StatusCode  = [int]$status
            Headers     = @{ 'Content-Type' = 'application/json' }
            Body        = (@{ error = $_.Exception.Message } | ConvertTo-Json)
        })
}
