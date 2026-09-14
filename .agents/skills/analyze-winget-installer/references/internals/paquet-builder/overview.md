# Paquet Builder internals

This reference describes the Paquet Builder formats and runtime behavior consumed by Dumplings. Use the [Paquet Builder workflow](../../families/paquet-builder/workflow.md) for package analysis and WinGet manifest decisions.

Read [binary notation](../../parser-development/binary-notation.md), [parser contracts](../../parser-development/contracts.md), and [performance guidance](../../parser-development/performance.md) before changing the parser.

## Mental model

Paquet Builder has used five physically different package layouts. All are native PE launchers, but the package catalog moved from a compressed controller and GAF stream to an ISFX-described cabinet, then to a compressed named-resource program, and finally to independent 7z payload and runtime archives. File placement, registry changes, nested execution, and ARP identity belong to the catalog or compiled program; the outer PE version resource is only product identity evidence.

```text
distributed package
+-- native launcher PE
+-- generation-specific runtime or controller
+-- package metadata and operation program
+-- application payload
`-- optional nested MSI or generated uninstaller

static evidence
+-- physical ranges and checksums
+-- named resources, controller records, or PBCore assignments
+-- literal registry and execution operations
`-- nested package identity when the program proves ownership

runtime-only state
+-- selected scope and destination for conditional packages
+-- values read from the registry, dialogs, or external DLLs
+-- branches assembled by arbitrary native code
`-- final installed state when static evidence remains conditional
```

## Evidence vocabulary

| Evidence | Establishes | Does not establish |
| --- | --- | --- |
| Structural route | Paquet Builder detection, container boundaries, decoder choice, and extraction method | Package behavior not represented by that route |
| Catalog record | An authored file, shortcut, registry operation, or execution record | Whether a conditional action runs on a particular machine |
| Literal GINFOS or `SetVar` evidence | Deterministic variables, ARP keys, associations, and nested execution | Values read from dialogs, the host registry, or external code |
| Nested MSI selected by structure or script | MSI ProductCode, UpgradeCode, ARP identity, and MSI-owned metadata | Wrapper scope when the MSI itself leaves scope conditional |
| VM comparison | Actual ARP hive/view, files, exit code, and selected route for that fixture | A generation-wide rule without matching static evidence |

The structural route always controls parser dispatch. PE product versions and capture dates are compatibility evidence and never override a validated layout.

## Reading path

1. [Architecture](architecture.md) explains the launcher, runtime, payload, and ownership boundaries.
2. [Format history](format-history.md) records the five verified generations and their transitions.
3. [Binary format](binary-format.md) defines the classic envelope, controller and GAF records, ISFX descriptor, `@GDG`, `AP32`, `GP`, 7z, and runtime catalogs.
4. [Metadata model](metadata-model.md) covers GINFOS commands, literal variables, registry records, associations, and modern `PBCore.SetVar` evidence.
5. [Setup runtime](setup-runtime.md) describes execution phases, scope, elevation, switches, exit codes, and nested installers.
6. [Uninstaller and ARP](uninstaller-and-arp.md) describes ProductCode ownership, visible uninstall rows, nested MSI selection, and unresolved cases.
7. [Parser implementation](parser-implementation.md) records detection, bounded decoding, extraction, diagnostics, and performance rules.
8. [Coverage](coverage.md) lists the persistent fixtures, current results, and remaining gaps.

## Current structural routes

| Route | Verified builder range | Physical package | Metadata route | Extraction |
| --- | --- | --- | --- | --- |
| `ClassicResourcePackage` | 2.6.x | GPacker control block followed by ZIP containing `SETUP.EXE` and `SETUP1.GAF` | Packed controller records | Installed GAF files, controller, registry, shortcut, and execution records |
| `CabinetPackageRuntime` | 2.7.x | `ISFX` descriptor and bounded Microsoft Cabinet | XOR + `@GDG` + LZHUF named resources and `GINFOS` | Cabinet entries and nested MSI when present |
| `LegacyEmbeddedPeRuntime` | 2.8.x | `RCDATA/ENG` PE plus one 7z payload | XOR + safe `AP32`/aPLib named resources and `GINFOS` | 7z payload, runtime resources, and nested MSI |
| `CompressedResourceRuntime` | 2.9.x | outer `GP`/LZMA runtime plus one 7z payload | XOR + inner `GP`/LZMA named resources and `GINFOS` | 7z payload, decoded runtime PE, and raw encoded configuration |
| `SplitArchiveRuntime` | 3.x through current | optional UPX/LZMA launcher image plus independent payload and runtime 7z archives | integrity-checked reconstructed PE, runtime data files, and bounded `PBCore.SetVar` call-site evidence | payload and runtime archives |

`PaquetBuilderFormatCatalog.psd1` stores these profiles. Add a new route only when a fixture proves a physical difference rather than a version-label difference.

## Implementation mapping

- `Modules/PackageModule/Libraries/Installers/PaquetBuilder.psm1`
- `Modules/PackageModule/Libraries/Installers/PaquetBuilderFormatCatalog.psd1`
- `Modules/PackageModule/Assets/Source/PaquetBuilder/PaquetBuilderClassicDecoder.cs`
- `Modules/PackageModule/Assets/Source/PaquetBuilder/PaquetBuilderApLibDecoder.cs`
- `Modules/PackageModule/Assets/Source/PaquetBuilder/PaquetBuilderPeScanner.cs`
- `Modules/PackageModule/Libraries/Infrastructure/Archive.psm1`

## Source references

- [Paquet Builder package command line](https://www.installpackbuilder.com/help/automation-command-line/package-installer-command-line)
- [Archived download.installpackbuilder.com builder installers](https://web.archive.org/web/*/https://download.installpackbuilder.com/pbinst.exe)
- [Archived installpackbuilder.com builder installers](https://web.archive.org/web/*/http://www.installpackbuilder.com/files/pbinst.exe)
- [Archived gdgsoft.com builder installers](https://web.archive.org/web/*/http://www.gdgsoft.com/files/pbinst.exe)
- [Archived gdgsoftware.com x86 builder installers](https://web.archive.org/web/*/https://download.gdgsoftware.com/pb/pbinst.exe)
- [Archived files.gdgsoft.com builder installers](https://web.archive.org/web/*/https://files.gdgsoft.com/pb/pbinst.exe)
- [Archived gdgsoftware.com x64 builder installers](https://web.archive.org/web/*/https://download.gdgsoftware.com/pb/pbinst64.exe)
- [aPLib format documentation](https://documentation.help/aPLib/general.html)
- [aPLib decompression API documentation](https://documentation.help/aPLib/decompression.html)
