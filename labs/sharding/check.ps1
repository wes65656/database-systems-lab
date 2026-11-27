param(
    [ValidateRange(100, 1000000)][int]$Keys = 100000,
    [ValidateRange(100, 20000)][int]$RealKeys = 2000,
    [switch]$Real
)
$ErrorActionPreference = 'Stop'
Push-Location $PSScriptRoot
try {
    dotnet run --project Sharding --configuration Release -- simulate $Keys
    if ($LASTEXITCODE -ne 0) { throw 'Simulation failed.' }
    if ($Real) {
        docker compose up -d --wait
        if ($LASTEXITCODE -ne 0) { throw 'Docker Compose failed.' }
        foreach ($mode in @('real-modulo', 'real-ring')) {
            dotnet run --project Sharding --configuration Release -- $mode $RealKeys
            if ($LASTEXITCODE -ne 0) { throw "Physical sharding failed: $mode" }
        }
    }
} finally {
    Pop-Location
}
