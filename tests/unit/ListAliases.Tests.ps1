BeforeAll {
    $modulePath = Join-Path $PSScriptRoot '..' '..' 'src' 'functions' 'modules' 'Aliasaurus' 'Aliasaurus.psd1'
    Import-Module $modulePath -Force

    $script:records = @(
        (New-AliasRecord -Address 'pool1@example.com' -HostMailbox 'intake@example.com' -Status 'pool'),
        (New-AliasRecord -Address 'a@example.com' -HostMailbox 'intake@example.com' -Status 'active' -Site 'netflix'),
        (New-AliasRecord -Address 'b@example.com' -HostMailbox 'graveyard@example.com' -Status 'disabled' -Site 'spammy')
    )
}

Describe 'Get-AliasInventory' {
    It 'excludes warm-pool entries' {
        $inv = Get-AliasInventory -Records $script:records
        $inv.address | Should -Not -Contain 'pool1@example.com'
        $inv.Count | Should -Be 2
    }

    It 'projects address, site, and status' {
        $inv = Get-AliasInventory -Records $script:records
        $active = $inv | Where-Object address -eq 'a@example.com'
        $active.site | Should -Be 'netflix'
        $active.status | Should -Be 'active'
    }

    It 'filters by status when requested' {
        $inv = Get-AliasInventory -Records $script:records -Status 'disabled'
        $inv.Count | Should -Be 1
        $inv[0].address | Should -Be 'b@example.com'
    }
}

Describe 'ConvertTo-AliasResponse' {
    It 'shapes the record to the public API contract' {
        $resp = ConvertTo-AliasResponse -Record ($script:records | Where-Object address -eq 'a@example.com')
        $resp.PSObject.Properties.Name | Should -Be @('address', 'site', 'status', 'createdUtc', 'assignedUtc', 'note')
    }
}

Describe 'Get-AliasSite (attribution)' {
    It 'maps a received address back to its site' {
        Get-AliasSite -Records $script:records -Address 'a@example.com' | Should -Be 'netflix'
    }

    It 'returns nothing for an unknown address' {
        Get-AliasSite -Records $script:records -Address 'nope@example.com' | Should -BeNullOrEmpty
    }
}
