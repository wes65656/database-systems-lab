$ErrorActionPreference = 'Stop'
$labRoot = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
$resultsDir = Join-Path $labRoot 'results'
New-Item -ItemType Directory -Path $resultsDir -Force | Out-Null

Push-Location $labRoot
try {
    Write-Warning 'A cópia particionada pode DUPLICAR o espaço dos pedidos. Na carga completa, verifique o disco primeiro.'
    docker compose exec -T db psql -U scale_lab -d ecommerce_scale -v ON_ERROR_STOP=1 -f /lab/sql/05_partitioned_copy.sql
    if ($LASTEXITCODE -ne 0) { throw 'Falha ao criar a cópia particionada' }

    docker compose exec -T db psql -U scale_lab -d ecommerce_scale -v ON_ERROR_STOP=1 -f /lab/sql/06_partition_comparison.sql |
        Tee-Object -FilePath (Join-Path $resultsDir 'partition-comparison.txt')
    if ($LASTEXITCODE -ne 0) { throw 'Falha na comparação' }

    Write-Host "Relatório: $resultsDir/partition-comparison.txt" -ForegroundColor Green
}
finally {
    Pop-Location
}
