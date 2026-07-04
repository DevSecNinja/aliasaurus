@{
    RootModule        = 'Aliasaurus.psm1'
    ModuleVersion     = '0.1.0'
    GUID              = 'b3f8e2a1-4c7d-4e2b-9f6a-1d2c3b4a5e6f'
    Author            = 'DevSecNinja'
    Description       = 'Shared logic for aliasaurus: alias generation, ledger, and Exchange Online operations.'
    PowerShellVersion = '7.4'
    FunctionsToExport = @(
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
    CmdletsToExport   = @()
    VariablesToExport = @()
    AliasesToExport   = @()
}
