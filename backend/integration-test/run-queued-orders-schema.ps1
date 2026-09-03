param([int]$Port = 55433)

$ErrorActionPreference = 'Stop'
$PSNativeCommandUseErrorActionPreference = $true
$container = 'tulpar-queued-order-schema-postgres'
$database = 'tulpar_queued_order_test'
$databaseUser = 'tulpar_test_runner'
$databasePassword = 'fixture-only-password'

if ($database -eq 'tulpar' -or -not $database.EndsWith('_test')) {
  throw "Unsafe integration database name: $database"
}
$dockerCommand = Get-Command docker -ErrorAction SilentlyContinue
if (-not $dockerCommand) {
  $bundledDocker = Join-Path $env:LOCALAPPDATA 'Programs\DockerDesktop\resources\bin\docker.exe'
  if (Test-Path -LiteralPath $bundledDocker) { $dockerCommand = Get-Item $bundledDocker }
}
if (-not $dockerCommand) { throw 'Docker is required.' }

$dockerContext = (& $dockerCommand context show).Trim()
$dockerEndpoint = (& $dockerCommand context inspect $dockerContext --format '{{.Endpoints.docker.Host}}').Trim()
if (-not ($dockerEndpoint.StartsWith('npipe://') -or $dockerEndpoint.StartsWith('unix://')) -or $dockerEndpoint.Contains('212.19.134.57')) {
  throw "Refusing non-local Docker endpoint: $dockerEndpoint"
}
$dockerServerVersion = (& $dockerCommand version --format '{{.Server.Version}}').Trim()
if (-not $dockerServerVersion) { throw 'Local Docker Engine is not running.' }
if (& $dockerCommand ps -a --format '{{.Names}}' | Select-String -SimpleMatch $container) {
  throw "Refusing to reuse existing container $container"
}

$env:ALLOW_DESTRUCTIVE_TEST_DB = '1'
$env:DB_HOST = '127.0.0.1'
$env:DB_PORT = [string]$Port
$env:POSTGRES_DB = $database
$env:POSTGRES_USER = $databaseUser
$env:POSTGRES_PASSWORD = $databasePassword
Remove-Item Env:DATABASE_URL -ErrorAction SilentlyContinue

try {
  & $dockerCommand run --rm --detach --name $container `
    --env "POSTGRES_DB=$database" `
    --env "POSTGRES_USER=$databaseUser" `
    --env "POSTGRES_PASSWORD=$databasePassword" `
    --publish "127.0.0.1:${Port}:5432" postgres:17 | Out-Null

  $ready = $false
  for ($attempt = 0; $attempt -lt 30; $attempt++) {
    & $dockerCommand exec $container pg_isready -U $databaseUser -d $database | Out-Null
    if ($LASTEXITCODE -eq 0) { $ready = $true; break }
    Start-Sleep -Seconds 1
  }
  if (-not $ready) { throw 'Temporary PostgreSQL did not become ready.' }
  if ((& $dockerCommand inspect $container --format '{{.Config.Image}}').Trim() -ne 'postgres:17') {
    throw 'Unexpected PostgreSQL image.'
  }
  if ((& $dockerCommand port $container '5432/tcp').Trim() -ne "127.0.0.1:$Port") {
    throw 'Unsafe PostgreSQL port binding.'
  }

  Push-Location (Join-Path $PSScriptRoot '..')
  try {
    node --test --test-concurrency=1 --test-isolation=none integration-test/queued-orders-schema.postgres.test.js
    if ($LASTEXITCODE -ne 0) { throw 'Queued-order schema tests failed.' }
  } finally { Pop-Location }
} finally {
  if (& $dockerCommand ps -a --format '{{.Names}}' | Select-String -SimpleMatch $container) {
    & $dockerCommand rm --force $container | Out-Null
  }
}
