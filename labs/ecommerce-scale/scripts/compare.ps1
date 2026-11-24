param(
    [switch]$AddIndexes
)

$ErrorActionPreference = 'Stop'
$labRoot = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
$resultsDir = Join-Path $labRoot 'results'
New-Item -ItemType Directory -Path $resultsDir -Force | Out-Null

function Measure([string]$File, [string]$Destination) {
    Write-Host ("==> $File") -ForegroundColor Cyan
    docker compose exec -T db psql -U scale_lab -d ecommerce_scale -v ON_ERROR_STOP=1 -f "/lab/sql/$File" |
        Tee-Object -FilePath (Join-Path $resultsDir $Destination)
    if ($LASTEXITCODE -ne 0) { throw "Falha ao executar $File" }
}

Push-Location $labRoot
try {
    Measure '03_baseline_queries.sql' 'baseline.txt'
    if ($AddIndexes) {
        Write-Host 'Criando índices adicionais...' -ForegroundColor Cyan
        docker compose exec -T db psql -U scale_lab -d ecommerce_scale -v ON_ERROR_STOP=1 -f /lab/sql/04_add_indexes.sql
        if ($LASTEXITCODE -ne 0) { throw 'Falha na criação de índices' }
        Measure '03_baseline_queries.sql' 'after-indexes.txt'
    }
    Write-Host "Relatórios em $resultsDir" -ForegroundColor Green
}
finally {
    Pop-Location
}
