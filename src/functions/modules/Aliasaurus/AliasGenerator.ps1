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

    $existing = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::OrdinalIgnoreCase)
    foreach ($addr in $ExistingAddresses) {
        if ($addr) { [void]$existing.Add([string]$addr) }
    }

    for ($attempt = 0; $attempt -lt 25; $attempt++) {
        $candidate = '{0}@{1}' -f (New-AliasLocalPart -Length $Length), $Domain
        if (-not $existing.Contains($candidate)) {
            return $candidate
        }
    }
    throw (New-AliasError -StatusCode 500 -Message 'Unable to generate a unique alias address after 25 attempts.')
}

# Curated, easy-to-say, unambiguous words for speakable aliases.
$script:SpeakableWords = @(
    'apple', 'anchor', 'arrow', 'badge', 'bagel', 'banjo', 'basket', 'beacon',
    'beaver', 'bison', 'bottle', 'brave', 'bridge', 'butter', 'cactus', 'camel',
    'candle', 'canyon', 'cedar', 'cherry', 'clover', 'cobra', 'comet', 'copper',
    'coral', 'cotton', 'crayon', 'dolphin', 'dragon', 'eagle', 'ember', 'falcon',
    'fern', 'fiddle', 'forest', 'garden', 'ginger', 'granite', 'harbor', 'hazel',
    'hedgehog', 'igloo', 'island', 'jacket', 'jaguar', 'jasmine', 'jungle', 'kettle',
    'kitten', 'ladder', 'lantern', 'lemon', 'lily', 'lobster', 'maple', 'marble',
    'meadow', 'melon', 'mitten', 'monkey', 'nectar', 'noodle', 'ocean', 'olive',
    'orbit', 'otter', 'panda', 'parrot', 'peach', 'pebble', 'pepper', 'pigeon',
    'pillow', 'pilot', 'pine', 'planet', 'pony', 'pretzel', 'pumpkin', 'rabbit',
    'ranch', 'raven', 'ribbon', 'river', 'rocket', 'saddle', 'salmon', 'sandal',
    'sardine', 'scooter', 'seal', 'silver', 'sparrow', 'spruce', 'squid', 'stone',
    'sunset', 'tiger', 'tomato', 'turtle', 'velvet', 'walnut', 'willow', 'zebra'
)

function New-SpeakableAlias {
    <#
    .SYNOPSIS
        Generates a unique, non-guessable alias that is easy to dictate aloud.
    .DESCRIPTION
        Combines random words from a curated unambiguous wordlist plus two digits,
        e.g. brave-otter-cactus-42@domain. Uses a cryptographic RNG. The result is
        not derived from any site name (FR-002, FR-009).
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][string]$Domain,
        [string[]]$ExistingAddresses = @(),
        [ValidateRange(2, 5)]
        [int]$WordCount = 3
    )

    $existing = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::OrdinalIgnoreCase)
    foreach ($addr in $ExistingAddresses) {
        if ($addr) { [void]$existing.Add([string]$addr) }
    }

    for ($attempt = 0; $attempt -lt 25; $attempt++) {
        $words = for ($i = 0; $i -lt $WordCount; $i++) {
            $script:SpeakableWords[[System.Security.Cryptography.RandomNumberGenerator]::GetInt32($script:SpeakableWords.Length)]
        }
        $digits = '{0:D2}' -f [System.Security.Cryptography.RandomNumberGenerator]::GetInt32(100)
        $local = ((@($words) + $digits) -join '-')
        $candidate = '{0}@{1}' -f $local, $Domain
        if (-not $existing.Contains($candidate)) {
            return $candidate
        }
    }
    throw (New-AliasError -StatusCode 500 -Message 'Unable to generate a unique speakable alias after 25 attempts.')
}
