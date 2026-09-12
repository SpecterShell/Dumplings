# Setup Factory internals

This reference describes the Indigo Rose Setup Factory structures consumed by Dumplings. For package analysis and manifest authoring, use the [Setup Factory workflow](../../families/setup-factory/workflow.md).

Read [binary notation](../../parser-development/binary-notation.md), [parser contracts](../../parser-development/contracts.md), and [performance guidance](../../parser-development/performance.md) before changing the parser.

## Product generations

Setup Factory release identity and archive format are separate facts. A project can replace the outer launcher's version resource, and releases 8 through 10 use the same observed doubled-signature container. Parser dispatch therefore uses structural profiles; trusted PE version information is supplemental release evidence.

| Profile | Observed releases | Outer header | Outer extraction | `irsetup.dat` metadata |
| --- | --- | --- | --- | --- |
| `Classic4` | 4.x and one early 5.x runtime | Seven-byte magic; byte 7 is the entry count | Supported | Global settings, built-in uninstall, registry, and files supported; absent product fields remain unresolved |
| `Legacy5` | 5.x | Eight-byte magic; `uint32` entry count; 16-byte names | Supported | Product, built-in uninstall, registry framing, and condition framing supported; runtime-dependent conditions remain unresolved |
| `Legacy6` | 6.x | Eight-byte magic; `uint32` entry count; 260-byte names | Supported | Product and built-in uninstall supported; custom actions partial |
| `Modern7` | 7.x | Eight-byte magic; optional extra byte; transformed runtime; 260-byte names | Supported | Supported |
| `Modern8Plus` | 8.x through 10.x | Doubled magic; transformed runtime; optional Lua runtime; 264-byte names | Supported | Supported |

Setup Factory 3.1 is distributed as multi-file media rather than the later single-file PE overlay. The archived `suf310.zip` contains `SETUP.EXE`, `IRDATA.IRD`, `W31ENG.*`, compressed builder files, and support DLLs. That layout is catalogued as historical evidence but is not accepted by the single-file parser.

## Embedded runtime release identity

Every supported single-file generation contains one outer-catalog entry named `irsetup.exe`. Decoding the catalog record, reversing the 2,000-byte XOR transform where applicable, and reading that PE's version resource provides stronger release evidence than the outer launcher because projects can replace the launcher's product identity. Release evidence remains subordinate to structural dispatch: a trusted runtime that conflicts with the validated overlay profile produces a diagnostic and never changes the record reader.

| Release media | Embedded product name | Embedded original filename | Observed embedded version |
| --- | --- | --- | --- |
| 4.0 | `Indigo Rose Corporation Setup` | `irsetup.exe` or `setup.exe` | 4.0.0.1 and 4.0.0.8 |
| 5.0 | `Setup Factory 5.0 Runtime Module setup32` | `setup32.exe` | 5.0.0.3 and 5.0.1.6 |
| 6.0 | `Setup Factory 6.0 Runtime Module` | `SUF60Runtime.exe` | 6.0.1.2 and 6.0.1.4 |
| 7.0 | `Setup Factory 7.0 Runtime` | `suf70_rt.exe` | 7.0.1.0 through 7.0.6.1 |
| 8.0 | `Setup Factory 8.0 Runtime` | `suf80_rt.exe` | 8.1.1008.0 |
| 9.x | `Setup Factory Runtime` | `suf_rt.exe` | 9.0.3.0 through 9.5.3.0 |
| 10.x | `Setup Factory Runtime` | `suf_rt.exe` | 10.2.0.0 |

The parser requires a numeric four-part runtime version and a compatible product-name/original-filename pair from the format catalog before treating the embedded identity as trusted. Missing or customized version resources remain nonblocking release-evidence diagnostics because the catalog can still prove the installer family and structural route.

## Container layers

```text
Setup executable
+-- PE headers, sections, resources, optional Authenticode certificate
`-- PE overlay at Get-PEOverlayOffset
    +-- generation signature and catalog framing
    +-- optional transformed irsetup.exe runtime
    +-- optional lua5.1.dll runtime
    +-- outer catalog
        +-- irsetup.dat compiled project metadata
        +-- language and UI resources
        +-- optional images and support files
        `-- individually compressed outer records
    +-- optional bundled prerequisite payloads described by CDependencyFile
    `-- installed application payload streams described by CFileInfo or CSetupFileData

irsetup.dat after decompression
+-- generation-specific object and class tables
+-- CSessionVar table in supported modern layouts
+-- compiled Lua and action data
+-- uninstall configuration
`-- file, registry, shortcut, service, and runtime actions
```

Offsets below are absolute file offsets after adding the PE overlay offset. Integer fields are little-endian. Catalog names are fixed-width byte fields terminated by the first NUL byte.

## Classic4 overlay

```text
Offset  Size  Field
------  ----  --------------------------------------------------------
0x00       7  Magic: E0 E1 E2 E3 E4 E5 E6
0x07       1  EntryCount
0x08       *  Repeated Classic4Entry records

Classic4Entry
+0x00      16  Name, NUL-terminated Windows text
+0x10       4  PackedSize, uint32
+0x14       4  Expanded CRC32, uint32
+0x18       *  PKWARE-compressed data, PackedSize bytes
```

The apparent missing `E7` byte is intentional: the count occupies the eighth byte. A release-version string cannot distinguish this route from a structurally similar early 5.x runtime, so the parser records the physical profile separately from the release candidate.

## Classic4 metadata and registry objects

Setup Factory 4 starts `irsetup.dat` with embedded `CGeneralData`, `CConclusionData`, and `CUninInfo` members rather than later standalone product variables. Two source-backed conclusion layouts are accepted: the production `Object24` layout and the builder-media `Scalar32` layout. The parser validates every Boolean byte, requires one unique later `CImageInfo` table as the upper boundary, and accepts an enabled uninstaller only when both the Control Panel description and unique key are non-empty.

```text
CGeneralData
+0x00       *  SetupTitle, variable string
next        1  WizardEnabled, Boolean
next        *  WizardStyle, variable string
next        *  LanguageFile, variable string
next        1  LanguageMode
next        *  FolderAnimation, variable string
next        4  Four Boolean flags
next        4  EvaluationCount, uint32 LE
next        *  EvaluationMessage, variable string
next        1  EvaluationEnabled, Boolean
next        4  EvaluationTimestamp, uint32 LE

CConclusionData Object24        CConclusionData Scalar32
+0x00       1  observed flag    +0x00       4  observed uint32
next        *  observed text
next        *  observed text
next        2  observed flags
next        *  observed text
next        *  observed text
next        1  observed flag
next        4  observed uint32

CUninInfo
+0x00       1  IncludeUninstall, Boolean
next        *  ControlPanelDescription, variable string
next        *  UniqueRegistryKey, variable string
next        *  ShortcutDescription, variable string
next        *  RemoveDescription, variable string
next        *  AdditionalText, variable string
next        1  ShowWizard, Boolean
next        *  WelcomeTitle, variable string
next        *  WelcomeText, variable string
next        *  CompletionTitle, variable string
next        *  CompletionText, variable string
```

These objects do not store the later product version, publisher, or default installation-directory variables. An enabled `CUninInfo` still proves its concrete ARP key and display name; a disabled object retains configuration defaults but proves no ARP write.

Setup Factory 4 serializes install-time registry commands through an MFC `CObList` of `CRegistryData`. Its root enum differs from version 5 because it has no HKCC member. The runtime dispatcher proves that the entire list is skipped in uninstall mode.

```text
Setup Factory 4 CRegistryData
+0x00       1  Action: 0 CreateKey, 1 DeleteKey, 2 SetValue
+0x01       1  Root: 0 HKCR, 1 HKCU, 2 HKLM, 3 HKU
+0x02       *  Key, variable string
next        1  ValueType: 0 REG_DWORD, 1 REG_SZ
next        *  ValueName, variable string
next        *  ValueData, variable string
```

## Legacy5 and Legacy6 overlays

```text
Offset  Size  Field
------  ----  --------------------------------------------------------
0x00       8  Magic: E0 E1 E2 E3 E4 E5 E6 E7
0x08       4  EntryCount, uint32
0x0C       *  Repeated records

Legacy5Entry                     Legacy6Entry
+0x00      16  Name              +0x000     260  Name
+0x10       4  PackedSize        +0x104       4  PackedSize
+0x14       4  Expanded CRC32    +0x108       4  Expanded CRC32
+0x18       *  CompressedData    +0x10C       *  CompressedData
```

No separate transformed runtime precedes these catalogs. `irsetup.exe` is an ordinary catalog entry and uses the same compressed-record handling as the other entries.

## Legacy5 and Legacy6 metadata blocks

Setup Factory 5 and 6 serialize global product values as eight variable-length strings followed by an exact three-byte trailer and one install-log path. A variable string uses a one-byte length when shorter than 255 bytes and `FF` followed by a little-endian `uint16` otherwise. The product block follows a terminated fixed-field region and occurs before `CImageInfo`; these boundaries prevent arbitrary UI text from being accepted as metadata. `CPasswordData` is an optional earlier class and narrows the search when present, but password-free projects omit it entirely.

```text
Legacy product block
+0x00       *  ProductName, variable string
next        *  CompanyName, variable string
next        *  ProductTagline, variable string
next        *  ProductVersion, variable string
next        *  Copyright, variable string
next        *  InformationUrl, variable string
next        *  DefaultInstallLocation, variable string
next        *  ShortcutFolder, variable string
next        1  Reserved, observed 00
next        1  Record tag, observed 03
next        1  CreateInstallLog, Boolean 00 or 01
next        *  InstallLogPath, variable string
```

The built-in uninstall block precedes the product block and is anchored independently by its ordered fields and an `irunin.ini` or `irunin.dat` configuration path. The builder help identifies these values as Add/Remove Programs and uninstall-shortcut settings. A project can retain names and paths while disabling uninstall support, so `IncludeUninstall` is authoritative and gates both `WritesAppsAndFeaturesEntry` and ProductCode projection.

```text
Legacy built-in uninstall block
+0x00       1  IncludeUninstall, Boolean 00 or 01
+0x01       *  ControlPanelDescription, variable string
next        *  UniqueRegistryKey, variable string
next        1  CreateShortcut, Boolean 00 or 01
next        *  ShortcutDescription, variable string
next        1  UseExternalIcon, Boolean 00 or 01
next        *  ExternalIconPath, variable string
next        *  ConfigurationFile, variable string ending in irunin.ini or irunin.dat
```

The parser maps `%ProductName%`, `%ProductVer%`, `%CompanyName%`, `%ProductTagline%`, `%Copyright%`, `%InfoURL%`, `%AppDir%`, `%AppFolder%`, and `%SCFolderTitle%` from these blocks. `%ProgramFiles%` remains a terminal manifest-safe system variable rather than recursively resolving to itself. The shipped Setup Factory 5.0.1.6 and 6.0.1.4 builder projects, a password-free Text Tally 1.1 installer, and a Setup Factory 6.0.1.2 installer exercise the same framing.

Setup Factory 5 stores installation-time registry commands in a counted MFC `CRegistryData` table. The shipped 5.0.1.6 runtime serializer and its registry-report routine establish the field order and enums. The class declaration appears on the first record; later records use one stable high-bit MFC class-reference token. The parser validates the declared count and token consistency rather than scanning nearby strings as registry evidence.

```text
Setup Factory 5 CRegistryData table
+0x00       2  EntryCount, uint16 LE
+0x02       2  First-object tag FFFF
+0x04       2  Class schema, observed 0001
+0x06       2  Class-name length, uint16 LE = 13
+0x08      13  ASCII "CRegistryData"
next        *  First CRegistryData record
next        2  MFC class-reference token, high bit set
next        *  Next CRegistryData record
...            repeated to EntryCount

CRegistryData record, serialized field order
+0x00       1  Action: 0 CreateKey, 1 DeleteKey, 2 SetValue, 3 DeleteValue
+0x01       1  Root: 0 HKCR, 1 HKCC, 2 HKCU, 3 HKLM, 4 HKU
+0x02       *  Key, variable string
next        *  ValueName, variable string
next        1  ValueType: 0 REG_DWORD, 1 REG_SZ
next        *  ValueData, variable string
next        1  ExistingValueAction
next        *  Separator, variable string
next        1  Flags
next        4  OperatingSystemMask, uint32 LE; FFFFFFFF is unconditional across the runtime's supported OS set
next        4  PackageSelector, uint32 LE; zero means no package filter
next        *  LanguageSelector, variable string; `None` means no language filter
next        2  ConditionCount, uint16 LE
if nonzero  *  MFC CObList of CConditionData records
next       16  Four reserved/observed uint32 values
next        *  Four reserved/observed variable strings

CConditionData record
+0x00       *  ValueA, variable string
next        *  ValueB, variable string
next        4  Operator: 0 Equals, 1 GreaterThan, 2 LessThan, 3 GreaterThanOrEqual, 4 LessThanOrEqual, 5 NotEqual
next        4  Observed integer
next        4  Observed integer
next        *  Observed string
next        *  Observed string
```

The common condition evaluator in the 5.0.1.6 runtime checks the OS mask, selected package, language, and then every advanced comparison. An all-OS mask, package zero, language `None`, and an empty advanced list prove unconditional execution and permit a Set Value record to become `RegistryWrites`. A non-empty or environment-dependent condition remains a fully bounded record with `ConditionState: Unknown`; it does not desynchronize later records and is not projected as a deterministic write. A table after the built-in uninstall configuration is classified as uninstall behavior and never projected as installed-state evidence.

Setup Factory 6 replaces the family-specific registry table with generic counted `CAction` lists. Reverse engineering the 6.0.1.4 runtime serializer establishes the complete 192-byte in-memory object member order, while the serialized stream remains variable length because every `CString` is length-prefixed. Four counted lists before the uninstall configuration correspond to the documented Startup, Before Installing, After Installing, and Shutdown tabs. A later counted list belongs to the generated uninstaller.

```text
Setup Factory 6 CAction list
+0x00       2  ActionCount, uint16 LE
+0x02       2  First-object tag: FFFF for the first class declaration, otherwise a stable high-bit class reference
first only  2  Class schema, observed 0001
first only  2  Class-name length, uint16 LE = 7
first only  7  ASCII "CAction"
next        *  CAction record
next        2  Same MFC class-reference token
next        *  CAction record
...            repeated to ActionCount

CAction record, relevant serialized members
+0x00       4  Object schema, uint32 LE = 1
+0x04       4  ActionId, uint32 LE
variable    *  Remaining integer and variable-string members in runtime serializer order
member +38  4  Registry operation for ActionId 17: 0 CreateKey, 1 DeleteKey, 2 SetValue, 3 DeleteValue
member +54  *  Boolean expression for ActionId 100 (IF)
member +58  *  Registry value name for ActionId 17
member +68  *  Registry value data for ActionId 17
member +74  *  Registry subkey for ActionId 17
member +78  4  Registry root enum for ActionId 17
member +90  4  Registry type for ActionId 17: 1 SZ, 2 EXPAND_SZ, 3 BINARY, 4 DWORD, 7 MULTI_SZ
```

Action ID 17 is Modify Registry, 100 is IF, and 101 is End IF. The parser reconstructs each counted list, evaluates bounded `TRUE`, `FALSE`, identifiers, `!`, `&&`, `||`, and parentheses through the shared three-valued condition evaluator, and emits only install-time Set Value actions reached under `True`. False branches and uninstall actions are preserved in `LegacyActionCatalog` but do not become `RegistryWrites`; unsupported expressions remain unresolved. The 6.0.1.4 builder fixture contains 136 actions across five lists: two evaluation registry writes under `TRUE`, five commercial writes under `!TRUE`, and two uninstall delete actions. Only the two reachable installation writes are projected.

## Modern7 overlay

```text
Offset  Size  Field
------  ----  --------------------------------------------------------
0x00       8  Magic: E0 E1 E2 E3 E4 E5 E6 E7
0x08     0|1  Observed optional generation byte
+0x00       4  RuntimeSize, uint32
+0x04       *  Encoded irsetup.exe, RuntimeSize bytes
next        4  EntryCount, uint32
next        *  Repeated Modern7Entry records

Modern7Entry
+0x000    260  Name
+0x104      4  PackedSize, uint32
+0x108      4  Expanded CRC32, uint32
+0x10C      *  CompressedData, PackedSize bytes
```

Setup Factory 7.0.1 and one observed 7.0.3 runtime place `RuntimeSize` immediately after the eight-byte magic. Later media commonly inserts one byte first. The parser tests both candidate offsets and accepts one only when the declared runtime fits the file and its first decoded bytes are `MZ`; it does not depend on a release-number threshold or PE timestamp.

Only the first 2,000 bytes of the embedded runtime are transformed with XOR `0x07`. Bytes after that boundary are stored verbatim.

## Modern8Plus overlay

```text
Offset  Size  Field
------  ----  --------------------------------------------------------
0x00      16  Magic: E0 E0 E1 E1 E2 E2 E3 E3 E4 E4 E5 E5 E6 E6 E7 E7
0x10      10  Observed header fields, currently reserved
0x1A       8  RuntimeSize, int64
0x22       *  Encoded irsetup.exe, RuntimeSize bytes
next      4|8  EntryCount uint32, or optional LuaSize int64 followed by lua5.1.dll and EntryCount
next        *  Repeated Modern8PlusEntry records

Modern8PlusEntry
+0x000    264  Name
+0x108      8  PackedSize, int64
+0x110      4  Expanded CRC32, uint32
+0x114      4  Observed padding or reserved field
+0x118      *  CompressedData, PackedSize bytes
```

The current parser recognizes releases 8, 9, and 10 as one physical archive profile. `ParserVersionInfo.BuilderVersion` prefers trusted outer runtime identity and falls back to the embedded runtime when the outer launcher was customized; `EmbeddedRuntimeVersion` retains the inner value independently. Neither value controls archive dispatch.

The optional Lua runtime is distinguished from an entry count by validating the complete candidate size and following catalog. The low half of `LuaSize` otherwise resembles an implausibly large count.

## Compression records

Outer entries are independently compressed. The parser selects a decoder from bounded record framing and validates the expanded CRC32 after decoding.

```text
LZMA record
+0x00       5  LZMA properties
+0x05       8  Expected expanded size, int64
+0x0D       *  LZMA stream

LZMA2 record
+0x00       1  Property byte, observed 18
+0x01       8  Expected expanded size, int64
+0x09       *  LZMA2 stream

PKWARE record
+0x00       1  Literal coding flag, 0 or 1
+0x01       1  Dictionary size selector, 4 through 6
+0x02       *  PKWARE DCL implode bitstream ending in its explicit end marker
```

The PKWARE decoder rejects invalid literal and dictionary flags, truncated input, invalid back-references, missing end markers, and output beyond the configured bound. LZMA and LZMA2 use the shared bounded archive infrastructure.

## Installed-file tables

The outer catalog is a bootstrap catalog rather than the installed application file list. The decompressed `irsetup.dat` contains one generation-specific class table whose records describe installed destinations and the payload streams appended after the outer records. The common class header is:

```text
Offset  Size  Field
------  ----  --------------------------------------------------------
0x00       2  RecordCount, uint16
0x02       2  Sentinel, 0xFFFF
0x04       2  Class subtype
0x06       2  ClassNameLength, uint16
0x08       *  ClassName bytes: CFileInfo or CSetupFileData
next       *  generation-specific records
```

Setup Factory 4 uses `CFileInfo` records beginning with the physical packed size and CRC, followed by a variable-length source path, a split local timestamp, the expanded size, destination, title, components, and subtype-dependent compression fields. Setup Factory 5 and 6 move the source and destination strings before the sizes and use one-byte strings. Their fixed tails contain the packed size and CRC. Version 5 separates records with a two-byte marker; version 6 stores that marker as part of each record.

```text
Setup Factory 4 CFileInfo
+0x00       4  PackedSize, uint32
+0x04       4  Expanded CRC32, uint32
+0x08       *  SourcePath, variable-length string
next        8  year:uint16, month/day/hour/minute/second/pad:uint8
next       16  observed fields
next        4  ExpandedSize, uint32
next        *  destination, title, component, and subtype fields

Setup Factory 5/6 CFileInfo
+0x00     0|4  version 6 record prefix, absent in version 5
next        *  FullSourcePath, BaseName, SourceDirectory, suffix, RuntimeFolder
next        4  ExpandedSize, uint32
next        *  timestamp, destination, title, component, options, and flags
tail        4  PackedSize, uint32
tail+4      4  Expanded CRC32, uint32
tail+8     37  observed trailing fields
```

The string historically labeled `StorageClass` is the builder's run-time folder. Values such as `Archive\qml\QtQuick` describe a folder inside the run-time archive and do not prove that a record is external or absent. The first source string is the complete source path; the following source-directory string is retained independently and must not be prepended to the complete path.

Version 7 introduces `CSetupFileData`. Its five-byte prefix belongs to every record. Version 8 moves those five bytes to the table header and expands sizes and timestamps to 64 bits. The validated 8.1 and 9.0 builder media use ten destination-layout bytes, while 9.1, 9.2, and 9.5 use eleven. Version 10.2 adds a separate reserved byte immediately before the compression and attribute flags. The parser selects these layouts by validating the complete table rather than by trusting the outer product version.

```text
Setup Factory 7 CSetupFileData
+0x00       5  per-record observed prefix
next        *  source path, base name, source directory, suffix, runtime folder, description
next        4  ExpandedSize, uint32
next        4  ModificationTime, Unix seconds
next        *  destination, shortcut/file fields, conditions, components
tail        4  PackedSize, uint32
tail+4      4  Expanded CRC32, uint32

Setup Factory 8-10 CSetupFileData table
+0x00       5  table-wide observed prefix
next        *  repeated records

Setup Factory 8-10 record
+0x00       *  source path, base name, source directory, suffix, runtime folder, description
next        2  observed field
next        8  ExpandedSize, int64
next        1  OriginalAttributes
next        4  observed field
next        8  CreationTime, Unix seconds
next       16  observed fields
next        8  ModificationTime, Unix seconds
next       25  observed fields
next        *  DestinationPath
next    10|11  destination-layout fields; 11-byte route observed from Setup Factory 9.1
next        *  shortcut location, comment, description, arguments, and working directory
next        *  icon path and font registry name with bounded fixed fields
next      0|1  compression-prefix byte; 1-byte route observed in Setup Factory 10
next        3  compressed, use-original-attributes, forced-attributes flags
next        *  condition vector, condition, install type, package names, notes
tail        8  PackedSize, int64
tail+8      4  Expanded CRC32, uint32
tail+12     8  observed trailing fields
```

The parser retains the known shortcut, condition, install-type, package, notes, icon, font, attribute, and timestamp fields as catalog evidence. It does not claim that a non-empty conditional record executes in the branch without condition evaluation or VM evidence.

## Prerequisites and payload placement

Modern media can serialize `CDependencyFile` records before `CSetupFileData`. The record stores a source path twice, expanded and packed 64-bit sizes, a flag, and a build label. Its physical payload precedes the installed application payloads. The parser requires both paths to agree and every size to remain inside the installer before returning a `DependencyPayloads` entry.

```text
CDependencyFile record
+0x00       4  observed fields
next        *  SourcePath, one-byte string
next        8  ExpandedSize, int64
next        8  PackedSize, int64
next        *  repeated SourcePath, one-byte string
next        2  observed flag
next        *  build label, one-byte string
```

Normal media stores each installed-file stream sequentially in record order. The parser assigns offsets until a record no longer fits. If every record fits, `CanExtract` is true. If only a bounded prefix fits, `CanExtractPartial` is true and `SetupFactory.Payload.Truncated` identifies an incomplete or corrupt artifact; prefix records remain forensic evidence rather than a supported installer route. The first unavailable record terminates offset assignment, and later small records are never packed into leftover bytes speculatively.

Complete Bicom 9.5.3 media verifies the prerequisite framing followed by 750 Communicator or 766 gloCOM application payloads. Earlier short fixture copies ended at valid LZMA prefixes and initially resembled intentionally partial media; comparing the cached length with the server `Content-Length` established that those files were interrupted downloads. Do not infer web, optional, or component payload behavior from a structurally valid prefix when the declared streams exceed the file boundary.

## Metadata and system effects

Setup Factory 5 and 6 use the fixed product and built-in uninstall blocks described above. Modern `irsetup.dat` media exposes a bounded `CSessionVar` table. Each record stores a short name and value with generation-specific padding. The parser resolves only names present in the applicable generation, follows nested `%Variable%` references to a depth of 32, and rejects cycles or unknown variables.

`%ProductName%`, `%ProductVer%`, `%CompanyName%`, and `%AppFolder%` provide product metadata when they resolve. For Setup Factory 5 and 6, the enabled built-in uninstall route uses the stored `UniqueRegistryKey` and `ControlPanelDescription`. For modern media, the built-in route is accepted only when the compiled data contains the exact `%ProductName%%ProductVer%` key expression. Literal `Registry.SetValue` calls targeting `Software\Microsoft\Windows\CurrentVersion\Uninstall\<key>` provide more precise ARP evidence and take precedence over built-in defaults.

Registry writes outside the exact uninstall path remain registry or association evidence; they do not prove ARP visibility, ProductCode, or scope. An uninstall entry is visible only when it has a non-empty `DisplayName` and `SystemComponent` is not `1`. HKCU and HKLM entries remain separate, and mixed visible scopes do not collapse into one `Scope` or `ProductCode`.

Legacy and modern registry writes can also establish protocols and file extensions through the shared registry-association projector. Setup Factory 4 and 5 use their generation-specific typed `CRegistryData` records, Setup Factory 6 uses condition-resolved Modify Registry actions, and modern media uses literal Lua calls. The Lua string reader preserves ordinary Windows backslashes while decoding escaped quotes, backslashes, control escapes, and decimal byte escapes. Computed arguments, long-bracket strings, unsupported registry roots, runtime-dependent legacy conditions, external DLL calls, and dynamically assembled paths remain unresolved and produce `SetupFactory.Metadata.RegistryActionsUnresolved` with the skipped-call count. An unresolved call does not invalidate an independently proven built-in ProductCode or scope, but it can leave additional ARP entries, protocols, and file extensions incomplete.

Setup Factory 7 and earlier commonly stores project text in a Western Windows code page. Text decoding tries strict UTF-8 first and falls back to Windows-1252, which preserves legacy names such as `365dní`.

## Validation and bounds

Detection requires a valid PE overlay boundary, the generation signature at that exact boundary, a structurally valid generation-specific catalog, bounded entry counts, fixed-width names, valid size fields, and records that remain inside the file. Marker strings elsewhere in the PE are only analyzer hints.

The parser limits the catalog to 100,000 entries, one compressed file to 1 GiB, total extraction to 16 GiB, variable recursion to 32, and every output path to the requested destination. It validates record CRCs, declared decompressed sizes, truncation, duplicate and colliding paths, and decoder-specific termination before writing output.

Metadata analysis catalogs the installer once and decompresses only `irsetup.dat`. It does not expand the complete payload or return temporary paths that disappear after the call. Selective extraction seeks directly to catalog offsets and decodes only matched entries.

## Remaining gaps

Setup Factory 4 outer records, installed files, global settings, built-in uninstall identity, and registry writes are supported. Its decoded global format has no later product version, publisher, or default installation-directory fields, so those values remain unresolved unless another exact structured record establishes them. Package, shortcut, execution, INI, and text-file records are not yet projected as system effects.

Setup Factory 5 and 6 product and built-in uninstall metadata are supported. Version 5 `CRegistryData` and `CConditionData` framing and version 6 condition-resolved Modify Registry actions are also supported. Version 5 runtime-dependent condition outcomes, version 6 expressions outside the bounded Boolean grammar, and both generations' shortcut, execution, INI, text-file, package, and other action semantics remain partial, so those effects still require controlled builder evidence or VM validation when they affect ARP identity, associations, scope, or unattended behavior.

Setup Factory 3.1 multi-file media remains outside the single-file parser. It requires a separate parser for `IRDATA.IRD`, disk and language resources, and the generation-specific compressed builder payloads rather than another overlay profile.

Full Lua control flow, conditional actions, arbitrary external DLL effects, service operations, scheduled operations, standard shortcut action tables, and nested executable arguments are not yet interpreted. Modern per-file shortcut fields and literal registry calls are exposed as evidence, but a custom action can still supersede them. Use VM evidence when any of these affect manifest fields or installability.

The optional Modern8Plus Lua discriminator and reserved fields are based on stable observed layouts from 8.1.1008.0, 9.0.3.0, 9.0.4.0, 9.1.1.0, 9.2.0.0, 9.5.1.0, and 10.2.0.0 builder media. Future media that violates those invariants must be rejected and added as a new structural profile rather than forced through the current route.

## Representative fixtures

The focused tests cover Setup Factory 4.0, 5.0, 6.0.1.2, 6.0.1.4, 7.0.1, 7.0.3, 7.0.6.1, 8.1.1008.0, 9.0.3, 9.0.4, 9.1.1, 9.2.0, 9.5.1, and 10.2.0 media plus current package installers. Historical builders are cached outside Git under `Dumplings-TestFixtures`; malformed and decoder-edge fixtures use Pester's temporary directory.

## Implementation mapping

- `Modules/InstallerParsers/Libraries/Installers/SetupFactory.psm1`
- `Modules/InstallerParsers/Libraries/Installers/SetupFactoryFormatCatalog.psd1`
- `Modules/InstallerParsers/Assets/Source/SetupFactory/PkwareBlast.cs`
- `Modules/PackageModule/Libraries/Installers/SetupFactory.psm1`

## Source references

- [Indigo Rose Setup Factory](https://www.indigorose.com/products/setup-factory/)
- [Setup Factory command-line options](https://www.indigorose.com/docs/suf/program_reference_command_line_options.htm)
- [Setup Factory release notes](https://www.indigorose.com/customers/release_notes/suf-release-notes.html)
- [Internet Archive captures of the official Setup Factory trial](https://web.archive.org/web/*/http://www.indigorose.com/files/setup-factory-trial.exe)
- [sfextract](https://github.com/CybercentreCanada/sfextract)
- [SFUnpacker](https://github.com/Puyodead1/SFUnpacker)
- [defactory](https://codeberg.org/CYBERDEV/defactory)
- [zlib blast](https://github.com/madler/zlib/tree/develop/contrib/blast)
