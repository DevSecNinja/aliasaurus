#Requires -Modules ExchangeOnlineManagement
<#
.SYNOPSIS
    Provisions the Exchange Online prerequisites for aliasaurus (idempotent).
.DESCRIPTION
    Creates the intake and graveyard shared mailboxes, configures intake
    forwarding to the primary mailbox, creates the graveyard silent-delete
    mail-flow rule, and grants the Functions managed identity a least-privilege
    Exchange management role scoped to the cmdlets aliasaurus uses.

    Run interactively as an Exchange administrator. No secrets are stored.
.NOTES
    See infra/exchange-prereqs.md for context and Constitution Principle III.
#>
[CmdletBinding(SupportsShouldProcess)]
param(
    [Parameter(Mandatory)][string]$Organization,
    [Parameter(Mandatory)][string]$PrimaryMailbox,
    [Parameter(Mandatory)][string]$IntakeMailbox,
    [Parameter(Mandatory)][string]$GraveyardMailbox,
    [Parameter(Mandatory)][string]$ManagedIdentityAppId,
    [Parameter(Mandatory)][string]$ManagedIdentityObjectId,
    [string]$RoleName = 'Aliasaurus-Mailbox-Management',
    [string]$MailFlowRuleName = 'Aliasaurus-Graveyard-Drop'
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

Connect-ExchangeOnline -Organization $Organization -ShowBanner:$false

function New-SharedMailboxIfMissing {
    [CmdletBinding(SupportsShouldProcess)]
    param([string]$Upn, [string]$DisplayName)
    if (Get-Mailbox -Identity $Upn -ErrorAction SilentlyContinue) {
        Write-Host "Mailbox '$Upn' already exists; skipping."
        return
    }
    if ($PSCmdlet.ShouldProcess($Upn, 'Create shared mailbox')) {
        New-Mailbox -Shared -Name $DisplayName -PrimarySmtpAddress $Upn | Out-Null
        Write-Host "Created shared mailbox '$Upn'."
    }
}

# 1. Shared mailboxes.
New-SharedMailboxIfMissing -Upn $IntakeMailbox -DisplayName 'Aliasaurus Intake'
New-SharedMailboxIfMissing -Upn $GraveyardMailbox -DisplayName 'Aliasaurus Graveyard'

# 2. Intake forwards to the primary mailbox.
if ($PSCmdlet.ShouldProcess($IntakeMailbox, "Forward to $PrimaryMailbox")) {
    Set-Mailbox -Identity $IntakeMailbox -ForwardingAddress $PrimaryMailbox -DeliverToMailboxAndForward $false
    Write-Host "Configured intake forwarding to '$PrimaryMailbox'."
}

# 3. Graveyard silent-delete mail-flow rule.
if (Get-TransportRule -Identity $MailFlowRuleName -ErrorAction SilentlyContinue) {
    Write-Host "Mail-flow rule '$MailFlowRuleName' already exists; skipping."
}
elseif ($PSCmdlet.ShouldProcess($MailFlowRuleName, 'Create silent-delete rule')) {
    New-TransportRule -Name $MailFlowRuleName `
        -SentTo $GraveyardMailbox `
        -DeleteMessage $true | Out-Null
    Write-Host "Created silent-delete mail-flow rule '$MailFlowRuleName'."
}

# 4. Least-privilege Exchange role for the managed identity.
if (-not (Get-ServicePrincipal -Identity $ManagedIdentityObjectId -ErrorAction SilentlyContinue)) {
    if ($PSCmdlet.ShouldProcess($ManagedIdentityObjectId, 'Register Exchange service principal')) {
        New-ServicePrincipal -AppId $ManagedIdentityAppId -ObjectId $ManagedIdentityObjectId `
            -DisplayName 'Aliasaurus Functions MI' | Out-Null
        Write-Host 'Registered Exchange service principal for the managed identity.'
    }
}

if (-not (Get-ManagementRole -Identity $RoleName -ErrorAction SilentlyContinue)) {
    if ($PSCmdlet.ShouldProcess($RoleName, 'Create scoped management role')) {
        # Parent off the built-in "Mail Recipients" role, then trim to the cmdlets we use.
        New-ManagementRole -Name $RoleName -Parent 'Mail Recipients' | Out-Null
        Get-ManagementRoleEntry "$RoleName\*" |
            Where-Object { $_.Name -notin @('Set-Mailbox', 'Get-Mailbox') } |
            ForEach-Object { Remove-ManagementRoleEntry -Identity "$RoleName\$($_.Name)" -Confirm:$false }
        Write-Host "Created scoped management role '$RoleName' (Set-Mailbox, Get-Mailbox)."
    }
}

$assignmentName = "$RoleName-Assignment"
if (-not (Get-ManagementRoleAssignment -Identity $assignmentName -ErrorAction SilentlyContinue)) {
    if ($PSCmdlet.ShouldProcess($assignmentName, 'Assign role to managed identity')) {
        New-ManagementRoleAssignment -Name $assignmentName -Role $RoleName -App $ManagedIdentityObjectId | Out-Null
        Write-Host "Assigned '$RoleName' to the managed identity."
    }
}

Write-Host 'Exchange prerequisites complete.'
