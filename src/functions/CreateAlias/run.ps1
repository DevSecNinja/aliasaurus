using namespace System.Net

param($Request, $TriggerMetadata)

try {
    $config = Get-AliasaurusConfig

    if (-not (Test-RequestOwner -Request $Request -Config $config)) {
        throw (New-AliasError -StatusCode 403 -Message 'Forbidden.')
    }

    Connect-Aliasaurus -Config $config

    $site = $Request.Body.site
    $note = $Request.Body.note
    $format = if ($Request.Body.format) { ([string]$Request.Body.format).ToLowerInvariant() } else { 'base32' }
    if ($format -notin @('base32', 'speakable')) {
        throw (New-AliasError -StatusCode 400 -Message 'format must be "base32" or "speakable".')
    }
    if ([string]::IsNullOrWhiteSpace([string]$site)) {
        throw (New-AliasError -StatusCode 400 -Message 'The "site" property is required.')
    }

    $records = Get-AliasRecord -Config $config

    if ($format -eq 'speakable') {
        # Speakable aliases are generated on demand (the warm pool holds base32).
        $mailbox = Select-IntakeMailboxWithCapacity -Config $config
        $address = New-SpeakableAlias -Domain $config.Domain -ExistingAddresses @($records.address)
        Add-AliasProxy -Mailbox $mailbox -Address $address
        $alias = New-AliasRecord -Address $address -HostMailbox $mailbox -Status 'pool'
    }
    else {
        $alias = Select-PoolAlias -Records $records
        if (-not $alias) {
            Write-AliasLog -Level Warning -Message 'Warm pool empty; falling back to on-demand creation.'
            try {
                $mailbox = Select-IntakeMailboxWithCapacity -Config $config
                $address = New-AliasAddress -Domain $config.Domain -ExistingAddresses @($records.address)
                Add-AliasProxy -Mailbox $mailbox -Address $address
                $alias = New-AliasRecord -Address $address -HostMailbox $mailbox -Status 'pool'
            }
            catch {
                if ((Resolve-AliasErrorStatus -ErrorRecord $_) -eq 500) {
                    throw (New-AliasError -StatusCode 503 -Message 'Pool depleted and on-demand creation failed; retry later.')
                }
                throw
            }
        }
    }

    $alias = Set-AliasRecordState -Record $alias -State 'active' -Site $site -Note $note
    Save-AliasRecord -Config $config -Record $alias | Out-Null

    Write-AliasLog -Level Information -Message 'Alias issued.' -Data @{ address = $alias.address; site = $site; format = $format }

    Push-OutputBinding -Name Response -Value ([HttpResponseContext]@{
            StatusCode = [HttpStatusCode]::Created
            Headers    = @{ 'Content-Type' = 'application/json' }
            Body       = (ConvertTo-AliasResponse -Record $alias | ConvertTo-Json -Depth 6)
        })
}
catch {
    $status = Resolve-AliasErrorStatus -ErrorRecord $_
    Write-AliasLog -Level Error -Message "CreateAlias failed: $($_.Exception.Message)" -Data @{ status = $status }
    Push-OutputBinding -Name Response -Value ([HttpResponseContext]@{
            StatusCode = [int]$status
            Headers    = @{ 'Content-Type' = 'application/json' }
            Body       = (@{ error = $_.Exception.Message } | ConvertTo-Json)
        })
}
