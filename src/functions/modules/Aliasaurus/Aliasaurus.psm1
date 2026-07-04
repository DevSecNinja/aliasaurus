Set-StrictMode -Version Latest

$here = $PSScriptRoot

foreach ($component in @('Common', 'Config', 'AliasGenerator', 'Ledger', 'Mailbox', 'Auth', 'Connect')) {
    . (Join-Path $here "$component.ps1")
}

Export-ModuleMember -Function @(
    'Write-AliasLog',
    'New-AliasError',
    'Resolve-AliasErrorStatus',
    'ConvertTo-AliasResponse',
    'Get-AliasaurusConfig',
    'New-AliasLocalPart',
    'New-AliasAddress',
    'New-SpeakableAlias',
    'New-AliasRecord',
    'Set-AliasRecordState',
    'Select-PoolAlias',
    'Get-AliasInventory',
    'Get-AliasSite',
    'Get-PoolHealth',
    'Get-AliasRecord',
    'Save-AliasRecord',
    'Get-AliasProxyCount',
    'Select-IntakeMailboxWithCapacity',
    'Get-GraveyardMailbox',
    'Add-AliasProxy',
    'Move-AliasProxy',
    'Connect-Aliasaurus',
    'Get-ClientPrincipalName',
    'Test-RequestOwner'
)
