# Astrum InstallWizard internals

## Scope

Astrum InstallWizard 1.x and 2.x append a compiled configuration, installation-item table, file records, and a compact footer to a native PE setup runtime. This document records only fields consumed or validated by Dumplings. Unknown fixed-tail fields and descriptor words retain observed names because assigning semantics without controlled evidence would make parser output unsafe.

Normal single-file media is verified from archived Astrum 1.80 through 2.29.50. Tiny, tiny-verbose, and spanned routes have controlled 2.29.50 fixtures. The parser distinguishes the physical `Legacy1`, `Early2`, and `Modern2` configuration profiles; these names describe record layouts and do not claim an exact builder release when the setup runtime does not expose one.

`AstrumInstallWizardFormatCatalog.psd1` stores the two overlay descriptors and three configuration profiles independently from parser code. Footer length selects `astrum-1` or `astrum-2`; validated fields from that descriptor select `Legacy1`, `Early2`, or `Modern2`. Each descriptor owns its footer offsets, accepted trailer routes, file-record width, condition and registry framing, optional tables, container capabilities, process success codes, and validation invariants. Configuration profiles own identity framing, unattended-installation policy, and sparse option offsets. This keeps observed wire layouts auditable and prevents application-version strings from selecting a parser route.

Archived download-page and installer captures establish this observed runtime sequence: `Legacy1` in 1.80, 1.83, 1.84, 1.90, 1.91.02, 1.91.51, 1.94, 1.95.4, and 1.95.5; `Early2` in 2.01.50, 2.02.50, and 2.04.20; and `Modern2` in 2.21.20, 2.22.30, 2.23.20, 2.24.00, 2.29.00, and 2.29.50. This leaves the `Early2` to `Modern2` transition somewhere after 2.04.20 and no later than 2.21.20. The 1.95.5 capture is the first available 1.x fixture with the dual trailer magic; this observation does not claim that 1.95.5 introduced it.

## Container layers

```text
physical installer
+-- PE image
|   +-- DOS/COFF/optional headers
|   +-- executable sections
|   +-- version resources and application manifest
|   `-- optional security-directory pointer
+-- Astrum logical overlay
|   +-- twice-protected configuration block
|   +-- optional UI/runtime ranges
|   +-- generated-uninstaller GZip member
|   +-- installation-item table
|   +-- file descriptors and payload members
|   +-- footer route table
|   +-- footer pointer
|   +-- optional short signature block
|   `-- optional late-1.x/2.x trailer magic
`-- optional Authenticode certificate table
```

Ordinary PE data directories use RVAs. The security directory is exceptional: its address is an absolute file offset. For signed media the parser begins at that offset, removes at most eight zero alignment bytes, and resolves the Astrum trailer immediately before it. The certificate is outside the logical Astrum image.

## Trailer and footer pointer

Late observed 1.x and all tested 2.x media end their logical image with two little-endian unsigned 32-bit values: `0x0B1C2D3E` and `0x12345678`. Their physical bytes are `3E 2D 1C 0B 78 56 34 12`. Archived 1.80 through 1.95.4 media omit these eight bytes while retaining the same signature-length and footer-pointer suffix.

```text
Magic-bearing suffix
Offset from logical end             Size  Encoding  Field
----------------------------------  ----  --------  ---------------------------------------------
-0x08                                  8  LE        trailer magic
-0x0C                                  4  LE        optional signature-block byte count
-0x10-signatureLength                  4  LE        absolute footer offset

Legacy no-magic suffix
Offset from logical end             Size  Encoding  Field
----------------------------------  ----  --------  ---------------------------------------------
-0x04                                  4  LE        optional signature-block byte count
-0x08-signatureLength                  4  LE        absolute footer offset
```

`0xFFFFFFFF` in the signature-length slot means no optional signature block. Other values are accepted only through 1000 bytes. The footer length is the distance from its absolute offset to the pointer slot and selects the generation profile: exactly `0xE8` bytes for 1.x or `0xEC` bytes for 2.x. A no-magic route is accepted only with the 1.x footer, exact `Astrum InstallWizard` and `Thraex Software` identity inside the PE image, valid double-protected configuration, and complete catalogs.

## Tiny wrapper

The documented `/tiny` and `/tinyverbose` builder switches replace the normal setup runtime with a small PE self-extractor. One GZip member starts exactly at the outer PE overlay and expands to a complete ordinary Astrum installer. A 96-byte little-endian descriptor follows the member.

```text
tiny wrapper
+-- PE32 self-extractor through outer overlay offset
+-- GZip member: complete inner Astrum installer
`-- descriptor[96]
    +-- reserved zero prefix[64]
    +-- version:u32 LE = 1
    +-- reserved:u32 LE = 0
    +-- silentExtraction:u32 LE
    +-- reserved:u32 LE = 0
    +-- reserved:u32 LE = 0
    +-- physicalFileLength:u32 LE
    +-- outerOverlayOffset:u32 LE
    `-- compressedEnd:u32 LE = descriptor offset
```

`silentExtraction=1` identifies `/tiny`; zero identifies `/tinyverbose`. Detection binds all three offsets to physical ranges, checks the GZip magic, decompresses through a bounded disk-spilling stream, and then requires the inner file to pass the complete normal Astrum validation. Metadata and payload evidence always come from that inner installer.

## Footer route table

The verified Astrum footer is `0xE8` bytes in 1.x and `0xEC` bytes in 2.x. The configuration fields at `0x00` and `0x04` are shared. The uninstaller and catalog region begins four bytes earlier in 1.x. Route fields are unsigned big-endian 32-bit integers even though the surrounding pointer/trailer words are little-endian.

```text
Footer-relative offset  Size  Generation  Field
----------------------  ----  ----------  ------------------------------------------------
0x00                       4  both        protected configuration absolute offset
0x04                       4  both        protected configuration byte count
0xA4 / 0xA8                4  1.x / 2.x   generated-uninstaller compressed byte count
0xA8 / 0xAC                4  1.x / 2.x   generated-uninstaller absolute offset
0xAC / 0xB0                4  1.x / 2.x   installation-item count
0xB0 / 0xB4                4  1.x / 2.x   installation-item-table absolute offset
0xB4 / 0xB8                4  1.x / 2.x   installation-item-table byte count
0xB8 / 0xBC                4  1.x / 2.x   file-record count
0xBC / 0xC0                4  1.x / 2.x   first file-record absolute offset
0xC0 / 0xC4                4  1.x / 2.x   complete file-catalog and payload byte count
0xC4 / 0xC8                4  1.x / 2.x   observed aggregate expanded-size value
0xC8 / 0xCC                4  1.x / 2.x   observed aggregate installed-size value
0xE4 / 0xE8                4  1.x / 2.x   footer absolute self pointer
```

The self pointer must equal the footer's physical offset. Every routed range must end before the footer. The file-record offset plus the declared catalog/payload byte count must equal the footer offset exactly.

## Protected configuration

The configuration is protected twice by the same checksum and byte transform. Each layer has this shape:

```text
+------------------------------+
| encoded data                 | length - 10 bytes
+------------------------------+
| step                         | 1 byte
+------------------------------+
| initial accumulator          | 1 byte
+------------------------------+
| cyclic checksum[8]           | 8 bytes
+------------------------------+
```

The checksum starts as eight zero bytes and adds each byte before the checksum into slot `index % 8`, modulo 256. For decoding, the accumulator is incremented by `step` modulo 256 before each output byte; that accumulator is subtracted from the encoded byte modulo 256. The final ten bytes are removed. The resulting block is validated and decoded a second time.

## Configuration records

Configuration integers are unsigned big-endian 32-bit values. Strings are null-terminated Windows-1252. Counts, strings, recursion depth, and total records are bounded before traversal.

```text
decoded configuration
+-- four recursive registry roots: HKCR, HKCU, HKLM, HKU
+-- shortcut table
+-- INI-operation table
+-- text-operation table
+-- advanced file-operation table
+-- variable table
+-- advanced interactive-operation table
+-- optional 2.x advanced resource-operation table
+-- fixed package identity and destination fields
+-- prior-installation, application-version, icon, and language strings
+-- generation-specific uninstaller and language fields
`-- sparse fixed option block
```

A registry key stores a value count and repeated values, then a child count and repeated child keys. In 1.x each value contains a name, data, type, and uninstall behavior, while each child contains only its name and recursive key body. In 2.x values and children also carry optional conditions, and child keys carry uninstall behavior. Known type codes are `0=REG_BINARY`, `1=REG_DWORD`, `2=REG_SZ`, `3=REG_MULTI_SZ`, and `4=REG_EXPAND_SZ`.

Conditions begin with a big-endian kind. Kind zero has no body. Other kinds contain a bounded term count followed by left string, operator word, and right string for each term. The parser preserves these terms and does not claim a runtime truth value without an environment.

The first table contains shortcut target, link name, command line, working directory, icon, and a generation-specific trailing word. In 1.x that word is consumed without assigning condition semantics; in 2.x it selects the optional condition record. The INI, text, advanced-file, and advanced-interactive records follow the same versioned-tail rule. Astrum 1.x has five post-shortcut system tables and omits the advanced-resource table present in 2.x. Action code zero is the source-backed execute-program route; other actions remain available under `InteractiveOperations` instead of being mislabeled as nested payload execution. File associations are compiled into the registry tree and are projected from those literal writes rather than a separate association table.

Three configuration profiles are dispatched from structure. `Legacy1` starts fixed metadata directly with one application name and one company name, omits the advanced-resource table and default-language field, and stores generated-uninstaller name and command at the end of its fixed string sequence. `Early2` adds 2.x conditions and the advanced-resource table but retains that older fixed identity layout. `Modern2`, first represented by the archived 2.21.20 fixture, prefixes fixed metadata with a bounded runtime/encoding word and duplicate internal application/company names, then stores install icon, language strings, default language, generated-uninstaller path, and command as separate fields. The exact release that first emitted `Modern2` is not inferred from the gap between tested builders.

The following option offsets apply only to `Modern2` and are relative to the byte immediately after the generated-uninstaller command. Multi-byte requirement values are big-endian unless the table says otherwise. The offsets were isolated through single-option controlled 2.29.50 builds. `Legacy1` and `Early2` option tails remain bounded opaque evidence rather than being decoded with offsets from a different structure.

```text
Offset  Size  Byte order  Meaning
------  ----  ----------  ---------------------------------------------
0x48       4  BE          minimum CPU speed in MHz
0x4C       4  BE          CPU manufacturer code
0x50       4  BE          combined CPU vendor mask
0x54       4  BE          CPU feature flags
0x58       4  BE          minimum memory in MiB
0x60       4  BE          minimum Windows 9x build
0x6C       4  BE          minimum Windows NT service pack
0x70       2  BE          minimum DirectX major version
0x72       2  BE          minimum DirectX minor version
0x74       4  BE          minimum display width
0x78       4  BE          minimum display height
0x94       4  LE          wave-playback requirement
0x98       4  LE          MIDI-playback requirement
0x9C       4  LE          joystick requirement
0xA0       4  LE          User Information field flags
0xF0       4  LE          silent-by-default flag
0xF4       4  LE          no-generated-uninstaller flag
0x131      4  LE          x64-compliance flag
0x135      4  LE          require-administrator runtime flag
end-29     1  byte        direct license-approval flag
end-25     1  byte        prohibit-silent-without-license flag
```

The final two license flags are relative to the end because optional auto-update strings make the intervening tail variable-length. Unassigned option bytes remain opaque evidence. The standard selected dialogs are identified in the bounded pre-catalog resource region by exact compiled resource records such as `<LangID=1>User information</LangID=1>` and `<LangID=1>License agreement</LangID=1>`; arbitrary product strings are not accepted as dialog evidence.

## Installation-item table

Installation-item records are adjacent and use big-endian unsigned integers with length-prefixed Windows-1252 text.

```text
Field                       Size
--------------------------  ---------------------------------
NameLength                  UInt32BE
Name                        NameLength bytes
Flags                       UInt32BE
DescriptionLength           UInt32BE
Description                 DescriptionLength bytes
Enabled                     UInt32BE
ExpandedSize                UInt32BE
ObservedValue1              UInt32BE
ObservedValue2              UInt32BE
InstalledSize               UInt32BE
```

The declared count must consume the installation-item table exactly. File descriptors reference these groups by zero-based index.

## File records

Each 1.x file begins with a 60-byte little-endian descriptor containing fifteen unsigned 32-bit words. Each 2.x file uses 64 bytes and sixteen words. The first fifteen words have the same routed lengths and offsets in every tested fixture; only 2.x word 15 selects a condition body. Only fields established by controlled samples are named.

```text
Descriptor word  Byte offset  Generation  Meaning
---------------  -----------  ----------  -----------------------------------------------
0                0x00         both        installation-item index
2                0x08         both        flags
3                0x0C         both        Windows file attributes
10               0x28         both        observed checksum-like value
11               0x2C         both        encoded destination-name byte count
12               0x30         both        volume-offset count
13               0x34         both        physical payload byte count
15               0x3C         2.x         condition kind
```

```text
file record
+-- 60-byte 1.x or 64-byte 2.x descriptor
+-- optional 2.x little-endian condition body
+-- bit-permuted Windows-1252 destination name
+-- volumeOffsets[volumeCount]: UInt32LE
`-- payload[dataLength]
```

Destination-name bytes use a fixed bit permutation, not encryption. The parser reverses that transform and then applies safe extraction-path validation. The first two payload bytes select GZip (`1F 8B`) or stored data. A GZip member's final little-endian ISIZE is used as expected-length evidence; `GZipStream` validates the compressed stream and CRC while the shared bounded copier enforces output limits.

Single-volume records contain one offset entry. A spanned record contains one entry per physical segment, including the portion stored in the main EXE.

## Spanned logical address space

The main `.exe` retains the normal PE, configuration, installation-item table, first catalog bytes, footer, pointer, and trailer. Companion files such as `.002`, `.003`, and later contain raw continuation bytes without a separate header. Footer `fileOffset + payloadSize` points beyond the physical main-file footer and identifies the virtual footer offset.

```text
physical main EXE                  logical parser stream
+-- bytes 0 .. footerOffset       +-- same main prefix
+-- footer and trailer            +-- companion .002 bytes
`-- optional certificate          +-- companion .003 .. final volume
                                  `-- relocated footer and trailer
```

The required continuation length is `fileOffset + payloadSize - physicalFooterOffset`. It must equal the sum of every explicitly supplied companion length. The parser writes a bounded temporary logical stream as main prefix, companions in caller-provided order, then footer/trailer. It changes only the big-endian footer self pointer and little-endian trailer footer pointer to the virtual footer location. Catalog offsets, descriptors, names, and payload lengths already use the logical address space and are left unchanged.

## Generated uninstaller

Footer offsets `0xA4`/`0xA8` in 1.x and `0xA8`/`0xAC` in 2.x identify a standalone GZip member containing the generated uninstaller. The installer's explicit ARP `UninstallString` determines its installed relative filename. Default extraction emits the uninstaller only when that path resolves below the default installation directory; raw mode otherwise exposes it as `_astrum\uninstaller.exe`.

## ARP, variables, and scope

Apps & Features behavior is represented by explicit compiled registry writes under `Software\Microsoft\Windows\CurrentVersion\Uninstall`. The leaf key is the ProductCode. The parser groups values by hive and key and reads `DisplayName`, `DisplayVersion`, `Publisher`, `InstallLocation`, uninstall commands, icon, URLs, comments, and `SystemComponent`.

Deterministic variables include application and company names, install directory, Program Files, Common Files, Windows, System32, temporary directory, Start menu, Programs, Startup, and Desktop. Unknown values such as application-defined timer or DLL results remain in raw evidence and cause the affected manifest-facing field to be omitted.

The explicit ARP hive is primary scope evidence. Requested execution level and resolved destination provide fallback evidence. The x64-compliance option selects the 64-bit registry view on 64-bit Windows; otherwise the outer runtime's PE architecture supplies the registry-view default. Installed application architecture is analyzed from up to 32 selectively extracted EXE and DLL payload files under a 512 MiB aggregate bound.

## Switches and process result

Astrum 2.x builder help documents `/silent` for unattended installation, `/AcceptLicense` for configurations that require command-line license acceptance, and process exit code `1` for success. The parser suggests `/silent` and success code `1` for 2.x when the standard User Information dialog is absent. A selected User Information dialog makes silent installation fail and produces interactive-only evidence. A selected license dialog plus the prohibit-silent flag adds `/AcceptLicense` as a custom switch. The separate direct-approval and silent-by-default flags are returned as `Modern2` configuration evidence.

The archived version history records that silent installation was added in Astrum 1.22. Distributed 1.x media does not carry a separate structured builder subversion, and its application version cannot safely be treated as builder identity. The parser therefore returns `Astrum.Silent.LegacyRuntimeVersionRequired` and withholds silent switches and success-code suggestions for 1.x until external builder-version evidence or VM validation resolves them.

## Parser limits and gaps

The parser bounds footer and signature sizes, configuration bytes, recursive depth, record counts, string sizes, catalog ranges, selective PE analysis bytes, extraction entries, and aggregate expanded bytes. It restores caller-owned stream position through shared random-access helpers and opens each top-level installer once.

Supported media covers normal Astrum InstallWizard 1.x and 2.x single-file installers, 2.x tiny and tiny-verbose wrappers, explicitly supplied 2.x spanned volumes, stored or GZip payload members, and certificate tables after the logical payload. Raw extraction exports each file-record header and every bounded pre-catalog range not owned by the configuration or generated uninstaller, which makes compiled dialog and image bytes available without assigning invented resource types. Remaining gaps are the precise introduction release for `Modern2`, semantics of legacy operation-tail words when nonzero, legacy and early-2 option fields, unknown checksum word 10, exact advanced-resource record semantics, several operating-system requirement indexes, typed UI resource routing, and Astrum 1.x tiny/spanned media for which no structural fixture is available.

## Implementation mapping

- `Modules/PackageModule/Libraries/Installers/AstrumInstallWizard.psm1`: footer, protected configuration, catalog, metadata, ARP, extraction, and generated uninstaller.
- `Modules/PackageModule/Libraries/Installers/AstrumInstallWizardFormatCatalog.psd1`: immutable generation and configuration-profile descriptors selected from validated structure.
- `Modules/PackageModule/Libraries/Infrastructure/Archive.psm1`: bounded GZip decompression.
- `Modules/PackageModule/Libraries/Infrastructure/InstallerAnalyzer.psm1`: strict structural routing before heuristic generic-EXE candidates.
- `Modules/PackageModule/Libraries/WinGet/WinGetAnalysis.psm1`: schema-valid generic-EXE projection.

## Fixtures

- Controlled Astrum 2.29.50 project: independent application and ARP names, version, publisher, install directory, stored payload, generated uninstaller, and nested execution record.
- Controlled `/tiny` and `/tinyverbose` variants: 96-byte descriptor and GZip-compressed complete inner installer.
- Controlled five-part spanning project: a 2 MiB incompressible payload crossing the main EXE and four companion volumes.
- Astrum InstallWizard 1.80 builder installer, SHA256 `71D6C6361D2B069E7B28AC9B460FD47A4AF71C07A5A82D2B0349623D9F0636A0`: no trailer magic, `0xE8` footer, 60-byte file descriptors, and 148 payload records.
- Astrum InstallWizard 1.95.5 builder installer, SHA256 `1245412FFA57761A988D7881062ACE262EB9C9F2BA028F55544CDB24423C6F7C`: late 1.x magic-bearing suffix and 209 payload records.
- Astrum InstallWizard 2.01.50 builder installer, SHA256 `DA0D51CE828C3AC56248725E4130D641F306921AF850E8522340928A4B1F3EB6`: `Early2` configuration and 157 payload records.
- Astrum InstallWizard 2.21.20 builder installer, SHA256 `E03460739CD74A76C23038B5DA33074E3FF0D436E729D8ADEE4C27DE53C91FA1`: `Modern2` configuration and Authenticode-after-payload route.
- Astrum InstallWizard 2.29.50 builder installer, SHA256 `657A8F9CC933A5E11378F65378FE55347A45781948D300A12FE0FD41256C2F8A`: 124 payload records and two installation-item groups.
- BreakAlube PC-GINA 1.0.1.5, SHA256 `9024FD2F27A0B2192B44A00A66FB2BFA37E5309DA3645194E9FC6F1D1E158600`: application, nested driver installer, manuals, and a localized unresolved ARP template.

## Source references

- [Thraex Software](https://www.thraexsoftware.com/)
- [Archived Astrum InstallWizard installer](https://web.archive.org/web/20130816053259/http://www.thraexsoftware.com/download/aiw.exe)
- [Archived Astrum InstallWizard download page](https://web.archive.org/web/20120410054204id_/http://www.thraexsoftware.com/aiw/download.html)
- [Archived Astrum InstallWizard version history](https://web.archive.org/web/20120410054204id_/http://www.thraexsoftware.com/aiw/version_history.txt)
- Astrum InstallWizard 2.29.50 builder-shipped help and sample project.
- Controlled `aiw2.exe /build` output and static observations of archived builder installers from 1.80 through 2.29.50.
