[CmdletBinding()]
param(
    [switch]$Clean,
    [switch]$SkipDependencies
)

$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest

$ProjectRoot = $PSScriptRoot
$DistDir = Join-Path $ProjectRoot "dist\windows"
$BuiltExecutable = Join-Path $ProjectRoot "_build\default\src\laby.exe"

function Invoke-Checked {
    param(
        [Parameter(Mandatory)]
        [string]$Command,

        [Parameter(Mandatory)]
        [string[]]$Arguments
    )

    & $Command @Arguments
    if ($LASTEXITCODE -ne 0) {
        throw "$Command exited with code $LASTEXITCODE"
    }
}

if (-not (Get-Command opam -ErrorAction SilentlyContinue)) {
    throw "opam was not found. Install it with: winget install OCaml.opam"
}

Push-Location $ProjectRoot
try {
    if ($Clean) {
        Invoke-Checked -Command "opam" -Arguments @("exec", "--", "dune", "clean")
    }

    if (-not $SkipDependencies) {
        & (Join-Path $ProjectRoot "prepare-windows-deps.ps1")
        if ($LASTEXITCODE -ne 0) {
            throw "prepare-windows-deps.ps1 exited with code $LASTEXITCODE"
        }

        Invoke-Checked -Command "opam" -Arguments @(
            "install", ".", "--deps-only", "--yes"
        )
    }

    Invoke-Checked -Command "opam" -Arguments @(
        "exec", "--", "dune", "build", "src/laby.exe"
    )

    if (-not (Test-Path -LiteralPath $BuiltExecutable -PathType Leaf)) {
        throw "Dune completed but did not produce $BuiltExecutable"
    }

    if (Test-Path -LiteralPath $DistDir) {
        Remove-Item -LiteralPath $DistDir -Recurse -Force
    }

    New-Item -ItemType Directory -Path $DistDir | Out-Null
    Copy-Item -LiteralPath $BuiltExecutable `
        -Destination (Join-Path $DistDir "laby.exe")
    Copy-Item -LiteralPath (Join-Path $ProjectRoot "data") `
        -Destination (Join-Path $DistDir "data") -Recurse

    Write-Host "Native Windows build created at:"
    Write-Host "  $(Join-Path $DistDir 'laby.exe')"
    Write-Host "Run it with .\run-windows.ps1 so opam-provided GTK DLLs are on PATH."
}
finally {
    Pop-Location
}
