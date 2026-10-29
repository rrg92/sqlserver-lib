<#
.SYNOPSIS
    Gera o arquivo app/scripts.json com a lista de todos os scripts SQL do repositório.

.DESCRIPTION
    Percorre recursivamente o repositório, coleta todos os arquivos .sql
    e gera um JSON estruturado utilizado pela app de listagem (app/index.html).

.EXAMPLE
    # Rodar a partir da raiz do repositório:
    .\.aux\generate-scripts-json.ps1
#>

param(
    [string]$RootDir   = (Split-Path $PSScriptRoot -Parent),
    [string]$OutputFile = (Join-Path (Split-Path $PSScriptRoot -Parent) 'app\scripts.json')
)

$ErrorActionPreference = "Stop"

$sqlFiles = Get-ChildItem -Path $RootDir -Recurse -Filter '*.sql' |
    Where-Object { $_.FullName -notmatch '[\\/]\.git[\\/]' }

$scripts = $sqlFiles | ForEach-Object {
    $relativePath = [System.IO.Path]::GetRelativePath($RootDir, $_.FullName).Replace('\','/')
    $parts        = $relativePath -split '/'
    $category     = if ($parts.Count -gt 1) { $parts[0] } else { 'Root' }
    $subcategory  = if ($parts.Count -gt 2) { ($parts[1..($parts.Count - 2)]) -join '/' } else { '' }

    [pscustomobject]@{
        path        = $relativePath
        name        = $_.Name
        category    = $category
        subcategory = $subcategory
    }
} | Sort-Object category, path

$outputDir = Split-Path $OutputFile -Parent
if (-not (Test-Path $outputDir)) {
    New-Item -ItemType Directory -Path $outputDir | Out-Null
}

$scripts | ConvertTo-Json -Depth 3 | Set-Content -Path $OutputFile -Encoding UTF8

$total = @($scripts).Count
Write-Host "scripts.json gerado em: $OutputFile"
Write-Host "Total de scripts: $total"
