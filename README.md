# Laby

Laby teaches programming by asking the player to guide an ant through
labyrinths while avoiding spider webs and moving rocks.

This fork adds a supported native Windows build alongside the existing
Unix build.

## Native Windows build

Requirements:

- 64-bit Windows 10 or Windows 11
- Git
- opam 2.2 or newer

Install the tools from PowerShell:

```powershell
winget install Git.Git OCaml.opam
opam init
```

When `opam init` asks for a Unix environment, use its managed environment
or an existing MSYS2 installation. Open a new PowerShell window, clone the
repository, and run:

```powershell
opam switch create . 4.14.2
.\build-windows.ps1
.\run-windows.ps1
```

The build installs the OCaml dependencies into the active opam switch,
compiles a native `laby.exe`, and places the executable and runtime data
under `dist\windows`. It recursively bundles the required GTK, Cairo,
Pango, GLib, GtkSourceView, and SVG-loader DLLs and data, so that entire
directory can run on a Windows machine without opam or MSYS2 installed.

`lablgtk3` 3.1.5 has two GdkPixbuf serializer signatures that use the
wrong integer width on 64-bit Windows, and its property generator
misinterprets Dune's Windows input paths. `prepare-windows-deps.ps1`
downloads that release, applies these compatibility fixes, and pins the
corrected `lablgtk3` and `lablgtk3-sourceview3` sources in the active
switch before the dependency build.
The pin excludes upstream's development-only parser generators because
release archives already contain their generated files.
The workaround can be removed after the fix is released upstream.

The launcher remains useful while developing, but the packaged
`dist\windows\laby.exe` can be started directly.

Programming-language modes are enabled when their compiler or interpreter
is present on `PATH`. For example, install Python, GCC, Java, or OCaml to
make the corresponding mode available.

## Linux and other Unix-like systems

The original Makefile build remains available. See [INSTALL](INSTALL).
