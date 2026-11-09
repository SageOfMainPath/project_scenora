$ErrorActionPreference = 'Stop'

$projectRoot = $PSScriptRoot
$backendDirectory = Join-Path $projectRoot 'server'
$cloudflaredCommand = Get-Command cloudflared -ErrorAction SilentlyContinue
$cloudflaredPath = if ($cloudflaredCommand) {
    $cloudflaredCommand.Source
} else {
    'C:\Program Files (x86)\cloudflared\cloudflared.exe'
}

if (-not (Test-Path -LiteralPath $cloudflaredPath)) {
    throw 'cloudflared is not installed. Reinstall Cloudflare Tunnel and try again.'
}

$backendProcess = $null
$startedBackend = $false

function Test-ScenoraBackend {
    try {
        $health = Invoke-RestMethod -Uri 'http://127.0.0.1:8080/health' -TimeoutSec 2
        return $health.status -eq 'ok'
    } catch {
        return $false
    }
}

try {
    if (-not (Test-ScenoraBackend)) {
        $dartCommand = Get-Command dart -ErrorAction Stop
        Write-Host 'Starting the SCENORA backend...' -ForegroundColor Cyan
        $backendProcess = Start-Process `
            -FilePath $dartCommand.Source `
            -ArgumentList @('run', 'bin/server.dart') `
            -WorkingDirectory $backendDirectory `
            -WindowStyle Hidden `
            -PassThru
        $startedBackend = $true

        $backendReady = $false
        for ($attempt = 0; $attempt -lt 20; $attempt++) {
            Start-Sleep -Milliseconds 500
            if (Test-ScenoraBackend) {
                $backendReady = $true
                break
            }
        }
        if (-not $backendReady) {
            throw 'The SCENORA backend did not start on port 8080.'
        }
    }

    Write-Host ''
    Write-Host 'Backend is ready.' -ForegroundColor Green
    Write-Host 'Starting a temporary Cloudflare URL...' -ForegroundColor Cyan
    Write-Host 'Copy the https://...trycloudflare.com URL into:' -ForegroundColor Yellow
    Write-Host 'Profile > Settings > Backend server > Test & save' -ForegroundColor Yellow
    Write-Host 'Keep this window open during the presentation. Press Ctrl+C when finished.'
    Write-Host ''

    $urlDisplayed = $false

    # Windows PowerShell 5 converts native stderr output into ErrorRecord
    # objects. cloudflared writes its normal status messages to stderr, so the
    # script-level "Stop" preference would otherwise terminate the tunnel.
    $previousErrorActionPreference = $ErrorActionPreference
    $ErrorActionPreference = 'Continue'
    & $cloudflaredPath tunnel --url 'http://127.0.0.1:8080' --no-autoupdate 2>&1 |
        ForEach-Object {
            $line = "$_"
            Write-Host $line
            if (-not $urlDisplayed -and
                $line -match 'https://(?!api\.)[a-z0-9-]+\.trycloudflare\.com\b') {
                $tunnelUrl = $Matches[0]
                $urlDisplayed = $true
                try {
                    Set-Clipboard -Value $tunnelUrl
                    $clipboardMessage = 'The URL was also copied to your clipboard.'
                } catch {
                    $clipboardMessage = 'Copy the URL shown below.'
                }
                Write-Host ''
                Write-Host '============================================================' -ForegroundColor Green
                Write-Host 'SCENORA BACKEND URL:' -ForegroundColor Green
                Write-Host $tunnelUrl -ForegroundColor Yellow
                Write-Host $clipboardMessage -ForegroundColor Green
                Write-Host '============================================================' -ForegroundColor Green
                Write-Host ''
            }
        }
    $ErrorActionPreference = $previousErrorActionPreference

    if (-not $urlDisplayed) {
        Write-Host ''
        Write-Host 'Cloudflare could not create a public URL.' -ForegroundColor Red
        Write-Host 'Check the internet connection and Windows Firewall, then run this file again.' -ForegroundColor Yellow
    }
} finally {
    if ($startedBackend -and $backendProcess -and -not $backendProcess.HasExited) {
        Stop-Process -Id $backendProcess.Id
    }
}
