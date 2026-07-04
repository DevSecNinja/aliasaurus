BeforeDiscovery {
    $script:RunIntegration = [bool]$env:ALIASAURUS_INTEGRATION
}

Describe 'SetAliasState (integration)' -Skip:(-not $script:RunIntegration) {
    It 'silently drops mail to a disabled alias (no NDR)' {
        Set-ItResult -Inconclusive -Because 'Requires a live tenant; verify graveyard silent-delete rule and absence of a bounce.'
    }

    It 'leaves other active aliases unaffected while one is disabled' {
        Set-ItResult -Inconclusive -Because 'Requires a live tenant.'
    }

    It 'resumes delivery after re-enabling' {
        Set-ItResult -Inconclusive -Because 'Requires a live tenant.'
    }
}
