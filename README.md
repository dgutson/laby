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
under `dist\windows`.

`lablgtk3` 3.1.5 has two GdkPixbuf serializer signatures that use the
wrong integer width on 64-bit Windows, and its property generator
misinterprets Dune's Windows input paths. `prepare-windows-deps.ps1`
downloads that release, applies these compatibility fixes, and pins the
corrected source in the active switch before the dependency build.
The pin excludes upstream's development-only parser generators because
release archives already contain their generated files.
The workaround can be removed after the fix is released upstream.

The launcher uses `opam exec` because GTK and GtkSourceView DLLs are
provided by the opam-managed MinGW environment. A future packaging step
can collect those DLLs into a standalone ZIP or installer.

Programming-language modes are enabled when their compiler or interpreter
is present on `PATH`. For example, install Python, GCC, Java, or OCaml to
make the corresponding mode available.

## Linux and other Unix-like systems

The original Makefile build remains available. See [INSTALL](INSTALL).
