# CreateInstall architecture

## Product boundary

CreateInstall is a native Windows setup runtime generated from a CreateInstall project and linked Gentee modules. Distributed media does not contain the original authoring project as a document. The compiler writes project values and generated operation calls into a serialized GE 4 program, links the Gentee runtime into a PE section, and optionally appends a GEA archive containing packaged files.

The earlier products distributed as `ci2000.exe`, `setupgen.exe`, and `sgpro.exe` use a different Gentee Installer runtime. They have no supported CreateInstall GE4-plus-MAINVAR structure and are not early CreateInstall routes.

## Layer model

```text
CreateInstall setup executable
+-- PE image
|   +-- native setup loader and runtime
|   +-- version resources and application manifest
|   `-- .gentee section
|       +-- Gentee runtime image
|       `-- compiled GE 4 project program
+-- optional GEA archive
|   +-- volume header and catalog
|   +-- file descriptors and inherited descriptor state
|   `-- stored, LZGE, or Gentee PPMd-I block streams
`-- optional companion GEA volumes
    `-- continuation bodies selected by the main volume pattern
```

Physical adjacency and execution ownership are separate. The native launcher owns process startup and UI. The compiled GE program owns setup decisions, registry operations, file selection, child execution, and generated-uninstaller behavior. The GEA archive supplies bytes but does not decide which files are installed. A nested MSI or EXE remains a child payload whose metadata and switches must be analyzed separately.

## Compile-time and runtime state

`MAINVAR` contains generated project variables such as product identity, installation path, uninstaller path, URLs, and the silent parameter. Other `g_list` tables hold records for files, registry values, shortcuts, downloads, tasks, INI changes, and related operations. Direct GE calls connect those tables to linked runtime routines.

Runtime state includes OS and architecture probes, existing files and registry values, prerequisite results, user choices, language-dependent strings, downloaded content, external DLL results, and values assigned by earlier operations. The parser resolves deterministic project values and retains runtime-dependent expressions as evidence. It never substitutes state from the analysis host.

## Setup and uninstaller relationship

CreateInstall's generated uninstaller reuses the same launcher and GE program architecture. A VM-generated uninstaller was accepted by the parser as a valid no-GEA CreateInstall artifact. Its project program replays removal operations and reads the installation log; it does not need a packaged application archive.

This relationship explains why archive presence cannot be a detection requirement. A setup can also omit packaged files while performing downloads, registry changes, generated-file work, or child execution entirely from the compiled program.

## Ownership rules

Use the compiled program as the authority for switches, operation routing, and deterministic registry effects. Use GEA only for physical file bytes and archive metadata. Use PE resources only as fallback identity or elevation evidence. Use VM evidence when an `@function`, external call, previous-machine state, or user choice decides behavior.

Do not derive application architecture from the native setup stub. CreateInstall builder media commonly uses an x86 launcher while installing x86, x64, or mixed payloads. The parser selectively extracts source-selected application binaries and passes those files to PE architecture and dependency analysis.
