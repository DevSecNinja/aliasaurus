BeforeAll {
    $modulePath = Join-Path $PSScriptRoot '..' '..' 'src' 'functions' 'modules' 'Aliasaurus' 'Aliasaurus.psd1'
    Import-Module $modulePath -Force
}

Describe 'New-AliasLocalPart' {
    It 'produces a string of the requested length' {
        (New-AliasLocalPart -Length 12).Length | Should -Be 12
        (New-AliasLocalPart -Length 16).Length | Should -Be 16
    }

    It 'uses only lowercase base32 characters' {
        1..50 | ForEach-Object {
            New-AliasLocalPart | Should -MatchExactly '^[a-z2-7]+$'
        }
    }

    It 'is highly unlikely to collide' {
        $set = 1..500 | ForEach-Object { New-AliasLocalPart -Length 12 }
        ($set | Sort-Object -Unique).Count | Should -Be 500
    }
}

Describe 'New-AliasAddress' {
    It 'appends the domain' {
        New-AliasAddress -Domain 'example.com' | Should -MatchExactly '^[a-z2-7]+@example\.com$'
    }

    It 'is not derivable from any site name (non-guessable)' {
        $addr = New-AliasAddress -Domain 'example.com'
        $local = ($addr -split '@')[0]
        # A random base32 local part should not contain a real word/site token.
        $local | Should -Not -Match 'netflix|amazon|github'
    }

    It 'avoids collisions with existing addresses' {
        $existing = 1..20 | ForEach-Object { New-AliasAddress -Domain 'example.com' }
        $new = New-AliasAddress -Domain 'example.com' -ExistingAddresses $existing
        $existing | Should -Not -Contain $new
    }
}
