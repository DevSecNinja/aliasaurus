BeforeAll {
    $modulePath = Join-Path $PSScriptRoot '..' '..' 'src' 'functions' 'modules' 'Aliasaurus' 'Aliasaurus.psd1'
    Import-Module $modulePath -Force

    $script:config = [pscustomobject]@{ OwnerUpn = 'owner@example.com' }
    function New-Req([hashtable]$headers) { [pscustomobject]@{ Headers = $headers } }
}

Describe 'Test-RequestOwner' {
    AfterEach { $env:AZURE_FUNCTIONS_ENVIRONMENT = $null }

    It 'allows the configured owner' {
        $req = New-Req @{ 'x-ms-client-principal-name' = 'owner@example.com' }
        Test-RequestOwner -Request $req -Config $script:config | Should -BeTrue
    }

    It 'is case-insensitive on the owner UPN' {
        $req = New-Req @{ 'x-ms-client-principal-name' = 'Owner@Example.com' }
        Test-RequestOwner -Request $req -Config $script:config | Should -BeTrue
    }

    It 'denies a different authenticated identity' {
        $req = New-Req @{ 'x-ms-client-principal-name' = 'intruder@example.com' }
        Test-RequestOwner -Request $req -Config $script:config | Should -BeFalse
    }

    It 'denies when no principal header and not local dev' {
        $env:AZURE_FUNCTIONS_ENVIRONMENT = $null
        Test-RequestOwner -Request (New-Req @{}) -Config $script:config | Should -BeFalse
    }

    It 'bypasses the check in local development' {
        $env:AZURE_FUNCTIONS_ENVIRONMENT = 'Development'
        Test-RequestOwner -Request (New-Req @{}) -Config $script:config | Should -BeTrue
    }
}
