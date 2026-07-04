param($Timer)

try {
    $config = Get-AliasaurusConfig
    Connect-Aliasaurus -Config $config

    $records = Get-AliasRecord -Config $config
    $health = Get-PoolHealth -Records $records -Config $config

    $created = 0
    foreach ($mailboxHealth in $health) {
        if ($mailboxHealth.needed -le 0) { continue }

        $capacity = $config.MaxProxiesPerMailbox - (Get-AliasProxyCount -Mailbox $mailboxHealth.mailbox)
        $toCreate = [Math]::Min($mailboxHealth.needed, [Math]::Max(0, $capacity))

        for ($i = 0; $i -lt $toCreate; $i++) {
            $existing = @((Get-AliasRecord -Config $config).address)
            $address = New-AliasAddress -Domain $config.Domain -ExistingAddresses $existing
            Add-AliasProxy -Mailbox $mailboxHealth.mailbox -Address $address
            $record = New-AliasRecord -Address $address -HostMailbox $mailboxHealth.mailbox -Status 'pool'
            Save-AliasRecord -Config $config -Record $record | Out-Null
            $created++
        }
    }

    Write-AliasLog -Level Information -Message 'Pool replenishment complete.' -Data @{ created = $created }
}
catch {
    Write-AliasLog -Level Error -Message "ReplenishPool failed: $($_.Exception.Message)"
    throw
}
