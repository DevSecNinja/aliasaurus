Set-StrictMode -Version Latest

function Get-AliasProxyCount {
    <#
    .SYNOPSIS
        Returns the number of SMTP proxy addresses on a mailbox.
    #>
    [CmdletBinding()]
    param([Parameter(Mandatory)][string]$Mailbox)

    $mbx = Get-Mailbox -Identity $Mailbox -ErrorAction Stop
    return @($mbx.EmailAddresses | Where-Object { $_ -like 'smtp:*' }).Count
}

function Select-IntakeMailboxWithCapacity {
    <#
    .SYNOPSIS
        Returns the first intake mailbox with room for another proxy address.
    .DESCRIPTION
        Honors the per-mailbox proxy cap (FR-013). Throws HTTP 507 when all
        intake mailboxes are at capacity.
    #>
    [CmdletBinding()]
    param([Parameter(Mandatory)][psobject]$Config)

    foreach ($mailbox in $Config.IntakeMailboxes) {
        if ((Get-AliasProxyCount -Mailbox $mailbox) -lt $Config.MaxProxiesPerMailbox) {
            return $mailbox
        }
    }
    throw (New-AliasError -StatusCode 507 -Message 'All intake mailboxes are at the proxy-address limit.')
}

function Add-AliasProxy {
    <#
    .SYNOPSIS
        Adds an alias as a secondary SMTP proxy address on a mailbox.
    #>
    [CmdletBinding(SupportsShouldProcess)]
    param(
        [Parameter(Mandatory)][string]$Mailbox,
        [Parameter(Mandatory)][string]$Address
    )

    if ($PSCmdlet.ShouldProcess($Mailbox, "Add proxy $Address")) {
        Set-Mailbox -Identity $Mailbox -EmailAddresses @{ add = $Address } -ErrorAction Stop
    }
}

function Move-AliasProxy {
    <#
    .SYNOPSIS
        Moves an alias proxy address from one mailbox to another.
    .DESCRIPTION
        Used to disable (intake -> graveyard) and enable (graveyard -> intake)
        aliases. Add to the target first, then remove from the source, so mail is
        never rejected during the move.
    #>
    [CmdletBinding(SupportsShouldProcess)]
    param(
        [Parameter(Mandatory)][string]$Address,
        [Parameter(Mandatory)][string]$From,
        [Parameter(Mandatory)][string]$To
    )

    if ($PSCmdlet.ShouldProcess($Address, "Move proxy $From -> $To")) {
        Set-Mailbox -Identity $To -EmailAddresses @{ add = $Address } -ErrorAction Stop
        Set-Mailbox -Identity $From -EmailAddresses @{ remove = $Address } -ErrorAction Stop
    }
}

function Get-GraveyardMailbox {
    <#
    .SYNOPSIS
        Returns a graveyard mailbox with capacity for a disabled alias.
    #>
    [CmdletBinding()]
    param([Parameter(Mandatory)][psobject]$Config)

    foreach ($mailbox in $Config.GraveyardMailboxes) {
        if ((Get-AliasProxyCount -Mailbox $mailbox) -lt $Config.MaxProxiesPerMailbox) {
            return $mailbox
        }
    }
    throw (New-AliasError -StatusCode 507 -Message 'All graveyard mailboxes are at the proxy-address limit.')
}
