param(
  [int]$Port = 55432
)

$ErrorActionPreference = 'Stop'
$PSNativeCommandUseErrorActionPreference = $true
$container = 'tulpar-intercity-integration-postgres'
$database = 'tulpar_intercity_test'
$databaseUser = 'tulpar_test_runner'
$databasePassword = 'fixture-only-password'

if ($database -eq 'tulpar' -or -not $database.EndsWith('_test')) {
  throw "Unsafe integration database name: $database"
}
$dockerCommand = Get-Command docker -ErrorAction SilentlyContinue
if (-not $dockerCommand) {
  $bundledDocker = Join-Path $env:LOCALAPPDATA 'Programs\DockerDesktop\resources\bin\docker.exe'
  if (Test-Path -LiteralPath $bundledDocker) {
    $dockerCommand = Get-Item -LiteralPath $bundledDocker
  }
}
if (-not $dockerCommand) {
  throw 'Docker is required to create the isolated PostgreSQL 17 test database.'
}
$dockerContext = (& $dockerCommand context show).Trim()
$dockerEndpoint = (& $dockerCommand context inspect $dockerContext --format '{{.Endpoints.docker.Host}}').Trim()
if (
  -not ($dockerEndpoint.StartsWith('npipe://') -or $dockerEndpoint.StartsWith('unix://')) -or
  $dockerEndpoint.Contains('212.19.134.57')
) {
  throw "Refusing non-local Docker endpoint: $dockerEndpoint"
}
$dockerServerVersion = (& $dockerCommand version --format '{{.Server.Version}}').Trim()
if (-not $dockerServerVersion) {
  throw 'Local Docker Engine is not running.'
}
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

Write-Output "SAFETY_DOCKER_CONTEXT=$dockerContext"
Write-Output "SAFETY_DOCKER_ENDPOINT=$dockerEndpoint"
Write-Output "SAFETY_DOCKER_SERVER_VERSION=$dockerServerVersion"
Write-Output 'SAFETY_DOCKER_ENDPOINT_LOCAL=true'
Write-Output 'SAFETY_DB_HOST=127.0.0.1'
Write-Output "SAFETY_DB_NAME=$database"
Write-Output "SAFETY_DB_NAME_ENDS_WITH_TEST=$($database.EndsWith('_test'))"
Write-Output "SAFETY_DB_IS_NOT_PRODUCTION=$($database -ne 'tulpar')"
Write-Output 'SAFETY_PRODUCTION_HOST_USED=false'

try {
  & $dockerCommand run --rm --detach `
    --name $container `
    --env "POSTGRES_DB=$database" `
    --env "POSTGRES_USER=$databaseUser" `
    --env "POSTGRES_PASSWORD=$databasePassword" `
    --publish "127.0.0.1:${Port}:5432" `
    postgres:17 | Out-Null

  $ready = $false
  for ($attempt = 0; $attempt -lt 30; $attempt += 1) {
    & $dockerCommand exec $container pg_isready -U $databaseUser -d $database | Out-Null
    if ($LASTEXITCODE -eq 0) {
      $ready = $true
      break
    }
    Start-Sleep -Seconds 1
  }
  if (-not $ready) {
    throw 'Temporary PostgreSQL did not become ready.'
  }

  $containerImage = (& $dockerCommand inspect $container --format '{{.Config.Image}}').Trim()
  if ($containerImage -ne 'postgres:17') {
    throw "Unexpected PostgreSQL test image: $containerImage"
  }
  $portBinding = (& $dockerCommand port $container '5432/tcp').Trim()
  if ($portBinding -ne "127.0.0.1:$Port") {
    throw "Unsafe PostgreSQL port binding: $portBinding"
  }
  $databaseIdentity = (& $dockerCommand exec $container `
    psql -X -U $databaseUser -d $database -Atc 'SELECT current_database()').Trim()
  if ($databaseIdentity -ne $database) {
    throw "Unexpected PostgreSQL database: $databaseIdentity"
  }
  $postgresVersion = (& $dockerCommand exec $container `
    psql -X -U $databaseUser -d $database -Atc 'SHOW server_version').Trim()

  Write-Output "SAFETY_POSTGRES_CONTAINER=$container"
  Write-Output "SAFETY_POSTGRES_IMAGE=$containerImage"
  Write-Output "SAFETY_POSTGRES_VERSION=$postgresVersion"
  Write-Output "SAFETY_POSTGRES_PORT_BINDING=$portBinding"
  Write-Output "SAFETY_POSTGRES_DATABASE_CONFIRMED=$databaseIdentity"

  Push-Location (Join-Path $PSScriptRoot '..')
  try {
    node integration-test/prepare-intercity-test-db.js
    if ($LASTEXITCODE -ne 0) { throw 'Test database preparation failed.' }
    node --test --test-concurrency=1 --test-isolation=none integration-test/intercity-rides.postgres.test.js
    if ($LASTEXITCODE -ne 0) { throw 'PostgreSQL integration tests failed.' }
    node --test --test-concurrency=1 --test-isolation=none integration-test/intercity-rides.e2e.test.js
    if ($LASTEXITCODE -ne 0) { throw 'PostgreSQL sequential E2E tests failed.' }
    node --test --test-concurrency=1 --test-isolation=none integration-test/account-deletion.postgres.test.js
    if ($LASTEXITCODE -ne 0) { throw 'PostgreSQL account deletion tests failed.' }
    node --test --test-concurrency=1 --test-isolation=none integration-test/account-deletion-concurrency.postgres.test.js
    if ($LASTEXITCODE -ne 0) { throw 'PostgreSQL account deletion concurrency tests failed.' }
  } finally {
    Pop-Location
  }
} finally {
  if (& $dockerCommand ps -a --format '{{.Names}}' | Select-String -SimpleMatch $container) {
    & $dockerCommand rm --force $container | Out-Null
  }
}
