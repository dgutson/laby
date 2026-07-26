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

function Get-ExistingDirectory {
    param([string]$Path)

    if ($Path -and (Test-Path -LiteralPath $Path -PathType Container)) {
        return (Resolve-Path -LiteralPath $Path).Path
    }
}

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

function Copy-RuntimeDependencyClosure {
    param(
        [Parameter(Mandatory)]
        [string[]]$InitialFiles
    )

    $ObjdumpCommand = Get-Command "objdump.exe" -ErrorAction SilentlyContinue
    $ObjdumpPath = if ($ObjdumpCommand) {
        $ObjdumpCommand.Source
    }
    else {
        $null
    }
    if (-not $ObjdumpPath) {
        $Fallback = "C:\msys64\mingw64\bin\objdump.exe"
        if (Test-Path -LiteralPath $Fallback -PathType Leaf) {
            $ObjdumpPath = $Fallback
        }
    }
    if (-not $ObjdumpPath) {
        throw "objdump.exe was not found; cannot collect runtime DLLs"
    }

    $SearchDirs = [Collections.Generic.List[string]]::new()
    foreach ($Entry in ($env:PATH -split [IO.Path]::PathSeparator)) {
        $Existing = Get-ExistingDirectory $Entry
        if ($Existing -and -not $SearchDirs.Contains($Existing)) {
            $SearchDirs.Add($Existing)
        }
    }
    foreach ($Known in @(
        "C:\msys64\mingw64\bin",
        (& opam var bin 2>$null),
        (& opam var stublibs 2>$null)
    )) {
        $Existing = Get-ExistingDirectory $Known
        if ($Existing -and -not $SearchDirs.Contains($Existing)) {
            $SearchDirs.Add($Existing)
        }
    }

    $Queue = [Collections.Generic.Queue[string]]::new()
    foreach ($File in $InitialFiles) {
        $Queue.Enqueue((Resolve-Path -LiteralPath $File).Path)
    }
    $ProcessedFiles = [Collections.Generic.HashSet[string]]::new(
        [StringComparer]::OrdinalIgnoreCase
    )
    $ResolvedDlls = [Collections.Generic.HashSet[string]]::new(
        [StringComparer]::OrdinalIgnoreCase
    )

    while ($Queue.Count -gt 0) {
        $File = $Queue.Dequeue()
        if (-not $ProcessedFiles.Add($File)) {
            continue
        }

        $Headers = & $ObjdumpPath -p $File 2>&1
        if ($LASTEXITCODE -ne 0) {
            throw "objdump failed while inspecting $File"
        }

        foreach ($Line in $Headers) {
            if ($Line -notmatch "^\s*DLL Name:\s*(?<Name>.+?)\s*$") {
                continue
            }
            $Name = $Matches.Name
            if (-not $ResolvedDlls.Add($Name)) {
                continue
            }

            $Destination = Join-Path $DistDir $Name
            if (Test-Path -LiteralPath $Destination -PathType Leaf) {
                $Queue.Enqueue((Resolve-Path -LiteralPath $Destination).Path)
                continue
            }

            $Source = $null
            foreach ($Directory in $SearchDirs) {
                $Candidate = Join-Path $Directory $Name
                if (Test-Path -LiteralPath $Candidate -PathType Leaf) {
                    $Source = $Candidate
                    break
                }
            }

            if ($Source) {
                Copy-Item -LiteralPath $Source -Destination $Destination
                $Queue.Enqueue((Resolve-Path -LiteralPath $Destination).Path)
            }
            else {
                Write-Verbose "Using Windows system DLL: $Name"
            }
        }
    }

    Write-Host "Bundled $($ResolvedDlls.Count) recursive DLL dependencies."
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

    $MingwRoot = "C:\msys64\mingw64"
    $QueryLoaders = Join-Path $MingwRoot "bin\gdk-pixbuf-query-loaders.exe"
    if (-not (Test-Path -LiteralPath $QueryLoaders -PathType Leaf)) {
        throw "Missing $QueryLoaders"
    }
    Copy-Item -LiteralPath $QueryLoaders -Destination $DistDir

    $PkgConfigPath = $null
    foreach ($Candidate in @(
        "C:\msys64\mingw64\bin\pkg-config.exe",
        "C:\msys64\mingw64\bin\pkgconf.exe",
        "C:\msys64\usr\bin\pkg-config.exe",
        "C:\msys64\usr\bin\pkgconf.exe"
    )) {
        if (Test-Path -LiteralPath $Candidate -PathType Leaf) {
            $PkgConfigPath = $Candidate
            break
        }
    }
    if (-not $PkgConfigPath) {
        foreach ($Name in @("pkg-config.exe", "pkgconf.exe")) {
            $Command = Get-Command $Name -ErrorAction SilentlyContinue
            if ($Command) {
                $PkgConfigPath = $Command.Source
                break
            }
        }
    }
    if (-not $PkgConfigPath) {
        throw "pkg-config.exe was not found"
    }
    $LoaderSource = (& $PkgConfigPath `
        --variable=gdk_pixbuf_moduledir gdk-pixbuf-2.0).Trim()
    if ($LASTEXITCODE -ne 0 -or
        -not (Test-Path -LiteralPath $LoaderSource -PathType Container)) {
        throw "Could not locate the GDK Pixbuf loader directory"
    }
    $LoaderDestination = Join-Path $DistDir "lib\gdk-pixbuf-2.0\loaders"
    New-Item -ItemType Directory -Path $LoaderDestination -Force | Out-Null
    Copy-Item -Path (Join-Path $LoaderSource "*.dll") `
        -Destination $LoaderDestination

    $RuntimeFiles = @(
        (Join-Path $DistDir "laby.exe"),
        (Join-Path $DistDir "gdk-pixbuf-query-loaders.exe")
    )
    $RuntimeFiles += Get-ChildItem -LiteralPath $LoaderDestination `
        -Filter "*.dll" -File | Select-Object -ExpandProperty FullName
    Copy-RuntimeDependencyClosure -InitialFiles $RuntimeFiles

    foreach ($RelativePath in @(
        "share\glib-2.0\schemas",
        "share\gtksourceview-3.0",
        "share\icons\Adwaita",
        "share\icons\hicolor",
        "share\themes",
        "share\licenses",
        "etc\fonts",
        "etc\gtk-3.0"
    )) {
        $Source = Join-Path $MingwRoot $RelativePath
        if (Test-Path -LiteralPath $Source -PathType Container) {
            $Destination = Join-Path $DistDir $RelativePath
            New-Item -ItemType Directory `
                -Path (Split-Path -Parent $Destination) -Force | Out-Null
            Copy-Item -LiteralPath $Source -Destination $Destination -Recurse
        }
    }
    Copy-Item -LiteralPath (Join-Path $ProjectRoot "gpl-3.0.txt") `
        -Destination $DistDir

    Write-Host "Native Windows build created at:"
    Write-Host "  $(Join-Path $DistDir 'laby.exe')"
    Write-Host "The dist directory includes the GTK/Cairo runtime."
}
finally {
    Pop-Location
}
