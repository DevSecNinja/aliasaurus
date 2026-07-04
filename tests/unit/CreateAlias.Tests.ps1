BeforeAll {
    $modulePath = Join-Path $PSScriptRoot '..' '..' 'src' 'functions' 'modules' 'Aliasaurus' 'Aliasaurus.psd1'
    Import-Module $modulePath -Force
}

Describe 'New-AliasRecord' {
    It 'creates a pool record with derived partition key and no site' {
        $r = New-AliasRecord -Address 'abc123@example.com' -HostMailbox 'intake@example.com'
        $r.status | Should -Be 'pool'
        $r.PartitionKey | Should -Be 'example.com'
        $r.RowKey | Should -Be 'abc123@example.com'
        $r.site | Should -BeNullOrEmpty
        $r.createdUtc | Should -Not -BeNullOrEmpty
    }
}

Describe 'Select-PoolAlias' {
    It 'returns the first pool alias' {
        $records = @(
            (New-AliasRecord -Address 'a@example.com' -HostMailbox 'intake@example.com' -Status 'active' -Site 's'),
            (New-AliasRecord -Address 'b@example.com' -HostMailbox 'intake@example.com' -Status 'pool'),
            (New-AliasRecord -Address 'c@example.com' -HostMailbox 'intake@example.com' -Status 'pool')
        )
        (Select-PoolAlias -Records $records).address | Should -Be 'b@example.com'
    }

    It 'returns nothing when the pool is empty' {
        $records = @(New-AliasRecord -Address 'a@example.com' -HostMailbox 'intake@example.com' -Status 'active' -Site 's')
        Select-PoolAlias -Records $records | Should -BeNullOrEmpty
    }
}

Describe 'Set-AliasRecordState (issue: pool -> active)' {
    It 'assigns the site and sets assignedUtc' {
        $r = New-AliasRecord -Address 'x@example.com' -HostMailbox 'intake@example.com'
        $r = Set-AliasRecordState -Record $r -State 'active' -Site 'netflix'
        $r.status | Should -Be 'active'
        $r.site | Should -Be 'netflix'
        $r.assignedUtc | Should -Not -BeNullOrEmpty
    }

    It 'refuses to activate without a site' {
        $r = New-AliasRecord -Address 'y@example.com' -HostMailbox 'intake@example.com'
        { Set-AliasRecordState -Record $r -State 'active' } | Should -Throw
    }
}

Describe 'Get-PoolHealth' {
    It 'computes the number of aliases needed to reach target' {
        $config = [pscustomobject]@{
            IntakeMailboxes = @('intake@example.com')
            PoolTarget      = 5
            PoolLowWater    = 2
        }
        $records = @(
            (New-AliasRecord -Address 'a@example.com' -HostMailbox 'intake@example.com' -Status 'pool'),
            (New-AliasRecord -Address 'b@example.com' -HostMailbox 'intake@example.com' -Status 'pool')
        )
        $health = Get-PoolHealth -Records $records -Config $config
        $health.poolCount | Should -Be 2
        $health.needed | Should -Be 3
        $health.belowLow | Should -BeFalse
    }
}
