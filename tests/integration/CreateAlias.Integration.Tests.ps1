BeforeDiscovery {
    # Integration tests require a live test tenant + Azure resources.
    # They are skipped unless ALIASAURUS_INTEGRATION is set.
    $script:RunIntegration = [bool]$env:ALIASAURUS_INTEGRATION
}

Describe 'CreateAlias (integration)' -Skip:(-not $script:RunIntegration) {
    It 'issues an alias that delivers a test message to the primary inbox' {
        Set-ItResult -Inconclusive -Because 'Requires a live tenant; implement against the test intake mailbox and a test sender.'
    }

    It 'issued alias is attributable to the requested site via the ledger' {
        Set-ItResult -Inconclusive -Because 'Requires a live tenant.'
    }
}
