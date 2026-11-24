param(
    [ValidateSet('small', 'full')]
    [string]$Size = 'small'
)

$ErrorActionPreference = 'Stop'
$labRoot = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path

function Run-Sql([string]$File, [string[]]$Variables = @()) {
    Write-Host ("\n==> {0}" -f $File) -ForegroundColor Cyan
    $args = @('compose', 'exec', '-T', 'db', 'psql', '-U', 'scale_lab',
              '-d', 'ecommerce_scale', '-v', 'ON_ERROR_STOP=1')
    foreach ($variable in $Variables) { $args += @('-v', $variable) }
    $args += @('-f', "/lab/sql/$File")
    & docker @args
    if ($LASTEXITCODE -ne 0) { throw "Falha executando $File (exit $LASTEXITCODE)" }
}

Push-Location $labRoot
try {
    Write-Host "Iniciando banco ISOLADO ecommerce_scale (localhost:5434) ..." -ForegroundColor Cyan
    docker compose up -d --wait
    if ($LASTEXITCODE -ne 0) { throw "Docker Compose falhou (exit $LASTEXITCODE)" }

    Run-Sql '00_schema.sql'

    if ($Size -eq 'full') {
        Write-Warning 'Carga completa: 26.050.100 linhas. Pode demorar e consumir muitos GB de disco.'
        Run-Sql '01_seed.sql' @('customers=1000000', 'products=50000', 'orders=5000000')
    } else {
        Run-Sql '01_seed.sql'
    }

    Run-Sql '02_validate.sql'
    Write-Host "\nConcluído. Carga: $Size. O laboratório original não foi alterado." -ForegroundColor Green
}
finally {
    Pop-Location
}
