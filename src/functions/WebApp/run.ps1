using namespace System.Net

param($Request, $TriggerMetadata)

# Serves the single-page web UI. Access is gated by App Service Authentication
# (Easy Auth); this function only returns static content.
$indexPath = Join-Path $PSScriptRoot 'wwwroot' 'index.html'
$html = Get-Content -Path $indexPath -Raw

Push-OutputBinding -Name Response -Value ([HttpResponseContext]@{
        StatusCode = [HttpStatusCode]::OK
        Headers    = @{ 'Content-Type' = 'text/html; charset=utf-8' }
        Body       = $html
    })
