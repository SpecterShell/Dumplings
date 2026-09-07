# Astrum InstallWizard internals

This reference describes the compiled Astrum runtime and wire formats consumed by Dumplings. Use the [Astrum InstallWizard workflow](../../families/astrum-installwizard/workflow.md) for package analysis and manifest authoring.

Read [binary notation](../../parser-development/binary-notation.md), [parser contracts](../../parser-development/contracts.md), and [performance guidance](../../parser-development/performance.md) before changing the parser.

## Builder and runtime model

Astrum InstallWizard Builder stores authoring state in an `.ai2` XML project, but a distributed setup contains a native runtime plus compiled binary tables rather than that XML document. The compiler serializes registry trees, shortcuts, INI and text edits, file operations, variables, interactive actions, package identity, option state, installation-item groups, and payload records into the overlay. The runtime consumes those structures directly.

The installed-state model has three layers. Configuration records describe intended operations and conditions. File records provide physical bytes and destination expressions. Runtime state supplies values that cannot be known statically, including registry- or INI-backed variables, detected files, dialog input, timers, external DLL results, and the actual elevation context. A parser may resolve the first two layers, but it must not replace the third with values from the analysis host.

Astrum's protected configuration is reversible obfuscation with integrity bytes, not a secret-bearing encryption boundary. Decoding it does not execute project actions or deserialize an object graph. The parser reads primitive integers and Windows-1252 strings from a bounded byte array and traverses each compiled table under explicit count and depth limits.

## Format coverage and evidence

Astrum InstallWizard 1.x and 2.x append a compiled configuration, installation-item table, file records, and a compact footer to a native PE setup runtime. This document records only fields consumed or validated by Dumplings. Unknown fixed-tail fields and descriptor words retain observed names because assigning semantics without controlled evidence would make parser output unsafe.

Normal single-file media is verified from archived Astrum 1.80 through 2.29.50. Tiny, tiny-verbose, and spanned routes have controlled 2.29.50 fixtures. The parser distinguishes the physical `Legacy1`, `Early2`, and `Modern2` configuration profiles; these names describe record layouts and do not claim an exact builder release when the setup runtime does not expose one.

`AstrumInstallWizardFormatCatalog.psd1` stores the two overlay descriptors and three configuration profiles independently from parser code. Footer length selects `astrum-1` or `astrum-2`; validated fields from that descriptor select `Legacy1`, `Early2`, or `Modern2`. Each descriptor owns its footer offsets, accepted trailer routes, file-record width, condition and registry framing, optional tables, container capabilities, process success codes, and validation invariants. Configuration profiles own identity framing, unattended-installation policy, and sparse option offsets. This keeps observed wire layouts auditable and prevents application-version strings from selecting a parser route.

Archived download-page and installer captures establish this observed runtime sequence: `Legacy1` in 1.80, 1.83, 1.84, 1.90, 1.91.02, 1.91.51, 1.94, 1.95.4, and 1.95.5; `Early2` in 2.01.50, 2.02.50, and 2.04.20; and `Modern2` in 2.21.20, 2.22.30, 2.23.20, 2.24.00, 2.29.00, and 2.29.50. Each builder installer's compiled configuration carries its own application version, and those self-identities are the primary anchoring evidence; 1.83 and 1.91.02 are absent from the published version history, which jumps from 1.82 to 1.84 and from 1.91 to 1.91i, so they are unlisted internal releases rather than history typos. This leaves the `Early2` to `Modern2` transition somewhere after 2.04.20 and no later than 2.21.20. The 1.95.5 capture is the first available 1.x fixture with the dual trailer magic; this observation does not claim that 1.95.5 introduced it.

Evidence labels in this reference have specific meanings. An observed field is stable across bounded artifacts but does not yet have a proved runtime meaning. A controlled field changed with one builder option while other project inputs stayed fixed. A decompiled behavior follows a bounded runtime code path. A VM-validated behavior was compared with installed files, registry state, and process exit code after restoring the checkpoint. Published documentation proves intended behavior but does not override contradictory compiled or live evidence.

| Statement type | Appropriate use | Insufficient use |
| --- | --- | --- |
| Structural invariant | Parser dispatch, range validation, and extraction | Exact builder release when the file does not record one |
| Controlled builder diff | Assigning a field or option meaning | Assuming the same offset in another configuration profile |
| Runtime decompilation | Command-line and control-flow behavior for that runtime route | Proving target-machine state without executing the route |
| VM comparison | ARP values, installed paths, exit codes, and elevation outcome for that fixture | Defining an untested generation-wide binary layout |
| Published builder help | Intended switches, project semantics, and UI choices | Replacing contradictory artifact evidence |

## Structural dispatch

Format selection starts at the logical end of the PE rather than from application-owned version resources. The parser removes a validated Authenticode envelope when present, tests the dual-magic and legacy suffix routes, follows the absolute footer pointer, and accepts only a catalog profile whose footer length, self pointer, configuration, installation-item table, file count, and exact catalog endpoint agree.

```text
candidate PE
+-- optional tiny wrapper
|   `-- bounded GZip member must expand to another complete candidate PE
`-- ordinary media
    +-- logical ending before optional certificate
    +-- suffix route: LegacyNoMagic or DualMagic
    +-- footer length: 0xE8 or 0xEC
    +-- twice-validated configuration
    +-- exact installation-item table
    `-- complete file-record chain ending at footer
```

Footer length selects the physical `astrum-1` or `astrum-2` descriptor. Configuration framing then selects `Legacy1`, `Early2`, or `Modern2`. These decisions are compositional: a late 1.x setup can have the dual trailer without becoming a 2.x file format, and an application version resembling a builder release cannot change either route.

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
+-- optional observed 2.x post-interactive table
+-- fixed package identity and destination fields
+-- prior-installation, application-version, icon, and language strings
+-- generation-specific uninstaller and language fields
`-- sparse fixed option block
```

A registry key stores a value count and repeated values, then a child count and repeated child keys. In 1.x each value contains a name, data, type, and uninstall behavior, while each child contains only its name and recursive key body. In 2.x values and children also carry optional conditions, and child keys carry uninstall behavior. Known type codes are `0=REG_BINARY`, `1=REG_DWORD`, `2=REG_SZ`, `3=REG_MULTI_SZ`, and `4=REG_EXPAND_SZ`.

Conditions begin with a big-endian operating-system mask, retained under both `Kind` and `OperatingSystemMask` for compatibility. Zero has no body. Other masks contain a bounded term count followed by left string, operator word, and right string for each term. Builder ordering establishes condition operators `0=Equals`, `1=Not equal`, `2=Greater than`, `3=Less than`, `4=Greater than or equal`, `5=Less than or equal`, and `6=Contains / Binary and`; the final operator performs case-insensitive containment for text and bitwise intersection for numbers. The parser exposes `OperatorName` but does not claim a runtime truth value without an environment.

The shortcut, INI, text, and advanced-file tables contain a generation-specific trailing field. In 1.x that UInt32 is retained as `ObservedOperationTail` without assigning condition semantics; in 2.x it selects the optional condition record and `ObservedOperationTail` is null. The advanced-interactive record is different: 1.x ends immediately after `ExecuteCount`, while 2.x appends flags, a custom message, and the normal condition envelope. Reading a legacy interactive record as the 2.x form consumes the first bytes of `ApplicationName`. Astrum 1.x has five post-shortcut system tables and omits one additional post-interactive table present in 2.x. That table is exposed conservatively as `PostInteractiveRecords`; controlled `<cs-advanced-resource>` projects do not populate it, so the parser does not claim that it describes builder Resource files. Builder runtime enum tables and compiled records establish text, file, interactive, timing, and condition names. Text opcodes `0..7` follow the help order from “Add to beginning of file” through “Replace text”; file opcodes `0..5` are Copy, Delete, Move, Rename, Make directory, and Remove directory; interactive opcodes `0..9` are Execute program, Open document, Open web site, Explore folder, Show message, End installation, Execute program and wait, Ask yes/no question, Show text box, and Assign variable value. This internal ordering differs from the builder UI, which displays “Execute program and wait” second. Astrum 1.x supports only interactive opcodes `0..7`. Timing opcodes `0..13` run from program startup through shutdown. The parser exposes source labels separately from numeric codes and treats execute opcodes `0` and `6` as `ExecutedPayloads`; BreakAlube's opcode-6 `CDM20802_Setup.exe` action is the real-media regression for the wait route. Unknown or generation-invalid enum values remain unlabeled and produce `Astrum.Operation.UnknownCode`. File associations are compiled into the registry tree and are projected from those literal writes rather than a separate association table.

Three configuration profiles are dispatched from structure. `Legacy1` starts fixed metadata directly with one application name and one company name, omits the advanced-resource table and default-language field, and stores generated-uninstaller name and command at the end of its fixed string sequence. `Early2` adds 2.x conditions and the advanced-resource table but retains that older fixed identity layout. `Modern2`, first represented by the archived 2.21.20 fixture, prefixes fixed metadata with a bounded runtime/encoding word and duplicate internal application/company names, then stores install icon, language strings, default language, generated-uninstaller path, and command as separate fields. For an `astrum-2` footer, the next big-endian word at the fixed-metadata boundary selects `Modern2` only when it is within the catalog's bounded runtime-word range; otherwise the parser takes the `Early2` route. This word is a wire-layout discriminator, not a builder-version number. The exact release that first emitted `Modern2` is not inferred from the gap between tested builders.

The following option offsets apply only to `Modern2` and are relative to the byte immediately after the generated-uninstaller command. Multi-byte requirement values are big-endian. The Java requirement is a variable-length NUL-terminated Windows-1252 string; `JavaEnd` means the first byte after that terminator. Fields following it must use this dynamic anchor because a selected Java version shifts every later option. The offsets were isolated through single-option controlled 2.29.50 builds. `Legacy1` and `Early2` option tails remain bounded opaque evidence rather than being decoded with offsets from a different structure.

```text
Offset  Size  Byte order  Meaning
------  ----  ----------  ---------------------------------------------
0x48       4  BE          minimum CPU speed in MHz
0x4C       4  BE          CPU manufacturer code
0x50       4  BE          combined CPU vendor mask
0x54       4  BE          CPU feature flags
0x58       4  BE          minimum memory in MiB
0x5C       4  BE          Windows-family mask: Windows 95=1, Windows 98=2, NT=4, Windows ME=8
0x60       4  BE          minimum Windows 9x build
0x64       4  BE          minimum Windows NT major version
0x68       4  BE          minimum Windows NT minor version
0x6C       4  BE          minimum Windows NT service pack
0x70       2  BE          minimum DirectX major version
0x72       2  BE          minimum DirectX minor version
0x74       4  BE          minimum display width
0x78       4  BE          minimum display height
0x7C       4  BE          minimum display bits per pixel
0x80       4  BE          minimum .NET Framework selector
0x84     var  Windows-1252 minimum Java version plus NUL terminator
JavaEnd+0x0C  4  BE       wave-playback requirement
JavaEnd+0x10  4  BE       MIDI-playback requirement
JavaEnd+0x14  4  BE       joystick requirement
JavaEnd+0x18  4  BE       User Information field flags
JavaEnd+0x68  4  BE       silent-by-default flag
JavaEnd+0x6C  4  BE       no-generated-uninstaller flag
JavaEnd+0xA9  4  BE       x64-compliance flag
JavaEnd+0xAD  4  BE       require-administrator runtime flag
end-29     1  byte        direct license-approval flag
end-25     1  byte        prohibit-silent-without-license flag
```

The .NET selector maps `1..8` to `1.0`, `1.1`, `2.0`, `3.0`, `3.5`, `3.5 SP1`, `4.0 Client`, and `4.0 Full`. The NT major/minor pairs observed from builder choices map `4.0` through `6.1` to Windows NT 4.0 through Windows 7 / Server 2008 R2. The final two license flags are relative to the end because optional auto-update strings make the intervening tail variable-length. Unassigned option bytes remain opaque evidence. The standard selected dialogs are identified in the bounded pre-catalog resource region by exact compiled resource records such as `<LangID=1>User information</LangID=1>` and `<LangID=1>License agreement</LangID=1>`; arbitrary product strings are not accepted as dialog evidence.

## Runtime phases and operation timing

Astrum actions are organized by timing codes rather than physical table order alone. The runtime can run an operation at program startup, after each standard wizard page, after installation, or during shutdown. A file or interactive record therefore does not prove that its side effect occurs in every installation: its condition, selected dialogs, earlier variable assignments, and termination actions can change reachability.

The ordinary execution path reads requirements and variables, selects installation-item groups, presents or skips configured dialogs, copies eligible file records, applies registry and file operations, runs post-install interactive actions, then creates the configured uninstaller and completes shutdown actions. Resource-directory files are available before the ordinary copy phase, which is why a nested prerequisite can execute from `<ResourceDir>` before application payload installation.

Interactive action `0` executes a program and action `6` executes a program and waits. The physical payload can be a catalog record, a resource file, or an external path. Static analysis reports both as nested execution evidence but does not assume the child accepts Astrum's `/silent` switch. “End installation,” prompts, variable assignment, and external DLL-backed values can alter later control flow and remain VM-validation boundaries when their inputs are not literal.

## Resource files

Builder Resource files are catalogued as normal file records whose destination starts with `<ResourceDir>\`. The setup decompresses these records before the ordinary installation phase, allowing interactive actions to execute prerequisites or open documents from the resource directory. `PayloadCatalog` retains every record, `ResourceFiles` selects these early payloads, and default extraction places them under `_destinations\ResourceDir`. The builder also adds internal records such as `<ResourceDir>\installer\*_tmp.exe`; callers must distinguish these from a user-authored resource by path and installation-item evidence. This route is separate from the additional observed 2.x post-interactive table described above.

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
2                0x08         both        flags; bits 12-15 encode overwrite-mode index 0-4
3                0x0C         both        Windows file attributes
8                0x20         both        file-version major/minor halves, or FFFFFFFF
9                0x24         both        file-version build/private halves, or FFFFFFFF
10               0x28         both        code page/language translation when words 8-9 carry a version
11               0x2C         both        encoded destination-name byte count
12               0x30         both        volume-offset count
13               0x34         both        physical payload byte count
14               0x38         both        registration-priority index
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

Destination-name bytes use a fixed bit permutation, not encryption. The parser reverses that transform and then applies safe extraction-path validation. When words 8 and 9 are not `0xFFFFFFFF`, they have the same high-word/low-word layout as `VS_FIXEDFILEINFO`: word 8 carries major/minor and word 9 carries build/private. Word 10 then packs the code page in its high word and language ID in its low word. When the version pair is absent, word 10 remains unlabeled observed evidence. The first two payload bytes select GZip (`1F 8B`) or stored data. A GZip member's final little-endian ISIZE is used as expected-length evidence; `GZipStream` validates the compressed stream and CRC while the shared bounded copier enforces output limits.

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

Package identity, ARP identity, and generated-uninstaller identity are independent. `ApplicationName` is a fallback display value, not a ProductCode. ProductCode comes only from a resolved uninstall-key leaf. `UninstallerPath` names the generated file, while the registry record supplies the command that owns maintenance behavior. A disabled-uninstaller build can therefore contain a valid ARP command that points to a file the runtime never creates; the parser reports this as risk evidence instead of deleting the structured ARP row.

Deterministic variables include application and company names, install directory, Program Files, Common Files, Windows, System32, temporary directory, Start menu, Programs, Startup, and Desktop. Each compiled custom-variable record stores `TypeCode`, `SourceCode`, `DefaultValue`, three source locations, and a flags word. Type codes `0` and `1` mean Text and Number. Source codes `0`, `1`, `2`, and `0xFFFFFFFF` mean Registry, INI, Find file location, and Nowhere; option bits `0x01`, `0x02`, and `0x04` mean Store drive only, Set to true if exists, and User visible. Registry root location values observed from paired projects are signed `0x80000000`, `0x80000001`, and `0x80000002` for HKEY_CLASSES_ROOT, HKEY_CURRENT_USER, and HKEY_LOCAL_MACHINE. Builder-defined `Nowhere` variables resolve recursively from their literal default values with cycle and depth limits. The BreakAlube `<MainPath>` record instead selects Registry/HKEY_CLASSES_ROOT with empty key and value locations; live installation proves this empty lookup falls back to the compiled default, so the parser accepts that exact form as deterministic. Other registry, INI, file-search, dialog, timer, or DLL-backed variables remain raw evidence and cause affected manifest-facing fields to be omitted. The manifest-safe install path resolves deterministic custom variables as well, so `DefaultInstallLocation` and dependent ARP values such as `DisplayIcon` complete instead of staying unresolved.

The explicit ARP hive is primary scope evidence. Requested execution level and resolved destination provide fallback evidence. The x64-compliance option selects the 64-bit registry view on 64-bit Windows; otherwise the outer runtime's PE architecture supplies the registry-view default. Installed application architecture is analyzed from up to 32 selectively extracted EXE and DLL payload files under a 512 MiB aggregate bound.

Registry conditions and unresolved variables can produce several candidate ARP rows. Only unconditional visible rows with resolved key identity become manifest-facing entries. A builder option that suppresses Add/Remove Programs registration can omit the key entirely; controlled hidden-ARP media confirms that this route does not create a hidden `SystemComponent=1` row as a substitute.

## Switches and process result

Astrum 2.x builder help documents `/silent` for unattended installation, `/AcceptLicense` for configurations that require command-line license acceptance, and process exit code `1` for success. The parser suggests `/silent` and success code `1` for 2.x unless the generation keeps the documented User Information blocking claim. Controlled VM installations of 2.29.50 builds prove the modern runtime skips a compiled User Information dialog under `/silent` and completes with exit code `1` and full ARP registration, so `Modern2` media keeps silent support with an informational `Astrum.Silent.UserInformationDialogIgnored` diagnostic; `Early2` retains the documented interactive-only claim pending VM evidence. A selected license dialog plus the prohibit-silent flag adds `/AcceptLicense` as a custom switch; VM evidence confirms bare `/silent` refuses such media with exit code `0` and no partial installation. The separate direct-approval and silent-by-default flags are returned as `Modern2` configuration evidence.

The 2.29.50 installed-state matrix also establishes the surrounding behavior: as-invoker media with compiled HKLM writes refuses unelevated with exit code `0` and no partial state, `requireAdministrator` media refuses unelevated with exit code `5`, hidden-ARP media writes no uninstall key at all, and disabled-uninstaller media writes the complete ARP entry while never creating the generated uninstaller file its `UninstallString` names.

These refusal codes are not success codes. They describe launch contexts in which installation does not occur. Only the documented and live-verified exit code `1` belongs in `InstallerSuccessCodes` for the supported 2.x route.

The legacy native runtime keeps accepted command-line options inside its PE image rather than the appended Astrum configuration. The parser searches only bytes before the PE overlay and accepts an option when both boundaries are NUL, ASCII whitespace, or a quote, preventing application payload text and longer identifiers from becoming switch evidence.

```text
native PE runtime option table
+-- NUL or ASCII whitespace
+-- "/SILENT" ASCII
+-- NUL or ASCII whitespace
+-- optional adjacent options such as "/NOREMOVE"
`-- PE overlay boundary; searching stops here
```

The archived version history records that silent installation was added in Astrum 1.22. Distributed 1.x media does not carry a separate structured builder subversion, and its application version cannot safely be treated as builder identity. Tested 1.80 and 1.95.5 runtimes contain a NUL or whitespace-delimited `/SILENT` token in the native PE image before the Astrum overlay, and the cross-generation audit extends that to every archived 1.x builder installer from 1.80 through 1.95.5, including all Wayback captures. The parser treats that bounded option-table token as direct switch support, projects `/silent`, and continues to withhold 1.x success-code suggestions because the 2.x exit-code documentation is not generation-independent. If the exact token is absent, `Astrum.Silent.LegacyRuntimeVersionRequired` preserves the unresolved state.

Runtime decompilation of a 2.29.50 setup stub confirms the mechanism behind the runtime option table: the initializer parses `GetCommandLineA` into tokens and sets adjacent internal flags for `/SILENT` and `/ACCEPTLICENSE`, and every dialog-creation call site in the installation flow is gated on the silent flag, which is why a compiled User Information dialog does not block `/silent` on modern media. The same option table also contains an undocumented `/REVERT` token with a separate internal flag; its rollback semantics are unproven, so the parser observes but does not expose it.

## Cross-generation audit

All 46 cached artifacts, representing 41 unique hashes and including 20 archived builder installers dated 2001 through 2012, parse under the catalog-selected generation. Archive-date to release-date mapping from the published version history anchors the observed ranges with interior points: `Legacy1` at 1.80, 1.8x, 1.9x, 1.95.3-4, and 1.95.5 media; `Early2` at 2.01.50, 2.02.50, and 2.04.20 media; `Modern2` at 2.21.20, 2.22.30, 2.23.20, 2.24.00, 2.29.00, and 2.29.50 media. The `/ACCEPTLICENSE` runtime token appears in exactly the `Modern2` option tables and in none of the `Early2` tables, independently corroborating the profile boundary, which therefore stays bounded between 2.04.20 and 2.21.20. The paired `.ai2` builder projects are readable XML, and a one-option-per-fixture diff confirms that every decoded `Modern2` option value moves exactly with its project setting. Project files that request out-of-range dropdown values compile to the builder's clamped defaults rather than the requested values, so decoded requirements can legitimately differ from project intent; the parser reports the compiled values, which live installation behavior enforces.

## Extraction and integrity model

Default extraction follows installed destination records, not physical overlay order. Files under `<InstallDir>` retain their relative path. Other resolved roots are isolated below `_destinations`, unresolved paths below `_unresolved`, and raw configuration, descriptors, gaps, companion data, and unplaced uninstaller content below `_astrum` only when raw mode is requested.

Each GZip record is bounded by its descriptor length. The decompressor validates the member checksum and the parser compares output with the expected size. Stored records copy exactly the declared physical byte count. File records also retain version, language, attributes, installation-item index, condition, and volume offsets, so extraction does not need to guess ownership from a filename.

Spanned 2.x media is interpreted as one virtual byte address space. The parser never searches the filesystem for likely companions; the caller supplies them in physical order. Their aggregate length must equal the missing logical range exactly before a temporary seekable stream is constructed. A missing, duplicate, reordered, or extra volume fails before catalog extraction.

The generated uninstaller is a separate GZip range identified by footer offsets rather than a normal file record. It is emitted by default only when configuration resolves its installed path and uninstallation is enabled. This distinction prevents raw runtime data from appearing as an installed application file.

## Parser limits and gaps

The parser bounds footer and signature sizes, configuration bytes, recursive depth, record counts, string sizes, catalog ranges, selective PE analysis bytes, extraction entries, and aggregate expanded bytes. It restores caller-owned stream position through shared random-access helpers and opens each top-level installer once.

Malformed input fails at the owning layer. Invalid trailer pointers do not trigger a backward magic scan, checksum failure does not fall through to an unprotected configuration, and an unsafe destination cannot be rescued by replacing path characters. Marker-only native programs, ordinary GZip SFX files, and unrelated PE overlays are rejected before metadata projection.

Supported media covers normal Astrum InstallWizard 1.x and 2.x single-file installers, 1.x and 2.x tiny and tiny-verbose wrappers, explicitly supplied 2.x spanned volumes, stored or GZip payload members, resource files, and certificate tables after the logical payload. Raw extraction exports each file-record header and every bounded pre-catalog range not owned by the configuration or generated uninstaller, which makes compiled dialog and image bytes available without assigning invented UI-resource types. The configuration profiles are observed across `Legacy1` 1.80-1.95.5, `Early2` 2.01.50-2.04.20, and `Modern2` 2.21.20-2.29.50; the exact transition between the latter two remains unknown. File descriptor words 8 and 9 store the high and low `VS_FIXEDFILEINFO` file-version halves when both are not `0xFFFFFFFF`, and word 10 then stores the code page in its high word and language ID in its low word.

| Gap | Current handling | Evidence needed to close it |
| --- | --- | --- |
| Nonzero 1.x shortcut, INI, text, and file-operation tail words | Preserve as `ObservedOperationTail` | One-option controlled 1.x builds plus runtime-path confirmation |
| `Legacy1` and `Early2` option tails | Preserve as bounded opaque option evidence | Paired builder projects or a source-backed runtime table for each profile |
| Nonempty 2.x post-interactive table | Parse framing and preserve records without assigning full semantics | A project that populates the table and an observed runtime effect |
| Typed UI and image resources | Export bounded raw pre-catalog ranges | Resource record grammar from controlled builds or runtime code |
| Astrum 1.x spanned media | Reject because no structural fixture exists | A complete ordered 1.x volume set |
| Astrum releases before 1.80 and after 2.29.50 | Reject unsupported layouts unless an existing route validates exactly | Structurally distinct media and builder/runtime evidence |

## Implementation mapping

- `Modules/PackageModule/Libraries/Installers/AstrumInstallWizard.psm1`: footer, protected configuration, catalog, metadata, ARP, extraction, and generated uninstaller.
- `Modules/PackageModule/Libraries/Installers/AstrumInstallWizardFormatCatalog.psd1`: immutable generation and configuration-profile descriptors selected from validated structure.
- `Modules/PackageModule/Libraries/Infrastructure/Archive.psm1`: bounded GZip decompression.
- `Modules/PackageModule/Libraries/Infrastructure/InstallerAnalyzer.psm1`: strict structural routing before heuristic generic-EXE candidates.
- `Modules/PackageModule/Libraries/WinGet/WinGetAnalysis.psm1`: schema-valid generic-EXE projection.

## Fixtures

- Controlled Astrum 2.29.50 project: independent application and ARP names, version, publisher, install directory, stored payload, generated uninstaller, and nested execution record.
- Controlled 1.95.5 and 2.29.50 `/tiny` and `/tinyverbose` variants: 96-byte descriptor and GZip-compressed complete inner installer.
- Controlled five-part spanning project: a 2 MiB incompressible payload crossing the main EXE and four companion volumes.
- Controlled resource-file project: a literal `<ResourceDir>\Resource.txt` record proving that builder Resource files use the ordinary payload catalog and extraction path.
- Controlled variable-length requirement project: Windows 98 plus Windows Server 2003, 32-bpp display, Java 1.4.2, and .NET Framework 4.0 Client selectors; a second Java-plus-require-admin build verifies dynamic option anchoring.
- Astrum InstallWizard 1.80 builder installer, SHA256 `71D6C6361D2B069E7B28AC9B460FD47A4AF71C07A5A82D2B0349623D9F0636A0`: no trailer magic, `0xE8` footer, 60-byte file descriptors, and 148 payload records.
- Astrum InstallWizard 1.95.5 builder installer, SHA256 `1245412FFA57761A988D7881062ACE262EB9C9F2BA028F55544CDB24423C6F7C`: late 1.x magic-bearing suffix and 209 payload records.
- Astrum InstallWizard 2.01.50 builder installer, SHA256 `DA0D51CE828C3AC56248725E4130D641F306921AF850E8522340928A4B1F3EB6`: `Early2` configuration and 157 payload records.
- Astrum InstallWizard 2.21.20 builder installer, SHA256 `E03460739CD74A76C23038B5DA33074E3FF0D436E729D8ADEE4C27DE53C91FA1`: `Modern2` configuration and Authenticode-after-payload route.
- Astrum InstallWizard 2.29.50 builder installer, SHA256 `657A8F9CC933A5E11378F65378FE55347A45781948D300A12FE0FD41256C2F8A`: 124 payload records and two installation-item groups.
- BreakAlube PC-GINA 1.0.1.5, SHA256 `9024FD2F27A0B2192B44A00A66FB2BFA37E5309DA3645194E9FC6F1D1E158600`: application, nested driver installer, manuals, a literal `Nowhere` variable, and an empty Registry/HKEY_CLASSES_ROOT lookup whose compiled fallback completes the localized ARP template.

## Source references

- [Thraex Software](https://www.thraexsoftware.com/)
- [Archived Astrum InstallWizard installer](https://web.archive.org/web/20130816053259/http://www.thraexsoftware.com/download/aiw.exe)
- [Archived Astrum InstallWizard download page](https://web.archive.org/web/20120410054204id_/http://www.thraexsoftware.com/aiw/download.html)
- [Archived Astrum InstallWizard version history](https://web.archive.org/web/20120410054204id_/http://www.thraexsoftware.com/aiw/version_history.txt)
- Astrum InstallWizard 2.29.50 builder-shipped help and sample project.
- Controlled `aiw2.exe /build` output and static observations of archived builder installers from 1.80 through 2.29.50.
