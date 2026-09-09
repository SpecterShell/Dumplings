# CreateInstall internals

This reference describes CreateInstall's compiled installer structures and generated runtime behavior. Use the [CreateInstall workflow](../../families/createinstall/workflow.md) for package analysis and manifest authoring.

Read [binary notation](../../parser-development/binary-notation.md), [parser contracts](../../parser-development/contracts.md), and [performance guidance](../../parser-development/performance.md) before changing the parser.

## Product boundary

CreateInstall 5.9.0 through 8.11.2 use a Win32 PE launcher, a Gentee 4 compiled project, and an optional GEA archive. The archived `ci2000.exe`, `setupgen.exe`, and `sgpro.exe` artifacts belong to the earlier Gentee Installer product. They contain neither the verified GE4 launcher contract nor a GEA payload and are deliberately rejected instead of being assigned a speculative CreateInstall route.

Builder release labels are regression evidence. Runtime dispatch uses independent structural profiles from `CreateInstallFormatCatalog.psd1`: GE program version, GEA major version, Add/Remove routine structure, install-group routine signature, and operation-list shape.

## Container stack

```text
Win32 PE setup
+-- PE headers and resources
+-- .gentee section
|   +-- Gentee runtime image                         RuntimeSize bytes
|   `-- compiled GE project                         stored or LZGE packed
+-- optional Authenticode certificate table
`-- optional GEA archive
    +-- fixed header and volume metadata
    +-- compressed catalog
    +-- ordinary file block region
    `-- moved file block region
```

The `.gentee` program and GEA archive evolve independently. A project with no packaged files can contain a valid compiled GE program and no GEA archive.

## Gentee launcher header

The parser searches only a bounded prefix for one `Gentee Launcher\0` signature and verifies that the header's recorded file offset points back to that signature. `linkhead` is packed, so multibyte fields are unaligned.

```text
Base               Offset  Size  Field
-----------------  ------  ----  -----------------------------------------------
launcher signature 0x00    15    ASCII `Gentee Launcher\0`
launcher signature 0x1A     1    Packed-program flag
launcher signature 0x1D     4    RuntimeSize, uint32 LE
launcher signature 0x21     4    StoredProgramSize, uint32 LE
launcher signature 0x2D     4    HeaderFileOffset, uint32 LE
```

The compiled program begins at `.gentee.RawOffset + RuntimeSize`. When the packed flag is set, the range starts with `ExpandedSize:uint32 LE` followed by one LZGE stream. All ranges must remain inside the section and under the configured GE program limit.

## GE 4 program

```text
Base       Offset  Size      Field
---------  ------  --------  ---------------------------------------------
GE program 0x00       4      Magic: 47 45 00 00 (`GE\0\0` as uint32 0x4547)
GE program 0x0C       4      HeaderSize, uint32 LE
GE program 0x10       4      ProgramSize, uint32 LE
GE program 0x14       1      MajorVersion, currently 4
GE program 0x15       1      MinorVersion
GE program HeaderSize ...    serialized object records
```

Each object record is `[Type:byte][Flags:uint32 LE][RecordSize:BWD][optional UTF-8 NUL name][payload]`. BWD is Gentee's bounded variable-width unsigned integer: leads 0–187 are the value, 188–253 mean `255 × (lead − 188) + next_byte`, 254 reads a following uint16, and 255 reads a following uint32. The multiplier is 255, matching the reference `load_bwd` code rather than its own comment, which claims 256. Record flags carry `GHCOM_NAME` (0x0001) and `GHCOM_PACK` (0x0002); the reference loader reads the record size as raw uint32 when `GHCOM_PACK` is clear, but CreateInstall's compiler always sets `GHCOM_PACK`, so every observed record size is BWD-encoded. The leading resource object has no VM object ID; later objects receive sequential IDs beginning at 1024 (`KERNEL_COUNT`). Relevant object types are bytecode functions, global variables, and the resource record. The parser verifies the GE header CRC the same way the reference `ge_load` does: Gentee `crc()` covers the half-open range `[12, ProgramSize)` with seed 0xFFFFFFFF and no final inversion, so the standard CRC32 of that range XORed with 0xFFFFFFFF must equal the stored header CRC.

Bytecode functions begin with a return-variable descriptor, parameter count and descriptors, grouped local variables, and commands. The parser decodes only source-grounded command operand forms and caches the result per function. Kernel command identifiers and the operand-width table are byte-identical to the reference `cmdlist` shift table (218 entries from `CNop`): shifts 7 (`SH1_3`) and 11 (`SH2_3`) read two BWD operands; shifts 3 (`SHN1_2`), 5 (`SH0_2`), and 8 (`SH1_2`) read one. Literal-prefixed opcodes are `CByload` 25 (ubyte), `CShload` 26 (ushort), `CDwload` 27 (uint), `CCmdload` 28 and `CPtrglobal` 85 (BWD ID), `CResload` 29 (BWD resource ID), `CQwload` 30 (ulong), `CDwsload` 31 (BWD count then that many 4-byte entries), `CDatasize` 34 (BWD length then raw bytes), and `CAsm` 93 (BWD count then 4 × count bytes). Object IDs at or above 1024 inside bytecode are direct calls to compiled functions. Function names and object IDs may be stripped or change during linking, so handlers are identified from parameter counts, literal signatures, call relationships, and validated list shapes.

Imported native functions retain stronger identity than linked GE routines. An object type 8 import record contains a NUL-terminated UTF-8 library name and, when `GHIMP_LINK` (0x0100) is set, a `LinkedSize:uint32 LE` followed by that many embedded library bytes. An object type 4 external-function record begins with the return and parameter variable descriptors; when `GHEX_IMPORT` (0x080000) is set, it ends with `ImportObjectId:BWD` and the original NUL-terminated UTF-8 function name. The parser validates these record boundaries and indexes the library/function relationship but never loads or executes an embedded DLL. This evidence distinguishes operations such as scheduled-task creation, INI mutation, and service control after ordinary GE function names have been stripped.

## Project data lists

CreateInstall's generator serializes project settings into one initialized Gentee `buf`, conventionally called `g_list`. Each referenced table uses this framing:

```text
+----------------------+ table offset
| RowCount             | uint32 LE
+----------------------+
| Field 0              | UTF-8, NUL terminated
+----------------------+
| ...                  | fixed field count for this route
+----------------------+
| final field          | UTF-8, NUL terminated
+----------------------+
| next row             | same fixed field count
+----------------------+
```

`MAINVAR` is a two-field name/value table. Detection requires the source-consumed keys `progname`, `ver`, `compname`, `setuppath`, `uninstexe`, and `silentpar`. Other tables are accepted only at offsets referenced by bytecode and only when their field count and value domains match one source-backed operation route.

Deterministic `#name#` macros are expanded recursively with a depth limit. Known shell-folder macros become manifest-safe environment paths. Unknown macros remain explicit unresolved evidence; arbitrary Gentee expressions are not executed.

## Operation routes

The current structural catalog contains these generated operations:

| Route | Physical discriminator | Decoded behavior |
| --- | --- | --- |
| `Direct5` | five-parameter `unpackgroup` target | group, destination, overwrite mode, condition, wildcard |
| `Extended6` | six-parameter `unpackgroupex` target | Direct5 plus a per-file option-list offset |
| `RegistryList5` | five-parameter `regsetsex` wrapper and five-field rows | hive, subkey, name/type/value/condition rows, registry view, outer condition |
| `ExtensionList2` | extension command and two-field variable rows | extension and ProgID association registry writes |
| `ShortcutDirect10` | generator literals preceding `shortcutex` | shortcut, target, arguments, comment, icon, work directory, show mode, condition |
| `ShortcutList10` | one-parameter `shlist` target and ten-field rows | shortcut and target path/name pairs, arguments, icon, work path/name, condition, ignored configured comment |
| `RunDirect8` | six-parameter `run` target fed from eight project fields | executable, arguments, working directory, wait, condition |
| `RunMsi11` | six-parameter `runmsiex` target and source-defined MSI template | action, quiet/passive, no-restart, log, wait, interface, nested MSI path, condition |
| `EnvironmentSetList5` | one-parameter `globsets` target with the literal `Environment` registry route and five-field rows | variable name, value, machine/user bit mask, condition, comment |
| `EnvironmentAppend4` | four-parameter `globappend` or `globdel` target with shared `Environment` and `g_append` literals | variable name, path/value, machine/user bit mask, condition; operation remains `AppendOrRemove` because these compiled routes are structurally indistinguishable |
| `VisualCppCheck6` | six-parameter routine containing the source-defined MSI product and `RuntimeMinimum` probes | architecture, eight Visual C++ generation flags, AND/OR mode, result macro, failure message, condition |
| `ServiceCreate8` | seven-parameter wrapper that calls the six-parameter service core containing `System\CurrentControlSet\Services` | binary path/name pair, service name, display name, description, start type, run-after-create flag, condition |
| `ServiceStart1`, `ServiceStop1`, `ServiceDelete1` | one-parameter helpers calling exact `StartServiceW`, `ControlService`, or `DeleteService` imports from zero-parameter generated event functions | service name, operation, and guarding condition |
| `RegistrationList6` | one-parameter list handlers identified by the source literals for Fonts, `regsvr32`, or `RegAsm` | font registration, COM/ActiveX/type-library registration, or .NET assembly registration with conditions |
| `ScheduledTaskCreate13`, `ScheduledTaskDelete2` | eleven- or two-parameter routines importing `newtask` or `deltask` from `citools.dll` | task identity, executable, arguments, working directory, trigger, schedule fields, condition, or deletion |
| `CopyDirect7`, `CopyList7` | five-parameter `cicopy` literal fingerprint or one-parameter seven-field list route | source and destination paths, search or overwrite behavior, and condition |
| `DownloadList8` | three-parameter `downloadfilesex` fingerprint and an eight-field list | resolved URL, destination, overwrite behavior, result macro, TLS-support flag, and condition |
| `Decompress7z8`, `DecompressCab7`, `DecompressZip6` | source-specific routine literals and parameter counts | nested archive path, destination, overwrite or option flags, include/exclude wildcards, and condition |
| `IniSet6`, `IniDelete6` | five-parameter routine distinguished by `GetPrivateProfileStringW` and `WritePrivateProfileStringW` imports | INI path, section, key/value or deletion, encoding/BOM flags, and condition |

Operations whose condition is false are omitted. Unknown conditions are retained as conditional evidence. Deterministic custom registry writes run after the generated setup body and therefore replace built-in values with the same hive, view, key, and name when reconstructing final ARP state. Visual C++ package identifiers are advisory mappings from the checked generation and architecture; the parser does not mutate manifest dependencies because the check does not encode a complete package-version constraint.

Command availability is capability-based rather than inferred from the setup version. Across the cached official builder media, copy, download, cabinet, INI set/format, service, directory, delete, rename, attribute, and replace modules are present from 5.9.0; scheduled-task, 7z, and ZIP modules appear from 5.19.1; INI line insertion appears from 6.0.0; text insertion and deletion appear from 6.2.1; and INI-key deletion appears from 6.4.0. These ranges document observed source availability only. The parser still requires the compiled routine structure before reporting an operation.

## Condition expressions

The source-backed `ifcondition` routine accepts an empty string, an optional leading `!`, and one of two expression routes:

```text
empty       -> true
#name#      -> read `name` from defmacro; true when non-empty and not `0` or `false`
name        -> same macro lookup after trimming optional `#` delimiters
@function   -> resolve `function` with getid and invoke it with no arguments
!expression -> Boolean negation of either route
```

The parser resolves the macro route when `MAINVAR` or a known deterministic folder macro supplies the value. It does not execute `@function` bytecode. Every unresolved condition becomes one `GenteeExpressions` item with the guarded operation, call site, affected metadata fields, operation context, and variable evidence.

For an `@function`, the parser resolves an exact named function when its name survived linking. `ReferencedFunction` contains its GE object ID, parameter count, record bounds, literal strings, directly called GE functions, and at most 256 decoded commands. A longer function sets `CommandsTruncated` instead of expanding an unbounded result. Identifier-like string literals are reported as candidate variables because generated predicates commonly pass names such as `oswindows`, `os64`, or `checkret` to macro-access helpers. The parser does not claim that every identifier literal is a variable.

`Variables` distinguishes compiled `ProjectVariable` values, deterministic `KnownMacro` values, and `RuntimeOrUnknown` names. It follows nested `#name#` references in project values so an agent receives the relevant value chain. A missing runtime value remains unknown. It must not be interpreted as an empty or false value.

This evidence is intended for bounded manual analysis. Simple source-grounded comparisons can be decided from the function commands, literals, callees, and known values. Conditions that depend on OS probes, previous operations, user choices, external DLLs, registry or filesystem state, or unsupported opcodes still require both-branch preservation or controlled VM validation.

## Add/Remove Program routes

The Add/Remove routine is classified independently from archive version:

| Route | Observed builders | Structural behavior |
| --- | --- | --- |
| `Legacy3` | 5.9.0 through 6.3.3 | `addremove` takes key/display name, icon path, and icon file; it lacks `InstallLocation`, policy, and size writes. |
| `Scoped4` | 6.4.0 through 7.0.19 | `addremoveex` adds the current-user Boolean and `InstallLocation`. |
| `Policy4` | 7.0.26 through 7.1.3 | `addremoveex` also writes `NoModify` and `NoRepair`. |
| `Extended5` | 7.1.7 through 8.11.2 | `addremoveext` adds the estimated-size argument and all later values. |

Dead-code elimination removes the entire built-in routine when a project disables Add/Remove Programs. That is a valid no-built-in-ARP state. The parser combines built-in and deterministic custom uninstall-key writes in execution order, excludes `SystemComponent=1` or nameless records from visible Apps & Features evidence, and emits one ProductCode only when exactly one visible key remains.

A live install/uninstall cycle of a generated Extended5 project confirmed the parser value-for-value: one 32-bit-view `HKLM` key named after the program, exactly `UninstallString`, `DisplayName`, `DisplayIcon`, `DisplayVersion`, `InstallLocation`, `Publisher`, `NoModify`, and `NoRepair` (no `EstimatedSize` when the payload rounds below one kilobyte), a quoted `UninstallString`, and an install path that resolves `#progfiles#` to `%ProgramFiles(x86)%`. The generated `uninstall.ini` log independently enumerated the same registry value set, and the generated uninstaller binary itself re-parses as a CreateInstall setup with no GEA archive. The installer's `addremoveext` estimated-size argument is compiled into the setup: `1` tells the runtime to use the archive summary size in kibibytes, another positive integer is a literal kibibyte value (Balabolka passes `56327`), and an empty or zero value writes no registry value. The `lunname` shortcut macro resolves at runtime from installer language strings (observed `Uninstall.lnk`), so it stays flagged as unresolved static evidence. Running a trial-built setup with `-s` still shows the full dialog sequence, consistent with `silentpar`-derived switch reporting.

## GEA archive

The parser locates aligned `GEA\0` candidates and accepts one only after the header, catalog, block ranges, counts, and logical file boundaries validate.

```text
Base       Offset  Size  Field
---------  ------  ----  ---------------------------------------------
GEA header 0x00       4  Magic: 47 45 41 00 (`GEA\0`)
GEA header 0x04       2  VolumeNumber, uint16 LE
GEA header 0x06       4  UniqueID, uint32 LE
GEA header 0x0A       1  MajorVersion
GEA header 0x0B       1  MinorVersion
GEA header 0x14       4  Flags, uint32 LE
GEA header 0x18       2  VolumeCount, uint16 LE
GEA header 0x1A       4  HeaderSize, uint32 LE
GEA header 0x1E       8  SummarySize, int64 LE
GEA header 0x26       4  InfoSize, uint32 LE
GEA header 0x2A       8  ArchiveFileSize, int64 LE
GEA header 0x32       8  VolumeSize, int64 LE
GEA header 0x3A       8  LastVolumeSize, int64 LE
GEA header 0x42       4  MovedSize, uint32 LE
GEA header 0x46       3  memory, block, and solid multipliers
```

GEA1 file records use 32-bit little-endian expanded and compressed sizes. GEA2 uses 64-bit sizes. Both carry flags, FILETIME, CRC32, group ID, folder and name strings, and one or more block descriptors.

```text
+----------------------+ block start
| Order                | byte
+----------------------+
| CompressedSize       | uint32 LE in GEA1, uint64 LE in GEA2
+----------------------+
| CompressedData       | CompressedSize bytes
+----------------------+
```

The order byte contains the protection bit (0x80), a compression method in the high nibble after the protection bit (0 store, 1 LZGE, 2 PPMd), and an order-minus-one low nibble; the reference `geadfile.g` masks the protection bit, shifts the method out of the high nibble, and adds one to the low nibble. A block keeps the preceding LZGE history only when the method is LZGE and the decoded order is exactly one; store and higher-order LZGE reset it, and the PPMd model persists across the archive with order-one records continuing the retained model in a fresh range stream. Block output size is `min(blocksize, remaining file size)` for compressed methods and the full declared size for store. Expanded size and Gentee's unfinalized CRC32 (standard CRC32 XOR 0xFFFFFFFF; the reference seeds 0xFFFFFFFF and never inverts) are checked for every selected entry. All 24 cached official builder installers from 5.19.1 through 8.11.2 expand completely with every catalog CRC passing across GEA1 and GEA2 profiles.

The GEA reading in the parser matches the reference `gead.open` field for field: the 73-byte packed `geavolume` + `geahead` prefix, the volume pattern string, the `GEAH_PASSWORD` count plus password CRC array, `GEAH_COMPRESS` LZGE-coded file descriptions with stateful inheritance of attributes, group, password, and folder between descriptors, and the moved region stored physically before ordinary data while forming one logical compressed stream.

For spanned media, every companion begins with a ten-byte `[GEA\0][VolumeNumber:uint16 LE][UniqueID:uint32 LE]` header. The main header pattern contains exactly one supported printf-style `%i`, `%d`, or `%u` placeholder; CreateInstall passes the one-based display number, while the stored companion `VolumeNumber` remains zero-based. A logical data range is translated across ordinary main-file data, each companion body in ascending volume order, and finally `MovedSize` bytes stored immediately after the main variable header. Companion magic, number, unique ID, declared size, path containment, and total logical length are validated before extraction. Missing companions leave the file catalog available and set `AllVolumesAvailable=false`; a present mismatched or truncated companion is an integrity failure. The parser opens companion streams only for slices that cross them and never concatenates the complete volume set in memory.

Password-protected data is not decrypted. Unknown compression methods remain non-expandable diagnostics.

## Installed-file and payload analysis

The physical GEA catalog is not the installed file list. The parser applies compiled group IDs, wildcards, destinations, conditions, and per-file options to derive `InstalledFiles`. Selected application paths are materialized into a temporary directory only when PE architecture or dependency analysis requires file paths. Archive-relative paths are matched exactly after safe normalization, so duplicate basenames in different folders cannot select the wrong payload.

The parser opens the archive once for block enumeration and reuses bounded streams during selected extraction. PPMd solid state is replayed only from the nearest reset rather than from the beginning of a large archive. Historical CreateInstall 5.9 GEA1 and modern 8.x GEA2 builders exercise both width profiles.

## Detection invariants

Full installer detection requires all of the following:

- A valid PE with exactly one `.gentee` section.
- One bounded `Gentee Launcher\0` header whose self-offset and section ranges agree.
- A valid GE major version 4 program with object records ending at `ProgramSize`.
- One referenced, structurally valid `MAINVAR` table.

A GEA archive is optional for installer identity but mandatory for extraction. Standalone GEA data can be inspected through archive internals and synthetic tests, but it is not accepted as a CreateInstall setup executable.

## Remaining unsupported behavior

Arbitrary Gentee `@function` expressions are exposed with their bounded function and variable evidence but are not executed. The shared four-parameter `globappend` and `globdel` structure is reported as `AppendOrRemove` until a stable source-backed discriminator is established. INI formatting, insert/delete text transforms, generated-file operations outside the implemented copy routes, indirect calls whose operands cannot be reduced to source-backed literal/list forms, runtime DLL side effects, and password-protected payloads remain unresolved. Nested 7z, cabinet, and ZIP operations are reported, but their inner catalogs are not recursively projected into the installed-file list.

The pre-CreateInstall Gentee Installer product is a separate future parser family, not an uncovered CreateInstall release.

## Implementation mapping

- `Modules/PackageModule/Libraries/Installers/CreateInstall.psm1`
- `Modules/PackageModule/Libraries/Installers/CreateInstallFormatCatalog.psd1`
- `Modules/PackageModule/Tests/Installers/CreateInstall.Tests.ps1`

## Representative evidence

Regression coverage includes official builder installers from 5.9.0 through 8.11.2, Balabolka's PPMd payload, custom ARP writes, and x86 Visual C++ 2019 prerequisite check, a generated `runmsiex` route, a generated no-payload project, synthetic stripped-symbol system-operation calls and list records, a stored block split across a main file and companion volume, mismatched companion identity, malformed synthetic GEA records, and rejected pre-CreateInstall Gentee Installer artifacts. Proprietary binaries remain in the external fixture cache.

## Source references

- [CreateInstall product and download history](https://www.createinstall.com/download-free-trial.html)
- [CreateInstall release history](https://www.createinstall.com/history.html)
- [CreateInstall help and Gentee scripting overview](https://www.createinstall.com/help/index.html)
- [Gentee GEA source index](https://www.gentee.com/source/src/projects/gea/index.htm)
- Local Gentee 3.6.1 source checkout (`gea.g`, `gead.g`, `geadfile.g`, `geacommon.g`, LZGE and Huffman C sources, `geload.c`, `cmdlist.c`, `launcher.c`, and `lib/registry/registry.g`) used to verify the parser against the reference implementation rather than against observed output alone.
