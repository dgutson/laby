[CmdletBinding()]
param(
    [string]$LablgtkVersion = "3.1.5"
)

$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest

$ProjectRoot = $PSScriptRoot
$SourceRoot = Join-Path $ProjectRoot ".opam-src"
$SourceDir = Join-Path $SourceRoot "lablgtk3-$LablgtkVersion"
$PixbufSource = Join-Path $SourceDir "src\ml_gdkpixbuf.c"
$OpamFile = Join-Path $SourceDir "lablgtk3.opam"

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

if (Test-Path -LiteralPath $SourceDir) {
    Remove-Item -LiteralPath $SourceDir -Recurse -Force
}
New-Item -ItemType Directory -Path $SourceRoot -Force | Out-Null

Invoke-Checked -Command "opam" -Arguments @(
    "source",
    "lablgtk3.$LablgtkVersion",
    "--dir=$SourceDir"
)

if (-not (Test-Path -LiteralPath $PixbufSource -PathType Leaf) -or
    -not (Test-Path -LiteralPath $OpamFile -PathType Leaf)) {
    throw "The downloaded lablgtk3 source is incomplete"
}

$Source = [IO.File]::ReadAllText($PixbufSource)
$OldSerialize = "static void ml_GdkPixbuf_serialize (value v, unsigned long *wsize_32, unsigned long *wsize_64)"
$NewSerialize = "static void ml_GdkPixbuf_serialize (value v, uintnat *wsize_32, uintnat *wsize_64)"
$OldDeserialize = "static unsigned long ml_GdkPixbuf_deserialize (void *dst)"
$NewDeserialize = "static uintnat ml_GdkPixbuf_deserialize (void *dst)"

if (-not $Source.Contains($OldSerialize) -or
    -not $Source.Contains($OldDeserialize)) {
    throw "The expected lablgtk3 Win64 signatures were not found"
}

$Patched = $Source.Replace($OldSerialize, $NewSerialize).Replace(
    $OldDeserialize,
    $NewDeserialize
)

[IO.File]::WriteAllText(
    $PixbufSource,
    $Patched,
    [Text.UTF8Encoding]::new($false)
)

$OpamSource = [IO.File]::ReadAllText($OpamFile)
$OpamPatched = [Text.RegularExpressions.Regex]::Replace(
    $OpamSource,
    '(?m)^\s*"(?:ocamlfind|camlp5)"\s*\{\s*dev\s*\}\s*\r?\n',
    ""
)
if ($OpamPatched -eq $OpamSource) {
    throw "The expected lablgtk3 development-only dependencies were not found"
}
[IO.File]::WriteAllText(
    $OpamFile,
    $OpamPatched,
    [Text.UTF8Encoding]::new($false)
)

Invoke-Checked -Command "opam" -Arguments @(
    "pin",
    "add",
    "lablgtk3.$LablgtkVersion",
    $SourceDir,
    "--no-action",
    "--yes"
)

Write-Host "Pinned lablgtk3 $LablgtkVersion with its Win64 build fixes."
