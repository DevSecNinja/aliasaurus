#Requires -Version 7.4
<#
.SYNOPSIS
    Runs the aliasaurus Pester unit tests.
#>
[CmdletBinding()]
param(
    [string]$Path = (Join-Path $PSScriptRoot '..' 'tests' 'unit')
)

$ErrorActionPreference = 'Stop'

$pesterMin = [version]'5.5.0'
$pester = Get-Module -ListAvailable Pester | Where-Object { $_.Version -ge $pesterMin } | Select-Object -First 1
if (-not $pester) {
    Write-Host "Installing Pester >= $pesterMin ..."
    Install-Module Pester -MinimumVersion $pesterMin -Scope CurrentUser -Force -SkipPublisherCheck
}
Import-Module Pester -MinimumVersion $pesterMin -Force

$config = New-PesterConfiguration
$config.Run.Path = $Path
$config.Output.Verbosity = 'Detailed'
$config.Run.Exit = $true

Invoke-Pester -Configuration $config
