param([string]$Server = 'localhost')
$ErrorActionPreference = 'Stop'
# Windows integrated authentication. No passwords or database deletion.
# Requires a SQL Server instance and sqlcmd already installed.
$SqlCmd = Get-Command sqlcmd -ErrorAction Stop
$Evidence = Join-Path $PSScriptRoot 'evidence/local'
New-Item -ItemType Directory -Path $Evidence -Force | Out-Null
foreach ($Step in @('00_create_database','01_schema','02_seed','03_reports','04_tests')) {
    $File = Join-Path $PSScriptRoot "sql/$Step.sql"
    & $SqlCmd.Source -S $Server -E -b -r1 -W -s '|' -i $File 2>&1 |
        Tee-Object -FilePath (Join-Path $Evidence "$Step.txt")
    if ($LASTEXITCODE -ne 0) { throw "Stopped at $Step; inspect the output. Existing databases are never replaced." }
}
Write-Host 'Build, reports and SQL Server tests completed successfully.'
