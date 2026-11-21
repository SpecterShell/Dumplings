# Actual Installer internals

This reference describes the compiled Actual Installer setup formats and runtime behavior consumed by Dumplings. Use the [Actual Installer workflow](../../families/actual-installer/workflow.md) for package analysis and WinGet manifest authoring.

Read [binary notation](../../parser-development/binary-notation.md), [parser contracts](../../parser-development/contracts.md), and [performance guidance](../../parser-development/performance.md) before changing the parser.

## Mental model

An Actual Installer setup is a native PE bootstrapper followed by independently bounded Microsoft Cabinet or ZIP archives. One archive contains `setup.ini` or `aisetup.ini`, language resources, and helper templates. Other archives carry application files. Setup EXE + Data media instead keeps its source-directory tree in a companion 7z/LZMA archive. The INI is the logical catalog: numeric `[Files]` keys identify embedded payload entries and their values describe intended destinations. Physical archive order and logical file identity are separate concerns.

```text
distributed setup
+-- native PE runtime
+-- optional alignment or runtime-owned overlay bytes
+-- one or more payload containers
+-- one metadata container
|   +-- setup.ini or aisetup.ini
|   +-- language and UI resources
|   `-- uninstaller/updater helper material
`-- optional signed or trailing envelope

compiled configuration
+-- package identity and version expressions
+-- scope, elevation, architecture, and destination policy
+-- logical file table
+-- built-in uninstall and Apps & Features policy
+-- registry and association records
+-- shortcuts and commands
`-- requirements, custom variables, media sources, and runtime options
```

The parser must keep three layers distinct. Container records establish physical bytes. Compiled INI records describe intended operations. Runtime state supplies dynamic variables, downloaded data, selected scope, elevation identity, conditions, generated files, and child-process effects. Static analysis must not manufacture the third layer from the analysis host.

## Evidence vocabulary

Statements in these pages use specific evidence classes.

| Evidence | Establishes | Does not establish |
| --- | --- | --- |
| Structural invariant | Format dispatch, range validation, payload mapping, and extraction | Runtime side effects not represented in the structure |
| Controlled builder comparison | Meaning of a changed project option or serialized field | Compatibility with an untested generation |
| Published builder help | Intended switches, variables, options, and exit-code meanings | The exact compiled representation in every historical release |
| Runtime inspection | Control flow and command-line handling for the inspected runtime | Installed state for an arbitrary project |
| VM installed-state comparison | Files, ARP values, registry view, scope, and exit behavior for that fixture | A generation-wide binary rule without corroborating media |

Structural route selection is authoritative. A builder version from the configuration is a compatibility check and must not override a validated container layout.

## Reading path

1. [Architecture](architecture.md) explains the producer, runtime layers, identity domains, and trust boundaries.
2. [Format history](format-history.md) records the verified generations and route changes.
3. [Binary format](binary-format.md) defines PE, CAB, ZIP, and logical payload framing.
4. [Metadata model](metadata-model.md) covers INI decoding, table records, variables, and current interpretation boundaries.
5. [Setup runtime](setup-runtime.md) describes phases, scope, elevation, switches, exit codes, and online or external data.
6. [Uninstaller and ARP](uninstaller-and-arp.md) describes Product GUIDs, visibility gates, hives, views, commands, and custom registry effects.
7. [Parser implementation](parser-implementation.md) records detection, parsing, extraction, diagnostics, bounds, and performance rules.
8. [Coverage](coverage.md) lists fixtures, validated behavior, and unresolved gaps.

## Current structural routes

| Route | Verified media | Container order | Metadata entry | Payload identity |
| --- | --- | --- | --- | --- |
| `Cabinet3` | 3.8 | metadata CAB first, then payload CABs | `setup.ini` | one payload CAB per ordered `[Files]` row |
| `Cabinet4` | 4.8 | metadata CAB first, then payload CABs | `aisetup.ini` | one payload CAB per ordered `[Files]` row |
| `Cabinet5` | 5.2 | payload CABs first, metadata CAB last | `aisetup.ini` | one payload CAB per ordered `[Files]` row |
| `Zip6Plus` | 6.6, 6.7, 8.0, 8.2, 8.3, 8.4, and 9.x configuration observed in current media | numbered payload ZIPs followed by metadata ZIP | `aisetup.ini` | decimal ZIP entry name equals `[Files]` key |
| `ZipExternalData` | source-backed synthetic route for documented Setup EXE + Data media | one metadata ZIP in the executable plus a caller-supplied companion archive | `aisetup.ini` | 7z paths preserve the source-directory tree below `<InstallDir>` |

Setup EXE + Data is also observed as a hybrid `Zip6Plus` file: controlled 9.6 output embeds numbered generated-uninstaller payloads and the metadata ZIP while moving application source files to the companion 7z. `FormatGeneration` describes the physical executable route; `MediaInfo.DataFileName` and `PackageType` describe the independent distribution mode. Supplying `CompanionFile` during information parsing adds that source tree to the installed payload catalog and permits bounded main-executable analysis.

Installed-state comparison shows that Cabinet5 and numbered-ZIP runtimes copy their selected generated-uninstaller helper unchanged for the verified 5.2, 8.0, and 8.4 media. This is represented as a route capability rather than inferred from the helper filename. Older generated helpers and updater helpers remain metadata evidence unless a physical payload record maps them directly.

`ActualInstallerFormatCatalog.psd1` stores these routes. Add a route only when bounded fixture evidence proves a physical difference.

## Source references

- [Actual Installer command-line parameters](https://www.actualinstaller.com/help/command-line.html)
- [Actual Installer variables](https://www.actualinstaller.com/help/installer-variables.html)
- [Actual Installer setup parameters](https://www.actualinstaller.com/help/setup-parameters.html)
- [Actual Installer commands](https://www.actualinstaller.com/help/commands.html)
- [Actual Installer 64-bit installations](https://www.actualinstaller.com/help/64-bit-installation.html)
- [Actual Installer files and folders](https://www.actualinstaller.com/help/files-and-folders.html)
- [Actual Installer registry behavior](https://www.actualinstaller.com/help/registry.html)
- [Actual Installer update installers and Product GUID behavior](https://www.actualinstaller.com/articles/how-to-create-update-installer.html)
- [Internet Archive captures of the download path](https://web.archive.org/web/*/http://www.actualinstaller.com/download/aisetup.exe)
- [Internet Archive captures of the older root path](https://web.archive.org/web/*/http://www.actualinstaller.com/aisetup.exe)
