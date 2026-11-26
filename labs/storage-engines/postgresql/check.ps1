$ErrorActionPreference = 'Stop'
Push-Location $PSScriptRoot
try {
    foreach ($file in '01_btree.sql', '02_vacuum.sql', '03_wal.sql', '04_mvcc_check.sql') {
        docker compose exec -T db psql -X -U lab -d storage_engines -f "/lab/sql/$file"
        if ($LASTEXITCODE -ne 0) {
            throw "Falha em $file (código $LASTEXITCODE)."
        }
    }
} finally {
    Pop-Location
}
