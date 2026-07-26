[CmdletBinding()]
param(
    [Parameter(ValueFromRemainingArguments)]
    [string[]]$LabyArguments
)

$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest

$Executable = Join-Path $PSScriptRoot "dist\windows\laby.exe"
$WorkingDirectory = Split-Path -Parent $Executable

if (-not (Test-Path -LiteralPath $Executable -PathType Leaf)) {
    throw "No Windows build found. Run .\build-windows.ps1 first."
}

Push-Location $WorkingDirectory
try {
    & opam exec -- $Executable @LabyArguments
    if ($LASTEXITCODE -ne 0) {
        throw "laby.exe exited with code $LASTEXITCODE"
    }
}
finally {
    Pop-Location
}
