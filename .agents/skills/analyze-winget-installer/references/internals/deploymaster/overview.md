# DeployMaster parser internals

This reference supports parser implementation and review. For installer analysis and manifest authoring, use the [DeployMaster workflow](../../families/deploymaster/workflow.md).

Read [binary notation](../../parser-development/binary-notation.md), [parser contracts](../../parser-development/contracts.md), and [performance guidance](../../parser-development/performance.md) before changing the parser.

## Format coverage and evidence

The parser covers the classic 2.x BZip2/zlib route and the locator-based 6.0 through current routes documented below. Variant-specific evidence must pass the same content-based detection and bounds checks.

| Route | Verified runtime range | Primary discriminator | Support status |
| --- | --- | --- | --- |
| `ClassicBZip2` | 2.5.3-2.5.5 | `BZh9` runtime member followed by a contiguous length-prefixed zlib catalog | Partial because prerequisite and completion records remain unresolved |
| `Header66` | 6.0.1-6.1.2 | Unique 66-byte locator-header candidate and complete core/language ranges | Supported |
| `Header70` | 6.5.1-7.1.1 | Unique 70-byte locator-header candidate with Windows 10 bounds | Supported |
| `Header74` | 7.2.0-7.7.0 | Unique 74-byte locator-header candidate with Windows 11 and package-settings fields | Supported |

These version ranges describe cached fixtures rather than dispatch conditions. The parser accepts a future or intermediate artifact only when one catalog route validates without ambiguity. DeployMaster 3.x through 5.x remains unclassified because no durable artifact establishes whether those releases use either known family.

Evidence labels in this reference separate four sources. Structural evidence comes from bounded records and selects parser routes. Controlled builder output assigns fields by changing one project option. Runtime decompilation establishes code paths such as uninstall quoting and URL fallbacks. VM evidence establishes installed registry state, files, elevation outcomes, and exit behavior for a concrete fixture. Product version resources are application-controlled and do not belong to any of these route selectors.

## Builder and runtime model

DeployMaster Builder turns a project into a native setup runtime plus a compiled package. The distributed setup does not contain the original `.deploy` project as a document that can be reopened by the builder. Identity, destinations, components, files, registry operations, associations, prerequisites, completion actions, and update behavior instead appear in separate binary records consumed by the runtime.

The installer runtime performs four jobs that must remain separate during analysis: it selects the architecture-specific runtime and payload records, resolves project variables and scope, applies the component install tree and system operations, then creates a deployment log and uninstaller registration. A PE launcher therefore proves only the setup engine architecture. The selected runtime core and install-tree applicability flags describe which application payload is installed.

Two physical package families are known. Classic 2.x puts a BZip2 runtime and zlib records directly in the PE overlay. Locator-based 6.x and later puts an integrity-checked absolute locator in the PE headers and uses raw LZMA for runtime cores, metadata blocks, and payloads. DeployMaster 3.x through 5.x has no durable structural fixture and is not assigned either grammar.

## Structural dispatch

Parser routing is based on mutually validating structures rather than PE product version strings. The application author controls those version resources, so they are not an engine-version discriminator.

```text
candidate PE
+-- valid locator at 0x80
|   +-- bounded package and CRC32
|   `-- exactly one normalized Header66/Header70/Header74 profile -> locator route
`-- no locator
    +-- DeployMaster runtime identity
    +-- PE overlay begins BZh9
    +-- bounded runtime member and contiguous zlib catalog
    `-- exact physical or pre-certificate ending -> ClassicBZip2 route
```

A locator profile is accepted only when its scope byte is in range, at least one runtime-core tuple is complete, every core is inside the CRC-protected region, the language block follows the final core, and exactly one catalog profile satisfies those relationships. The classic route binds runtime identity, compression boundaries, the filename record, catalog columns, and the trailing payload chain. A marker or a successful decompression alone is insufficient.

## Binary structure

DeployMaster keeps an absolute package locator at file offset `0x80`. The locator protects a bounded package range with expected file size and CRC32. The package begins with a version-dependent 66-, 70-, or 74-byte control prefix whose first five bytes are the shared LZMA properties, followed by runtime cores, typed metadata blocks, and file ranges.

```text
PE setup stub
+-- locator at [abs] 0x80
`-- package at PackageOffset
    +-- catalog-selected 66/70/74-byte control prefix
    |   `-- 5-byte LZMA properties at prefix offset 0
    +-- x86 and/or x64 runtime cores
    +-- language data block
    +-- identity data block
    +-- current package-settings preamble and portable-folder block
    +-- metadata-resident file payloads
    +-- component data block
    +-- CRLF file-name data block
    +-- parallel file catalog
    +-- install-tree data block
    +-- registry-operation data block
    +-- file-association data block
    +-- prerequisite, completion, uninstall, and update tail
    +-- catalogued payload ranges
    +-- optional zero padding to 8-byte alignment
    `-- optional Authenticode certificate table
```

```text
Base   Offset  Size  Field
-----  ------  ----  ---------------------------------------------
[abs]  0x80    4     PackageOffset, uint32 LE -> [abs]
[abs]  0x84    4     IntegrityLength, uint32 LE
[abs]  0x88    4     ExpectedCRC32, uint32 LE
[abs]  0x8C    8     ExpectedFileSize, uint64 LE
[abs]  0x94    4     Reserved/observed
```

The CRC covers the declared integrity range, not all bytes to EOF. `ExpectedFileSize` is the logical end of the DeployMaster package. Signed media can append zero padding through the next eight-byte boundary and a PE certificate table whose offset and size must agree with the PE security directory and physical EOF. The parser requires `PackageOffset` to equal the PE overlay offset after complete package parsing. The data-driven format catalog selects `Header66` for observed 6.0.1-6.1.2 media, `Header70` for observed 6.5.1-7.1.1 media, and `Header74` for observed 7.2.0-7.7.0 media. These release ranges describe fixtures; dispatch still depends on structural range checks. Undocumented control fields remain `Observed`, and truncated or expanding-out-of-bound ranges are rejected.

The three control-prefix layouts share one normalized field map. Let `Shift` be `-8` for `Header66`, `-4` for `Header70`, and `0` for `Header74`.

```text
Base       Offset            Size  Field
---------  ----------------  ----  -----------------------------------------------------
[package]  0x00                 5  raw-LZMA properties: property byte + dictionary size
[package]  0x05                 8  supported-Windows platform bitset, uint64 LE
[package]  0x0C                 1  bit 7 permits future Windows releases
[package]  0x0D                 4  Windows 10 min/max codes, Header70/Header74 only
[package]  0x11                 4  Windows 11 min/max codes, Header74 only
[package]  0x15 + Shift         1  scope selector
[package]  0x16 + Shift        12  x86 core offset/stored size/expanded size, uint32 LE
[package]  0x22 + Shift        12  x64 core offset/stored size/expanded size, uint32 LE
[package]  0x2E + Shift         4  language data-block absolute offset, uint32 LE
[package]  0x32 + Shift         6  compiled expiration year/month/day, uint16 LE
[package]  0x38 + Shift         4  expiration-message absolute offset, uint32 LE
[package]  0x3C + Shift         2  expiration-message UTF-16 code-unit count, uint16 LE
```

Core offset zero means absent. The x64 offset also uses `0xFFFFFFFF` in the x86-only-on-x86 route. Offset, stored size, and expanded size form one indivisible tuple; a partially zero tuple is invalid. The runtime cores use the package-level raw-LZMA properties and must expand to their exact declared sizes.

### Classic 2.x route

Classic 2.x media has no `0x80` locator. Its PE overlay starts with a single BZip2 runtime member and then switches to length-prefixed zlib records.

```text
PE setup stub
`-- overlay at PE raw-image end
    +-- BZh9...                                  BZip2 runtime member
    +-- FF FF FF FF                             member boundary marker
    +-- Length:u32 LE + zlib language text
    +-- Length:u32 LE + zlib identity text
    +-- UI/configuration records, auxiliary files, and component records
    +-- Length:u32 LE + zlib CRLF filename list
    +-- classic file catalog columns
    +-- recursive component destination forests
    |   +-- NameLength:u8 + Folder:Windows-1252
    |   +-- FE + Length:u32 LE + zlib item stream
    |   `-- FF level terminators
    +-- zlib registry and file-association records
    +-- unresolved prerequisite/completion records
    +-- Length:u32 LE + zlib payload 0
    +-- ...
    +-- Length:u32 LE + zlib payload N
    +-- optional zero alignment padding
    `-- optional Authenticode certificate table
```

The parser accepts the BZip2 boundary only when the following record has a valid RFC 1950 header and the preceding member expands within 64 MiB to a valid PE. It indexes zlib candidates from their four-byte length prefixes, walks backward from physical EOF or a validated pre-certificate boundary to recover a contiguous payload chain, and accepts only the nearest small metadata record whose Windows-1252 CRLF lines form safe relative paths with exactly one name per payload. This relationship prevents zlib-looking bytes inside compressed data from becoming catalog entries.

The classic identity record uses Windows-1252 and form-feed delimiters. Observed 2.5.3 fields contain publisher, publisher URL, display name, package URL, display version, OLE Automation release day, copyright, display-icon filename, readme filename, license filename, x86 support-DLL filename, machine and user installation destinations, machine and user menu destinations, description, and additional text. These positions must not be passed to the later UTF-8 identity decoder because fields 7 through 10 have different meanings.

The classic file catalog starts immediately after the filename-list record. Each entry contributes a 32-bit offset, a 32-bit observed value, an eight-byte observed value, a 32-bit expanded size, and a CRC32. Auxiliary display-icon, readme, license, and x86 support-DLL payloads use `0xFFFFFFFF` offsets because their zlib records precede the table; the parser locates each one through its unique expanded-size and CRC pair. Ordinary offsets must equal the recovered trailing payload chain. The byte immediately after the six parallel catalog columns begins the first component's destination forest; it is not merely a one-record catalog suffix.

Classic payload extraction covers the complete auxiliary and ordinary file catalog. The records immediately before the filename catalog also expose component flags, one-byte-length Windows-1252 names, earlier-component requirement indexes, and descriptions. One recursive destination forest follows for every component in catalog order. A byte below `0xFE` is a Windows-1252 folder-name length; root names such as `%APPFOLDER%`, `%APPMENU%`, and `%DESKTOP%` are variable destinations, while nested names append to the parent path. `0xFE` attaches the following length-prefixed zlib item stream to the current folder and closes that node list; `0xFF` closes a list without an item stream. Flat file records use an `0x80`-family opcode and a 16-bit file index; `0x40` records contain a target file index, three one-byte-length Windows-1252 strings, flags, and a reference; `0x20` records contain URL, label, flags, and reference fields. The parser therefore recovers every item's component and full destination, including nested folders and separate Start Menu and desktop routes. After the final component forest, the parser recognizes a classic registry stream only when it begins with opcode `0x01`, a NUL-terminated Windows-1252 `HKEY_*` root, and consumes the complete record. Child-key opcode `0x01`, separator `0x1F`, value-name opcode `0x02`, string opcode `0x04`, DWORD opcode `0x05`, and branch terminator `0xFF` are supported. Classic file associations use a one-byte count, form-feed-terminated Windows-1252 description and extension, one x86 icon index/resource pair, and repeated action name, x86 executable index, and parameter records. Prerequisites and completion records remain unresolved.

The 2.5.x setup runtime contains a dedicated built-in 32-bit HKLM uninstall-key path. A controlled 2.5.3 installation confirms that the key name is the package identity `DisplayName`, while the registered `DisplayName` concatenates publisher, package name, and version. Classic ARP writes only `DisplayName` and `UninstallString`; it does not add the later Publisher, DisplayVersion, InstallLocation, NoModify, NoRepair, EstimatedSize, or InstallDate values. The uninstaller command is `%WINDOWS%\UnDeploy.exe "<MachineInstallLocation>\Deploy.log"`, and the runtime also records the log under a value named for the ProductCode below 32-bit `Software\JGsoft\DeployIT`; `Stub` remains runtime-generated source-path evidence. Explicit Registry-tab uninstall writes remain separately decoded and projected when present. The classic runtime contains no unattended switch parser or referenced slash-token route, so 2.5.x media is interactive-only.

The first eight control-header bytes after the LZMA properties form a platform bitset. Controlled current-builder outputs identify `0x80` as Windows 7, `0x0100` as Windows 8, `0x0200` as Windows 8.1, `0x0400` as Windows 10, `0x0800` as Windows 11, and bit 63 as future Windows releases. `Header70` and `Header74` store UInt16 minimum and maximum Windows 10 version codes. `Header74` additionally stores Windows 11 range fields at package-relative offsets `0x11` and `0x13`. `Header66` predates both range pairs, so those bytes must not be interpreted as operating-system bounds. Older platform bits remain raw until separately verified.

`Header74` stores a compiled expiration year, month, and day at package-relative offsets `0x32`, `0x34`, and `0x36` as UInt16 values. A zero date disables expiration. When enabled, `0x38` is the absolute offset of the UTF-16LE expiration message and `0x3C` is its UInt16 character count. `Header70` shifts these fields four bytes earlier and `Header66` shifts them eight bytes earlier. The message must fit between the last runtime core and the language block. Both fixed-date and days-after-release projects compile to this final date and cannot be distinguished afterward.

The structured identity block contains form-feed-delimited UTF-8 fields. Fields 0 through 6 hold publisher, publisher URL, application name, application URL, version, OLE Automation release day, and copyright. Fields 7 through 10 hold the readme filename, license filename and policy marker, x86 support-DLL filename, and x64 support-DLL filename. The first byte of field 11, the machine application path, is a route marker rather than part of the path: `0x01` selects machine scope, `0x02` selects user scope, `0x03` permits both, and `0x06` selects user scope while requiring administrative rights. Marker `0x06` intentionally shares package-control scope byte `1` with machine media, so registry hive selection must use the identity route. Fields 12 through 18 contain user application, common-files, publisher-common, machine/user menu, and common/user data locations.

## Scope, variables, and runtime selection

The identity marker is authoritative when it distinguishes machine, user, dual-scope, or current-user-with-administration behavior. The package-control scope byte is a consistency check and can intentionally differ for marker `0x06`. `HKEY_AUTO` and scope-dependent paths remain conditional for dual-scope media until the launch context selects a route.

DeployMaster paths use installer variables rather than literal host paths. The parser converts stable roots such as `%PROGRAMFILES%`, `%LOCALAPPDATAROOT%`, `%APPDATAROOT%`, and `%COMMONAPPDATAROOT%` to manifest-safe environment paths while preserving raw values beside the resolved form. `%APPFOLDER%`, menu, common-data, and user-data destinations depend on the selected scope and the authored identity fields. Unknown variables remain unresolved instead of being expanded against the analyst's machine.

The runtime chooses x86, x64, or mixed payloads from the normalized core table and per-install-item applicability flags. Mixed media can contain identically named architecture-specific support DLLs and uninstallers as distinct physical entries. File identity therefore includes catalog position and architecture applicability; filename alone is not a unique key.

## Data blocks

DeployMaster reuses one signed-size framing convention for metadata. All integers are little-endian and offsets are absolute unless noted otherwise.

```text
Offset  Size  Field
------  ----  -------------------------------------------------------
+0x00      4  Size, Int32
              0: empty block
             <0: stored byte count is -Size; bytes begin at +0x04
             >0: expanded byte count; CompressedSize follows
+0x04      4  CompressedSize, Int32, present only when Size > 0
+0x08      n  raw-LZMA bytes, using the package-level 5-byte properties
```

Each decoder receives the next structural boundary and an expanded-size limit. A block cannot consume the following record, and its decoded length must equal the declared positive size.

## Components and install tree

The component block begins with a byte count. Each component contains a length-prefixed UTF-8 name, a flag byte, a byte requirement count and requirement indexes, then a UTF-8 description. Flag bit `0x02` means installed by default and bit `0x01` means user-selectable.

One install-tree data block contains a recursive tree for every component in catalog order. A marker below `0xFE` is the UTF-16LE character count for a directory name, followed by a create-empty flag and nested records. `0xFE` starts an item list and `0xFF` terminates the current list or directory. The parser currently decodes file items (`0x80` family), file shortcuts (`0x40`), and URL shortcuts (`0x20`); every file reference is checked against the catalog. For a file item, opcode bits `0x00` through `0x02` select always overwrite, overwrite if newer, or never overwrite, and opcode bit `0x04` keeps the file during uninstall. The following flag byte uses `0x01` for x86 applicability and `0x02` for x64 applicability; both can be set. Flag bit `0x10` gates the following optional argument string. These mappings are verified by controlled single-field builder output rather than inferred from shipped filenames.

## File catalog

The CRLF-delimited UTF-8 filename block ends shortly before the catalog. Observed media leaves generation- and project-dependent reserved bytes in this gap, so the parser searches at most 64 bytes and selects the uniquely nearest valid decoded block instead of assigning a release-specific constant. Readme, license, and x86/x64 support-DLL names are omitted from this block because identity fields 7 through 10 already carry them. Readme and license aliases can identify one physical entry, but identically named x86 and x64 support DLLs remain separate catalog entries because they have separate architecture-selected payloads. Current media serializes one value per file in six parallel arrays: absolute offset, expanded size, stored size, OLE Automation timestamp, attributes, and CRC32. The first five arrays use 64-bit values and CRC32 uses 32 bits, for `44 * FileCount` bytes. Earlier media can keep one or more auxiliary payloads before `PackageDataOffset` as `[StoredSize:uint32][ExpandedSize:uint32][Data]`; the parser reconstructs each missing offset from its parallel size columns and requires a unique bounded record. A maximal strictly increasing boundary run prevents suffixes of the real offset table from being accepted as independent catalogs.

Stored size equal to expanded size selects direct copying. Other files are raw-LZMA streams using the package properties. Expansion checks the selected entry's output size and CRC32 before retaining it.

## Registry and associations

The registry block is a recursive opcode stream. An outer `0x01` introduces a root name and branch; a non-`0x01` byte ends the root list. Branch opcodes are `0x01` child key, `0x02` delete key during uninstall, `0x03` select default value, `0x04` select named value, `0x05` keep an existing value, `0x06` logging/removal behavior, `0x07` `REG_SZ`, `0x08` `REG_DWORD`, `0x09` `REG_BINARY`, and `0xFF` end branch. `HKEY_AUTO` resolves to HKCU for user scope, HKLM for machine scope, and SHCTX for dual-scope media.

The following file-association block has two validated string-framing routes. Current 7.7 records use length-prefixed UTF-8 strings and include a default-selection byte. Archived 6.0 through 7.2 records use form-feed-terminated Windows-1252 strings and omit that byte; Header74 media selects between them from the first bounded record field rather than from the header size alone. Both routes store literal extensions, descriptions, architecture-specific icon indexes, and action records. An action holds its name, x86/x64 executable indexes, and parameters. Registry-tab class writes are interpreted separately and then merged with these dedicated records.

For a normal installation, the runtime derives the uninstall key as `Software\Microsoft\Windows\CurrentVersion\Uninstall\<DisplayName>` in HKCU or HKLM according to the selected scope and architecture-selected registry view. Runtime decompiles of the 6.0.1, 6.5.1, 7.6.0, and 7.7.0 cores confirm the complete built-in value set: `DisplayName`, `UninstallString`, `NoModify` and `NoRepair` as DWORD 1, `EstimatedSize` as a computed DWORD, `InstallDate` as a `yyyymmdd` string, `InstallLocation`, `DisplayVersion`, string `VersionMajor` and `VersionMinor`, `Publisher`, `HelpLink`, `URLInfoUpdate`, `URLInfoAbout`, and `DisplayIcon`. `VersionMajor` and `VersionMinor` hold the first two dot-separated `DisplayVersion` components as written, so `DEMO 6.1.2` registers as `DEMO 6` and `1`; live installs of controlled archived demo media confirm this split for non-numeric versions that the earlier digit-only model could not project. The installed uninstaller is `UnDeploy.exe` for x86 and `UnDeploy64.exe` for x64. Mixed media keeps the two source payloads distinguishable as `UnDeploy32.exe` and `UnDeploy64.exe`, then installs the selected x86 payload as `UnDeploy.exe`; Header66-era runtimes select an `UnDeployXP.exe` payload on Windows versions before 6.0. Header66 and Header70 always quote the log path and never quote the executable, producing `<InstallLocation>\<Uninstaller>.exe "<InstallLocation>\Deploy.log"`. Header74 runtimes instead quote each resolved path exactly when it contains a space, so the canonical `"<InstallLocation>\<Uninstaller>.exe" "<InstallLocation>\Deploy.log"` form matches every standard install location while a space-free custom folder stays unquoted. The application URL is written to both `HelpLink` and `URLInfoUpdate` with a publisher-URL fallback when no application URL is configured, and the block is skipped only when both URLs are empty; this gate is byte-identical in every locator-based generation from 6.0.1 through 7.7.0. The publisher URL is written to `URLInfoAbout`. `DisplayIcon` is written only when the project defines an application icon; the parser does not decode the icon reference and leaves the value unresolved. DeployMaster also writes the deployment-log path to the `<DisplayName>` value under `Software\JGsoft\DeployIT` in the same registry view as the uninstall key, next to a runtime-generated `Stub` value holding the setup source path; `EstimatedSize`, `InstallDate`, and the log file name itself depend on runtime state, and a reinstall over an existing deployment registers an indexed name such as `Deploy2.log`.

The quoting route boundary was verified against the extracted runtime core of every archived generation. The 6.0.1, 6.1.2, 6.5.2, 6.5.3, and 7.1.1 cores build the uninstall command as one fixed four-string concatenation that quotes the log unconditionally and never quotes the executable; the 7.2.0, 7.6.0, and 7.7.0 cores replace it with the space-conditional per-path build, so the route change coincides exactly with the Header74 format boundary.

Neither the builder nor any runtime generation writes `SystemComponent`, `QuietUninstallString`, or other ARP visibility attributes for the built-in entry. Byte searches of the 7.7 builder and the 6.0.1 through 7.7 runtime cores find no such value names in any encoding, the builder UI exposes no visibility control across its Project, Identity, Media, Registry, File Types, Portable, and Finished tabs, and the shipped help states that the built-in Add/Remove Programs entry exists regardless of other settings. Only Registry-tab records can create additional uninstall keys, including hidden ones, so every non-built-in ARP row is custom evidence rather than a built-in variant.

## Trailing records

After associations, one byte is a .NET Framework compatibility mask: bits `0x01`, `0x02`, `0x04`, `0x08`, and `0x10` represent versions 1.0, 1.1, 2.0, 3.0, and 3.5, while `0x20` enables the 4.x family. The next byte selects the minimum 4.x release from 4.0 through 4.8.1. A data block follows with bare-CR positional fields for an optional automatic-installer filename and fallback download URL, followed by a 16-byte observed state record. A bounded signed custom-prerequisite count follows; every custom prerequisite has a compressed text descriptor and 16 observed bytes. The parser preserves undocumented positions without assigning guessed semantics.

Completion flags gate x86/x64 post-install file indexes and one argument block. The same tail stores architecture-specific pre-uninstall file indexes, arguments, and uninstall-shortcut settings. The final update flag byte uses `0x01` for delete-obsolete-files behavior, `0x02` for a patch package requiring a compatible previous release, `0x04` for blocked window classes, and `0x08` for blocked window captions. A UInt16 OLE Automation day follows, then each enabled variable-length field appears as a normal data block in patch text, class, caption order. File indexes are resolved to catalog names in `ExecutedPayloads`.

## Command-line and portable routes

Locator-based runtimes accept `/s` and `/silent` for unattended installation and `/appfolder`, `/appcommonfolder`, `/appmenu`, `/userdata`, and `/temp` for path overrides. `/nodesktop` suppresses desktop shortcuts. Mixed-architecture media can expose `/32`. Header74 dual-scope media can expose `/userall`; older `Header66` media does not carry that route. The parser reports the complete command vocabulary separately from the WinGet-facing silent and install-location pair.

Portable behavior is compiled into the package-settings record as `Never`, `UserChoice`, or `Always`. A non-`Never` value is not enough to prove a usable command line: the parser expands one bounded runtime core and requires the exact UTF-16 `/portable` token before exposing that switch. `Always` suppresses the normal installation route and built-in ARP registration. `UserChoice` retains both normal and portable behavior. The generated uninstaller accepts `/silent` independently of the setup switch.

Classic 2.5.x runtime images contain no referenced unattended switch table or bounded slash-token route. They are treated as interactive-only rather than inheriting switches from later DeployMaster releases.

## Installation and maintenance state

Normal installation writes files selected by components and architecture, applies registry and association records, runs configured completion payloads, writes `Deploy.log`, installs the architecture-selected `UnDeploy` runtime, and creates the built-in uninstall key. The deployment log is the uninstaller's state database; deleting or renaming it can make the ARP command unusable even when the executable remains.

An update can select a different deployment-log filename when the previous file remains, such as `Deploy2.log`. The `Software\JGsoft\DeployIT` value and `UninstallString` must therefore agree on the same runtime-selected log. Static output represents the canonical first-install path and labels `EstimatedSize`, `InstallDate`, the source `Stub`, and indexed log names as runtime-generated evidence.

Portable-only installation skips the built-in uninstall registration and ordinary host-system changes. Custom support DLLs and explicitly authored registry actions can still have opaque behavior, so their presence remains a separate validation boundary.

## Validation and trust boundaries

The locator CRC authenticates only the declared integrity range. Every payload still has its own stored size, expanded size, and CRC32, and extraction validates all three. A valid PE certificate does not replace those checks, while a valid package CRC does not prove a catalogued payload outside the integrity region.

Metadata projection follows the runtime's ownership boundaries. The built-in identity and explicit registry records can establish ARP values. A support DLL, nested prerequisite, or completion executable can change installed state after the static records run, so its effects remain separate evidence. Conditional dual-scope records are not collapsed to the analyst's current user or elevation state.

The parser opens one installer stream per top-level operation, uses bounded substreams for compressed members, limits recursion and counts before allocation, and checks every file reference against the catalog. Destination paths are normalized without permitting traversal outside the extraction root. Malformed input fails at the structure that owns the invalid range instead of falling back to a weaker family detector.

## Known gaps

| Gap | Current handling | Evidence needed to close it |
| --- | --- | --- |
| DeployMaster 3.x through 5.x | Reject instead of extrapolating the 2.x or 6.x grammar | Durable installers or controlled builder media from those generations |
| Classic prerequisite and completion records | Preserve the surrounding bounded records without projecting effects | Paired 2.5.x projects and live or decompiled behavior |
| Classic 2.5.4 and 2.5.5 installed state | Reuse only structurally common fields and retain the 2.5.3 live-evidence limitation | Checkpointed installations of both later classic fixtures |
| Locator prerequisite descriptor positions and condition semantics | Preserve observed fields and report opaque effects | Single-option builder diffs and runtime-path confirmation |
| Support DLL effects | Report the DLL and require separate static or VM analysis | Analysis of the package-specific exported callbacks |
| Project icon reference | Leave `DisplayIcon` unresolved | Builder diff plus runtime resolution of the selected icon payload |
| Expiration source mode | Return the compiled date and message only | Not recoverable from known media because both authoring modes converge |
| `EstimatedSize`, `InstallDate`, source `Stub`, and indexed `DeployN.log` names | Mark runtime-generated | Installed-state evidence for the concrete run |
| Future structural layouts | Reject | A new catalog route backed by bounded fixtures |

## Implementation mapping

- `Modules/PackageModule/Libraries/Installers/DeployMaster.psm1`
- `Modules/PackageModule/Libraries/Installers/DeployMasterFormatCatalog.psd1`

## Representative fixtures

- Archived 2.5.3, 2.5.4, and 2.5.5 media establish the `ClassicBZip2` runtime, zlib catalog, component forests, and classic registry/association grammars.
- Archived 6.0.1 and 6.1.2 media establish `Header66`, the legacy delimited registry route, form-feed associations, and no `/userall` support.
- Archived 6.5.1, 6.5.2, 6.5.3, and 7.1.1 media establish `Header70` and the fixed unquoted-executable/quoted-log uninstall command.
- Archived 7.2.0 and 7.6.0 media plus controlled 7.7 output establish `Header74`, package settings, conditional path quoting, current associations, portable choices, scope variants, and x86/x64 payload selection.
- Controlled VM installations cover machine, user, user-with-administration, dual-scope, mixed architecture, portable-only, and custom visible/hidden ARP records.

## Source references

- [DeployMaster manual](https://www.deploymaster.com/manual.html)
- [DeployMaster silent installation](https://www.deploymaster.com/manual.html#silent)
- [DeployMaster version history](https://www.deploymaster.com/history.html)
- [Archived DeployMaster builder media](https://web.archive.org/web/*/https://download.jgsoft.com/deploymaster/SetupDeployMasterDemo.exe)
