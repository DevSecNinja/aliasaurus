Set-StrictMode -Version Latest

# Crockford-free RFC 4648 base32 alphabet, lowercased (no padding).
$script:AliasAlphabet = 'abcdefghijklmnopqrstuvwxyz234567'

function New-AliasLocalPart {
    <#
    .SYNOPSIS
        Generates a random, non-guessable local part for an alias address.
    .DESCRIPTION
        Uses a cryptographically secure RNG. The result is not derived from any
        site name, satisfying the non-guessability requirement (FR-002).
    #>
    [CmdletBinding()]
    param(
        [ValidateRange(8, 32)]
        [int]$Length = 12
    )

    $bytes = [byte[]]::new($Length)
    [System.Security.Cryptography.RandomNumberGenerator]::Fill($bytes)

    $sb = [System.Text.StringBuilder]::new($Length)
    foreach ($b in $bytes) {
        $null = $sb.Append($script:AliasAlphabet[$b % $script:AliasAlphabet.Length])
    }
    return $sb.ToString()
}

function New-AliasAddress {
    <#
    .SYNOPSIS
        Generates a unique alias SMTP address for a domain.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][string]$Domain,

        [string[]]$ExistingAddresses = @(),

        [ValidateRange(8, 32)]
        [int]$Length = 12
    )

    $existing = [System.Collections.Generic.HashSet[string]]::new(
        [string[]]$ExistingAddresses, [System.StringComparer]::OrdinalIgnoreCase)

    for ($attempt = 0; $attempt -lt 25; $attempt++) {
        $candidate = '{0}@{1}' -f (New-AliasLocalPart -Length $Length), $Domain
        if (-not $existing.Contains($candidate)) {
            return $candidate
        }
    }
    throw (New-AliasError -StatusCode 500 -Message 'Unable to generate a unique alias address after 25 attempts.')
}
