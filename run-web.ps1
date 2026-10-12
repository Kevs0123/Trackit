$ErrorActionPreference = 'Stop'

$repoRoot = $PSScriptRoot
$apiPath = Join-Path $repoRoot 'apps/api'
$mobilePath = Join-Path $repoRoot 'apps/mobile'
$apiProcess = $null
$apiPort = 8000

function Test-LocalPort {
  param([int]$Port)

  $client = New-Object System.Net.Sockets.TcpClient
  try {
    $client.Connect('127.0.0.1', $Port)
    return $true
  } catch {
    return $false
  } finally {
    $client.Dispose()
  }
}

try {
  $php = Get-Command php -ErrorAction SilentlyContinue
  if (-not $php) { throw 'PHP is required. Install PHP and make sure php is on PATH.' }
  $flutter = Get-Command flutter -ErrorAction SilentlyContinue
  if (-not $flutter) { throw 'Flutter is required. Install Flutter and make sure flutter is on PATH.' }

  if (-not (Test-Path (Join-Path $apiPath '.env'))) {
    throw 'apps/api/.env is missing. Copy .env.example to .env, set up the app key and database once, then rerun this script.'
  }
  if (Test-LocalPort -Port $apiPort) {
    throw "Port $apiPort is already in use. Stop the existing service, then rerun this script."
  }

  if (-not (Test-Path (Join-Path $apiPath 'vendor/autoload.php'))) {
    if (-not (Get-Command composer -ErrorAction SilentlyContinue)) {
      throw 'Composer is required to install the API dependencies.'
    }
    Push-Location $apiPath
    try {
      & composer install
      if ($LASTEXITCODE -ne 0) { throw 'composer install failed.' }
    } finally {
      Pop-Location
    }
  }

  if (-not (Test-Path (Join-Path $mobilePath '.dart_tool/package_config.json'))) {
    Push-Location $mobilePath
    try {
      & flutter pub get
      if ($LASTEXITCODE -ne 0) { throw 'flutter pub get failed.' }
    } finally {
      Pop-Location
    }
  }

  $logPath = Join-Path $apiPath 'storage/logs'
  New-Item -ItemType Directory -Path $logPath -Force | Out-Null
  $stdoutLog = Join-Path $logPath 'monorepo-dev-server.log'
  $stderrLog = Join-Path $logPath 'monorepo-dev-server-error.log'

  $apiProcess = Start-Process `
    -FilePath $php.Source `
    -ArgumentList @('artisan', 'serve', '--host=127.0.0.1', "--port=$apiPort") `
    -WorkingDirectory $apiPath `
    -RedirectStandardOutput $stdoutLog `
    -RedirectStandardError $stderrLog `
    -WindowStyle Hidden `
    -PassThru

  Write-Host "Starting TrackIt API on http://127.0.0.1:$apiPort ..."
  $startupDeadline = (Get-Date).AddSeconds(30)
  while (-not (Test-LocalPort -Port $apiPort)) {
    if ($apiProcess.HasExited) {
      $details = if (Test-Path $stderrLog) { Get-Content $stderrLog -Tail 20 | Out-String } else { '' }
      throw "The API server stopped during startup. Check $stderrLog`n$details"
    }
    if ((Get-Date) -ge $startupDeadline) {
      throw "The API did not start within 30 seconds. Check $stderrLog."
    }
    Start-Sleep -Milliseconds 300
  }

  Write-Host 'API is ready. Starting the web app in Chrome. Press Ctrl+C to stop both.'
  Push-Location $mobilePath
  try {
    & flutter run -d chrome
    $flutterExitCode = $LASTEXITCODE
  } finally {
    Pop-Location
  }
  if ($flutterExitCode -ne 0) { throw "flutter run exited with code $flutterExitCode." }
} finally {
  if ($apiProcess -and -not $apiProcess.HasExited) {
    & taskkill.exe /PID $apiProcess.Id /T /F | Out-Null
    Write-Host 'Stopped the local API server.'
  }
}
