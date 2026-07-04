# Azure Functions PowerShell profile. Runs once per worker (cold start).
# Authentication uses the managed identity; no secrets are read here.

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

# Import the shared aliasaurus module bundled with the app.
Import-Module (Join-Path $PSScriptRoot 'modules' 'Aliasaurus' 'Aliasaurus.psd1') -Force
