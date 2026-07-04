#Requires -Version 7.4
<#
.SYNOPSIS
    Runs PSScriptAnalyzer over the aliasaurus PowerShell sources.
#>
[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'
$repoRoot = Join-Path $PSScriptRoot '..'

if (-not (Get-Module -ListAvailable PSScriptAnalyzer)) {
    Write-Host 'Installing PSScriptAnalyzer ...'
    Install-Module PSScriptAnalyzer -Scope CurrentUser -Force
}
Import-Module PSScriptAnalyzer -Force

$settings = Join-Path $repoRoot 'PSScriptAnalyzerSettings.psd1'
$targets = @('src', 'scripts', 'build', 'tests') | ForEach-Object { Join-Path $repoRoot $_ }

$results = foreach ($target in $targets) {
    if (Test-Path $target) {
        Invoke-ScriptAnalyzer -Path $target -Recurse -Settings $settings
    }
}
if ($results) {
    $results | Format-Table -AutoSize
    if ($results | Where-Object Severity -eq 'Error') {
        throw "PSScriptAnalyzer found $($results.Count) issue(s), including errors."
    }
    Write-Warning "PSScriptAnalyzer found $($results.Count) warning(s)."
}
else {
    Write-Host 'PSScriptAnalyzer: no issues.'
}
