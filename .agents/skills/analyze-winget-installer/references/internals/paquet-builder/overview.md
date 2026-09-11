# Paquet Builder internals

This reference describes the Paquet Builder structures consumed by Dumplings. Use the [Paquet Builder workflow](../../families/paquet-builder/workflow.md) for manifest decisions and [binary notation](../../parser-development/binary-notation.md) for diagram conventions.

## Format catalog

Paquet Builder changed its physical package format several times without changing the outer `.exe` convention. `PaquetBuilderFormatCatalog.psd1` records the verified structural routes. The parser dispatches by resources and validated archive contents, not by PE version text.

| Route | Observed builder range | Required structure | Payload extraction | Runtime analysis |
| --- | --- | --- | --- | --- |
| `ClassicResourcePackage` | 2.6.x | `DESCRIPTION`, `DVCLAL`, and `PACKAGEINFO` `RCDATA`; overlay GPacker control block followed by ZIP | Outer ZIP supported | GPacker/LZHUF control stream validated; installed GAF paths unresolved |
| `CabinetPackageRuntime` | 2.7.x | `ENG` starts with `MZ`; `ISFX` contains exact package and cabinet offsets; payload starts with `MSCF` | Supported | ISFX descriptor, Microsoft Cabinet, and sole nested MSI |
| `LegacyEmbeddedPeRuntime` | 2.8.x | One valid 7z payload; `ENG` starts with `MZ`; optional `ISFX` | Supported | Embedded PE runtime and sole nested MSI |
| `CompressedResourceRuntime` | 2.9.x | One valid 7z payload; `ENG` has a `GP` raw-LZMA frame | Supported | Embedded runtime PE decoded; separately sized trailing state unresolved |
| `SplitArchiveRuntime` | 3.x through current | Independent payload and runtime 7z archives; runtime contains `pbfprop.dat` or `PBCore*.dll` | Supported | Catalog and bounded native-code evidence |

The capture timestamp is not a format version. Truncated one-megabyte Wayback responses are rejected because they do not contain a complete structural route.

## Common PE layer

Every verified installer is a PE image. The parser reads the PE section map, data directories, version resources, `RCDATA`, requested execution level, and mapped native code. The overlay begins after the largest `PointerToRawData + SizeOfRawData` section end. Certificate data and overlay archives are treated as file ranges rather than mapped virtual addresses.

```text
DOS header / PE headers
+-- section table
|   +-- virtual address and virtual size
|   +-- raw file offset and raw size
|   `-- executable characteristic used by the SetVar scanner
+-- .rsrc
|   +-- RT_VERSION
|   +-- RT_MANIFEST
|   `-- RT_RCDATA generation-specific records
+-- import and delay-import directories
`-- overlay at max(section.RawOffset + section.RawSize)
```

The native scanner materializes only PE headers and file-backed sections, with a 256 MiB limit. It never reads a multi-gigabyte payload overlay into memory. PE import evidence is optional: an old linker layout that cannot be mapped does not invalidate a structurally confirmed container.

## Classic 2 GPacker and ZIP package

The 2.6 route has no 7z archive. Detection requires Paquet identity, all three named `RCDATA` records, and a valid overlay envelope. The envelope carries an adaptive-Huffman/LZSS GPacker control stream and gives the exact boundary of the following ZIP package.

```text
PE
+-- .rsrc / RT_RCDATA
|   +-- DESCRIPTION   observed package description data
|   +-- DVCLAL        observed runtime/package data
|   `-- PACKAGEINFO   observed package metadata
`-- overlay at OverlayOffset
    +-- 20-byte classic envelope prefix
    +-- 12-byte GPacker header
    +-- compressed control bytes
    `-- ZIP package at OverlayOffset + 20 + PackedBlockSize
```

```text
Overlay-relative  Size  Meaning
----------------  ----  ------------------------------------------------------------
0x00                 1  EnvelopeVersion = 3
0x01                11  Observed prefix
0x0C                 4  PackedBlockSize, uint32 LE, including GPacker header
0x10                 4  Observed trailer word
0x14                 4  Magic 40 47 44 47 ("@GDG")
0x18                 4  Uncompressed control size, uint32 LE
0x1C                 4  Control CRC32, uint32 LE
0x20                 n  GPacker/LZHUF bytes; nominal n = PackedBlockSize - 12
0x14+PackedBlockSize  ... ZIP local header and package data
```

The GPacker decoder uses a 4096-byte LZSS ring initialized with spaces, a 60-byte lookahead, threshold 2, 314 literal/length symbols, a 627-node adaptive Huffman tree, root node 626, and reconstruction at frequency `0x8000`. Its canonical 64-symbol position alphabet has code lengths 3, 4, 5, 6, 7, and 8 bits. The historical bit reader may prefetch one byte from the following ZIP, so the envelope's `PackedBlockSize` remains authoritative rather than the decoder's consumed-byte count. The parser validates the complete decoded control stream against its CRC32 before accepting the route.

The complete observed package ZIP contains `SETUP.EXE` and `SETUP1.GAF`. A GAF is itself a sequence of `GAF 1C` records with compressed members, but the control-to-installed-destination mapping is not yet source-backed. `Expand-PaquetBuilderInstaller` therefore exports the exact outer ZIP entries without claiming that the archive names are installed paths. An incomplete Wayback capture can still prove the envelope and control CRC but reports that the following ZIP is absent or truncated.

## Cabinet 2.7 package runtime

Paquet Builder 2.7 replaced the Classic overlay with an `ISFX` descriptor that points to an opaque configuration area and a Microsoft Cabinet. Its `ENG` resource is a PE runtime with the exported package entry point `GPBExecutePack`.

```text
PE
+-- RCDATA/ENG: MZ cabinet runtime
+-- RCDATA/ISFX: 24-byte descriptor
`-- package data
    +-- opaque configuration at PackageOffset .. PayloadOffset
    `-- MSCF cabinet at PayloadOffset, bounded by header cbCabinet
```

```text
ISFX-relative  Size  Meaning
-------------  ----  -------------------------------------------------------
0x00              1  Descriptor version = 3
0x01              3  Magic 47 44 47 ("GDG")
0x04              4  Observed uint32 LE field
0x08              4  Absolute PackageOffset, uint32 LE
0x0C              4  Absolute PayloadOffset, uint32 LE
0x10              8  Reserved, zero in verified media
```

The parser requires `0 < PackageOffset < PayloadOffset < FileLength`, validates `MSCF` at `PayloadOffset`, reads the cabinet's declared `cbCabinet`, and never treats the rest of the executable as an unbounded archive. A sole nested MSI in this exact route can own ProductCode, UpgradeCode, scope, and Apps & Features metadata. The bytes between the two ISFX offsets remain unresolved configuration evidence.

## Legacy 2.8 embedded runtime

The 2.8 route stores one standard 7z payload in the overlay and a complete runtime executable in `RCDATA/ENG`.

```text
PE
+-- RCDATA/ENG
|   0x00  2  4D 5A (MZ)
|   ...      embedded Paquet Builder 7z SFX runtime PE
+-- RCDATA/ISFX, optional 24-byte observed launcher descriptor
`-- overlay/7z
    +-- PBSetup.msi
    `-- PBSetup1.cab
```

The archive is validated from its 32-byte 7z start header and exact next-header range. The verified builder installer contains exactly one MSI, so the parser extracts that entry to an automatically removed temporary directory and reads its ProductCode, UpgradeCode, scope, and ARP fields. This rule is restricted to the 2.8 route; a sole MSI in a later installed-file payload is not automatically treated as the outer package owner.

## Resource 2.9 GP/LZMA runtime

The 2.9 route still has one independently valid 7z payload, but `RCDATA/ENG` begins with `47 50` (`GP`) rather than `MZ`.

```text
PE
+-- RCDATA/ENG: GP-framed raw-LZMA runtime
`-- overlay/7z
    `-- application payload entries
```

```text
ENG-relative  Size  Meaning
------------  ----  --------------------------------------------------------
0x00             2  Magic 47 50 ("GP")
0x02             4  Uncompressed PE size, uint32 LE
0x06             4  Trailing data size, uint32 LE
0x0A             4  Observed uint32 LE field; not assigned CRC semantics
0x0E             5  LZMA properties
0x13             n  Raw LZMA stream
0x13+n           m  Package-specific trailing data, m = TrailingDataSize
```

The compressed size is `ResourceSize - 19 - TrailingDataSize`. The parser bounds and decodes that raw LZMA range, requires the declared output size, validates the result as a PE, and can export it as `ENG.exe`. It exports the trailing bytes separately as `ENG.tail.bin`; those bytes remain opaque and are never appended to the PE or assigned invented semantics. The application 7z payload is independently validated, listed, and extracted.

## Split 3 and later archives

Modern media appends at least two complete 7z archives. Each candidate has its own 7z signature, start-header CRC, next-header offset, next-header size, catalog, and packed streams. Archive adjacency does not identify purpose.

```text
PE overlay
+-- archive A
|   `-- application payload catalog
+-- optional padding or unrelated overlay bytes
`-- archive B
    +-- pbfprop.dat
    +-- pbdlg.dat
    +-- pblng.dat
    +-- pbremove.dat
    `-- PBCore.dll / PBCore64.dll / PBCoreA64.dll
```

An archive containing `pbfprop.dat` or a `PBCore*.dll` name is the runtime archive. The largest remaining validated archive is selected as the application payload. Catalog contents are copied into ordinary parser objects before each archive context is disposed.

### pbfprop.dat

Observed modern `pbfprop.dat` files contain repeated five-line records separated by CRLF. Dumplings labels fields conservatively where semantics are not yet proven.

```text
Record-relative line  Meaning
--------------------  ----------------------------------------------
0                     payload-relative path
1                     observed field 1
2                     observed field 2
3                     component-variable name
4                     decimal flags when parseable
```

Trailing empty lines are ignored. A remaining line count that is not divisible by five produces `PaquetBuilder.Runtime.PropertyCatalogMalformed`; incomplete records are not guessed.

### pblng.dat, pbdlg.dat, and pbremove.dat

`pblng.dat` repeats `[PBLang]`, a language name, and a decimal LCID. `pbdlg.dat` contains bracketed dialog identifiers and related runtime UI data. `pbremove.dat` begins with `MZ` in verified media and is the generated-uninstaller template. Its presence proves that the package carries uninstall machinery, but a visible ARP entry still requires a source-backed uninstall identity.

## Compiled PBCore evidence

Modern package PEs import or delay-import `SetVar` from `PBCore.dll`, `PBCore64.dll`, or `PBCoreA64.dll`. The shipped `pbcore.h` describes `SetVar(name, value)`. Dumplings resolves the relevant IAT slot and scans executable sections for bounded literal call-site evidence.

```text
x64 Windows ABI                         x86 call shape
RCX -> UTF-16 variable name             push UTF-16 value address
RDX -> UTF-16 literal value             push UTF-16 name address
call PBCore!SetVar IAT                  call [PBCore!SetVar IAT]
```

The scanner tracks direct RIP-relative `LEA`, register copies, conditional moves, and direct or register-indirect IAT calls. It accepts only bounded null-terminated UTF-16 strings and simple variable names. Results are evidence candidates rather than a complete native-code emulation, so each projected field applies an additional allowlist.

`PBINSTALLSCOPE=0` means user scope and `PBINSTALLSCOPE=1` means machine scope in controlled builder output. Both values in one artifact indicate conditional routing. `DESTPATH` is projected only when one literal path resolves after replacing verified variables. `%PBINSTALLSCOPEDIR%` maps to `%LOCALAPPDATA%\Programs` for a singular user route and `%ProgramFiles%` for a singular machine route. `%PROGFILESDIR%`, `%LOCALAPPDATADIR%`, and `%APPDATADIR%` map to their manifest-safe equivalents. Dialog-derived values such as `%DLGSELPATH%` remain unresolved.

Current verified media contains literal `SILENT=1` call paths when built-in `/s` handling is compiled. A project with only `SILENT=0`, or an older route without the call evidence, does not receive silent-switch suggestions.

## ARP identity

The native scanner searches mapped PE data for the exact UTF-16 prefix `Software\Microsoft\Windows\CurrentVersion\Uninstall\` and reads a bounded null-terminated key suffix. A suffix containing another slash, backslash, percent variable, or control character is rejected. One unique literal suffix can become `ProductCode`; multiple suffixes remain ambiguous.

The current builder installer contains `GDGSoftPB2019`. The 2.8 wrapper obtains its ARP identity from the verified nested MSI instead. PE ProductName and CompanyName are identity metadata, not a substitute for an uninstall-key name.

## Extraction invariants

Every ZIP, Microsoft Cabinet, and 7z range is bounded before its archive reader opens it. Extraction applies aggregate byte and entry limits, rejects links and traversal, resolves source and destination paths before managed I/O, and applies collision handling only after a collision occurs. `-ArchiveKind All` prefixes output with `Payload` or `Runtime` to prevent same-name files from different physical containers from colliding silently.

Classic extraction exports the validated outer ZIP entries. Cabinet 2.7 extraction materializes only the exact ISFX-declared cabinet range for the shared cabinet reader. Runtime PE resources are copied directly from validated file offsets. The 2.8 `ENG` resource receives an `.exe` suffix, the decoded 2.9 runtime is `ENG.exe`, its opaque tail is `ENG.tail.bin`, and unknown `RCDATA` values receive `.bin`. These names describe parser output rather than executable actions.

## Remaining limits

Classic GAF members and their installed-destination catalog are not yet projected, the 2.7 configuration area remains opaque, and the 2.9 trailing runtime state is not decoded. The compiled scanner does not emulate arbitrary native branches, external DLL calls, or dynamically assembled variable values. Registry writes, protocols, and file associations remain empty until a literal structured registry model is recovered. These gaps produce diagnostics or unresolved fields rather than inferred metadata.

## Implementation mapping

- `Modules/PackageModule/Libraries/Installers/PaquetBuilder.psm1`
- `Modules/PackageModule/Libraries/Installers/PaquetBuilderFormatCatalog.psd1`
- `Modules/PackageModule/Assets/Source/PaquetBuilder/PaquetBuilderPeScanner.cs`
- `Modules/PackageModule/Assets/Source/PaquetBuilder/PaquetBuilderClassicDecoder.cs`
- `Modules/PackageModule/Libraries/Infrastructure/Archive.psm1`

## Source references

- [Paquet Builder package command line](https://www.installpackbuilder.com/help/automation-command-line/package-installer-command-line)
- [Archived download.installpackbuilder.com builder installers](https://web.archive.org/web/*/https://download.installpackbuilder.com/pbinst.exe)
- [Archived installpackbuilder.com builder installers](https://web.archive.org/web/*/http://www.installpackbuilder.com/files/pbinst.exe)
- [Archived gdgsoft.com builder installers](https://web.archive.org/web/*/http://www.gdgsoft.com/files/pbinst.exe)
- [Archived gdgsoftware.com x86 builder installers](https://web.archive.org/web/*/https://download.gdgsoftware.com/pb/pbinst.exe)
- [Archived files.gdgsoft.com builder installers](https://web.archive.org/web/*/https://files.gdgsoft.com/pb/pbinst.exe)
- [Archived gdgsoftware.com x64 builder installers](https://web.archive.org/web/*/https://download.gdgsoftware.com/pb/pbinst64.exe)
