@{
    Severity     = @('Error', 'Warning')
    ExcludeRules = @(
        # Console/tooling scripts (build/, scripts/) intentionally use Write-Host
        # for interactive operator output. The Functions runtime code uses
        # Write-AliasLog (Write-Information/Warning) instead.
        'PSAvoidUsingWriteHost',
        # Azure Functions binding parameters (Timer, TriggerMetadata) are required
        # by the runtime signature even when unused; and closure variables used in
        # nested functions are miscounted as unused.
        'PSReviewUnusedParameter',
        # New-/Set- helpers here are pure, in-memory builders/transformers with no
        # side effects. The real state-changing functions (Add-AliasProxy,
        # Move-AliasProxy) explicitly implement SupportsShouldProcess.
        'PSUseShouldProcessForStateChangingFunctions'
    )
}
