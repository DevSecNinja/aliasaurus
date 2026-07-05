#Requires -Version 7.4
<#
.SYNOPSIS
    Runs aliasaurus locally with an in-memory mock backend, to preview the web UI.
.DESCRIPTION
    Serves the real SPA (src/functions/WebApp/wwwroot/index.html) and implements
    the /aliases API against an in-memory store, reusing the real Aliasaurus
    module logic (alias generation, warm pool, state transitions, speakable
    format). No Azure, Exchange Online, Table Storage, or Easy Auth are needed.

    This is a development preview only. It mocks persistence (in-memory) and the
    Exchange proxy operations (no-op); everything else is the production code.
.EXAMPLE
    ./build/Start-DevServer.ps1
    Then open http://localhost:7071/ in a browser.
#>
[CmdletBinding()]
param(
    [int]$Port = 7071,
    [string]$Domain = 'localdev.example'
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

$repoRoot = Split-Path $PSScriptRoot -Parent
Import-Module (Join-Path $repoRoot 'src' 'functions' 'modules' 'Aliasaurus' 'Aliasaurus.psd1') -Force
$indexPath = Join-Path $repoRoot 'src' 'functions' 'WebApp' 'wwwroot' 'index.html'

# ---- in-memory store (mock ledger) -----------------------------------------
$store = [System.Collections.Generic.List[object]]::new()
$intake = 'intake@localdev'
$graveyard = 'graveyard@localdev'

function Get-Address { @($store | ForEach-Object { $_.address }) }

# Seed a warm pool and a few sample aliases so the UI has content.
for ($i = 0; $i -lt 10; $i++) {
    $store.Add((New-AliasRecord -Address (New-AliasAddress -Domain $Domain -ExistingAddresses (Get-Address)) -HostMailbox $intake -Status 'pool'))
}
foreach ($site in @('example-shop', 'newsletter-daily', 'social-app')) {
    $rec = New-AliasRecord -Address (New-AliasAddress -Domain $Domain -ExistingAddresses (Get-Address)) -HostMailbox $intake -Status 'pool'
    $store.Add((Set-AliasRecordState -Record $rec -State 'active' -Site $site))
}
$spam = New-AliasRecord -Address (New-SpeakableAlias -Domain $Domain -ExistingAddresses (Get-Address)) -HostMailbox $intake -Status 'pool'
$spam = Set-AliasRecordState -Record $spam -State 'active' -Site 'spammy-forum'
$spam = Set-AliasRecordState -Record $spam -State 'disabled' -HostMailbox $graveyard
$store.Add($spam)

# ---- mock request handlers (mirror the Functions logic) --------------------
function Invoke-CreateAlias {
    param([string]$Body)
    $req = if ($Body) { $Body | ConvertFrom-Json } else { $null }
    $reqSite = Get-BodyProperty -Body $req -Name 'site'
    $reqNote = Get-BodyProperty -Body $req -Name 'note'
    if ([string]::IsNullOrWhiteSpace([string]$reqSite)) {
        return @{ Status = 400; Json = @{ error = 'The "site" property is required.' } }
    }
    $formatValue = Get-BodyProperty -Body $req -Name 'format'
    $format = if ($formatValue) { ([string]$formatValue).ToLowerInvariant() } else { 'base32' }

    if ($format -eq 'speakable') {
        $address = New-SpeakableAlias -Domain $Domain -ExistingAddresses (Get-Address)
        $alias = New-AliasRecord -Address $address -HostMailbox $intake -Status 'pool'
    }
    else {
        $alias = Select-PoolAlias -Records $store.ToArray()
        if (-not $alias) {
            $address = New-AliasAddress -Domain $Domain -ExistingAddresses (Get-Address)
            $alias = New-AliasRecord -Address $address -HostMailbox $intake -Status 'pool'
            $store.Add($alias)
        }
    }
    if ($format -eq 'speakable') { $store.Add($alias) }
    $null = Set-AliasRecordState -Record $alias -State 'active' -Site $reqSite -Note $reqNote
    return @{ Status = 201; Json = (ConvertTo-AliasResponse -Record $alias) }
}

function Invoke-SetState {
    param([string]$Address, [string]$Action)
    $alias = $store | Where-Object { $_.address -eq $Address } | Select-Object -First 1
    if (-not $alias) { return @{ Status = 404; Json = @{ error = "Alias '$Address' not found." } } }
    if ($Action -eq 'disable') {
        $null = Set-AliasRecordState -Record $alias -State 'disabled' -HostMailbox $graveyard
    }
    elseif ($Action -eq 'enable') {
        $null = Set-AliasRecordState -Record $alias -State 'active' -HostMailbox $intake
    }
    else { return @{ Status = 400; Json = @{ error = 'action must be "disable" or "enable".' } } }
    return @{ Status = 200; Json = (ConvertTo-AliasResponse -Record $alias) }
}

# ---- HTTP listener ---------------------------------------------------------
$listener = [System.Net.HttpListener]::new()
$prefix = "http://localhost:$Port/"
$listener.Prefixes.Add($prefix)
$listener.Start()
Write-Host "aliasaurus dev server (mock) listening on $prefix"
Write-Host "Open $prefix in your browser. Press Ctrl+C to stop."

try {
    while ($listener.IsListening) {
        $ctx = $listener.GetContext()
        $req = $ctx.Request
        $res = $ctx.Response
        $path = $req.Url.AbsolutePath.TrimEnd('/')
        $method = $req.HttpMethod

        $status = 200
        $contentType = 'application/json'
        $bodyText = ''

        try {
            if ($method -eq 'GET' -and ($path -eq '' -or $path -eq '/index.html')) {
                $contentType = 'text/html; charset=utf-8'
                $bodyText = Get-Content -Path $indexPath -Raw
            }
            elseif ($method -eq 'GET' -and $path -eq '/aliases') {
                $inv = Get-AliasInventory -Records $store.ToArray()
                $bodyText = ($inv | ConvertTo-Json -Depth 6 -AsArray)
            }
            elseif ($method -eq 'POST' -and $path -eq '/aliases') {
                $reader = [System.IO.StreamReader]::new($req.InputStream, $req.ContentEncoding)
                $result = Invoke-CreateAlias -Body $reader.ReadToEnd()
                $reader.Dispose()
                $status = $result.Status
                $bodyText = ($result.Json | ConvertTo-Json -Depth 6)
            }
            elseif ($method -eq 'POST' -and $path -match '^/aliases/(.+)/(disable|enable)$') {
                $result = Invoke-SetState -Address ([Uri]::UnescapeDataString($Matches[1])) -Action $Matches[2]
                $status = $result.Status
                $bodyText = ($result.Json | ConvertTo-Json -Depth 6)
            }
            else {
                $status = 404
                $bodyText = (@{ error = 'Not found' } | ConvertTo-Json)
            }
        }
        catch {
            $status = 500
            $bodyText = (@{ error = $_.Exception.Message } | ConvertTo-Json)
        }

        $buffer = [System.Text.Encoding]::UTF8.GetBytes($bodyText)
        $res.StatusCode = $status
        $res.ContentType = $contentType
        $res.ContentLength64 = $buffer.Length
        $res.OutputStream.Write($buffer, 0, $buffer.Length)
        $res.OutputStream.Close()
        Write-Host ("{0} {1} -> {2}" -f $method, ($path ? $path : '/'), $status)
    }
}
finally {
    $listener.Stop()
    $listener.Close()
}
