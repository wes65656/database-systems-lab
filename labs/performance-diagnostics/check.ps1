$ErrorActionPreference = 'Stop'
Push-Location $PSScriptRoot
try {
    $experiments = @(
        '00_setup.sql'
        '01_index.sql'
        '02_estimates.sql'
        '03_sort.sql'
        '04_workload.sql'
        '05_locks.sql'
    )
    foreach ($experiment in $experiments) {
        docker compose exec -T db psql -X -U lab -d performance_diagnostics -f "/lab/sql/$experiment"
        if ($LASTEXITCODE -ne 0) {
            throw "Falha em $experiment (código $LASTEXITCODE)."
        }
    }
} finally {
    Pop-Location
}
