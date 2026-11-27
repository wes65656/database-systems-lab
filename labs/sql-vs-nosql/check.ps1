param(
    [ValidateRange(100, 1000000)][int]$Rows = 15000,
    [ValidateRange(100, 1000000)][int]$Operations = 3000,
    [ValidateRange(1, 5000)][int]$Batch = 500
)
$ErrorActionPreference = 'Stop'
Push-Location $PSScriptRoot
try {
    docker compose up -d --wait
    if ($LASTEXITCODE -ne 0) { throw 'Docker Compose failed.' }
    dotnet run --project Benchmark --configuration Release -- $Rows $Operations $Batch
    if ($LASTEXITCODE -ne 0) { throw 'Benchmark or integrity check failed.' }
} finally {
    Pop-Location
}
