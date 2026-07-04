using namespace System.Net

param($Request, $TriggerMetadata)

try {
    $config = Get-AliasaurusConfig

    $statusFilter = $null
    if ($Request.Query.status) {
        $statusFilter = [string]$Request.Query.status
        if ($statusFilter -notin @('active', 'disabled')) {
            throw (New-AliasError -StatusCode 400 -Message 'status filter must be "active" or "disabled".')
        }
    }

    $records = Get-AliasRecord -Config $config
    $inventory = if ($statusFilter) {
        Get-AliasInventory -Records $records -Status $statusFilter
    }
    else {
        Get-AliasInventory -Records $records
    }

    Push-OutputBinding -Name Response -Value ([HttpResponseContext]@{
            StatusCode  = [HttpStatusCode]::OK
            Headers     = @{ 'Content-Type' = 'application/json' }
            Body        = ($inventory | ConvertTo-Json -Depth 6 -AsArray)
        })
}
catch {
    $status = Resolve-AliasErrorStatus -ErrorRecord $_
    Write-AliasLog -Level Error -Message "ListAliases failed: $($_.Exception.Message)" -Data @{ status = $status }
    Push-OutputBinding -Name Response -Value ([HttpResponseContext]@{
            StatusCode  = [int]$status
            Headers     = @{ 'Content-Type' = 'application/json' }
            Body        = (@{ error = $_.Exception.Message } | ConvertTo-Json)
        })
}
