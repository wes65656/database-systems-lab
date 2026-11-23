# Executar da raiz do repositório, no PowerShell 7 (Windows).
$ErrorActionPreference = 'Stop'
$files = @(
    '00_schema.sql',
    '01_transactions.sql',
    '02_isolation.sql',
    '03_locking.sql',
    '04_indexes.sql',
    '05_partitioning.sql'
)

docker compose up -d --wait
if ($LASTEXITCODE -ne 0) { throw 'Falha ao iniciar Docker Compose.' }

foreach ($file in $files) {
    Write-Host "`n===== $file =====" -ForegroundColor Cyan
    docker compose exec -T db psql -U lab -d database_lab -v ON_ERROR_STOP=1 -f "/lab/sql/$file"
    if ($LASTEXITCODE -ne 0) { throw "Falha no script $file" }
}

Write-Host "`nExperimentos SQL executados sem erros." -ForegroundColor Green
