BeforeAll {
    $modulePath = Join-Path $PSScriptRoot '..' '..' 'src' 'functions' 'modules' 'Aliasaurus' 'Aliasaurus.psd1'
    Import-Module $modulePath -Force
}

Describe 'Set-AliasRecordState (disable / enable)' {
    BeforeEach {
        $script:active = New-AliasRecord -Address 'k@example.com' -HostMailbox 'intake@example.com' -Status 'pool'
        $script:active = Set-AliasRecordState -Record $script:active -State 'active' -Site 'shop'
    }

    It 'disables an active alias and records the graveyard host + timestamp' {
        $r = Set-AliasRecordState -Record $script:active -State 'disabled' -HostMailbox 'graveyard@example.com'
        $r.status | Should -Be 'disabled'
        $r.hostMailbox | Should -Be 'graveyard@example.com'
        $r.disabledUtc | Should -Not -BeNullOrEmpty
        $r.site | Should -Be 'shop'
    }

    It 're-enables a disabled alias back to an intake host' {
        $r = Set-AliasRecordState -Record $script:active -State 'disabled' -HostMailbox 'graveyard@example.com'
        $r = Set-AliasRecordState -Record $r -State 'active' -HostMailbox 'intake@example.com'
        $r.status | Should -Be 'active'
        $r.hostMailbox | Should -Be 'intake@example.com'
    }

    It 'rejects an invalid transition (disabled -> pool)' {
        $r = Set-AliasRecordState -Record $script:active -State 'disabled' -HostMailbox 'graveyard@example.com'
        { Set-AliasRecordState -Record $r -State 'pool' } | Should -Throw
    }

    It 'preserves the site through a disable/enable cycle (no collateral change)' {
        $r = Set-AliasRecordState -Record $script:active -State 'disabled' -HostMailbox 'graveyard@example.com'
        $r = Set-AliasRecordState -Record $r -State 'active' -HostMailbox 'intake@example.com'
        $r.site | Should -Be 'shop'
    }
}
