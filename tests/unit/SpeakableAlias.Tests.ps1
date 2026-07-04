BeforeAll {
    $modulePath = Join-Path $PSScriptRoot '..' '..' 'src' 'functions' 'modules' 'Aliasaurus' 'Aliasaurus.psd1'
    Import-Module $modulePath -Force
}

Describe 'New-SpeakableAlias' {
    It 'produces a word-based, hyphenated local part with trailing digits' {
        $addr = New-SpeakableAlias -Domain 'example.com'
        $addr | Should -MatchExactly '^([a-z]+-){3}[0-9]{2}@example\.com$'
    }

    It 'honors the requested word count' {
        $addr = New-SpeakableAlias -Domain 'example.com' -WordCount 4
        $local = ($addr -split '@')[0]
        ($local -split '-').Count | Should -Be 5  # 4 words + digits group
    }

    It 'is not derivable from a site name (non-guessable)' {
        1..20 | ForEach-Object {
            (New-SpeakableAlias -Domain 'example.com') | Should -Not -Match 'netflix|amazon|github'
        }
    }

    It 'avoids collisions with existing addresses' {
        $existing = 1..15 | ForEach-Object { New-SpeakableAlias -Domain 'example.com' }
        $new = New-SpeakableAlias -Domain 'example.com' -ExistingAddresses $existing
        $existing | Should -Not -Contain $new
    }
}
