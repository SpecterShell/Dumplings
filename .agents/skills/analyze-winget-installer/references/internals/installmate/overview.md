# InstallMate internals

This reference describes the InstallMate structures consumed by Dumplings. It is intended for parser maintenance and reverse engineering; use the [InstallMate workflow](../../families/installmate/workflow.md) for package analysis and manifest authoring.

Read [binary notation](../../parser-development/binary-notation.md), [parser contracts](../../parser-development/contracts.md), and [performance guidance](../../parser-development/performance.md) before changing the implementation.

## Format lineage

InstallMate uses Tarma TIZ containers, but the framing and database layout changed across releases. Dispatch must use the physical signature, compression framing, and decoded database signature rather than a product-version string.

| Observed builder line | Container | Compression | First decoded record | Database | Parser route |
| --- | --- | --- | --- | --- | --- |
| 2.25 and 2.99 | `tiz1` at the PE overlay | RFC 1950 Zlib | `tzff` named `Setup.ini` | repeated INI sections | `Legacy2` |
| 3.2 and 3.8 | `tiz3` in the PE overlay | raw LZMA | type-2 `tzf3` | `tin3` | `Modern/tin3` |
| 5.2 | `tiz3` in the PE overlay | raw LZMA | type-2 `tzf3` | `tin5` | `Modern/tin5-early` |
| 5.7 and 5.9 | two concatenated `tiz3` archives | raw LZMA | loader record, then type-2 `tzf3` | `tin5` | `Modern/tin5-late` |
| 8.x and 9.x | `tiz4` in an overlay or `.tsuarch` | raw LZMA2 | type-2 `tzf3` | `tin9` | `Modern/tin9` |
| Current controlled Deflate media | `tiz2` in `.tsustub` or `.tsuarch` | RFC 1950 Zlib | type-2 `tzf3` | `tinB` | `Modern/tinB` |
| Current controlled LZMA media | `tiz3` in `.tsustub` or `.tsuarch` | raw LZMA | type-2 `tzf3` | `tinB` | `Modern/tinB` |
| Current controlled LZMA2 media | `tiz4` in `.tsustub` or `.tsuarch` | raw LZMA2 | type-2 `tzf3` | `tinB` | `Modern/tinB` |

Controlled InstallMate 11 builds establish the compression mapping independently of marker strings: the builder's Deflate choice produces `tiz2` with a valid RFC 1950 CMF/FLG pair at archive-relative `+0x38`, LZMA produces `tiz3`, and LZMA2 produces `tiz4`. A payload-bearing `tiz2` build containing one 33-byte installed file verifies that the decompressed stream uses the same `tzf3` database and typed payload-segment framing as current `tiz3` and `tiz4` media; selective extraction reproduces the source file byte-for-byte.

## Physical container map

```text
InstallMate 2.x single-file setup
+-- PE image
+-- overlay-relative tiz1 header
|   +-- "tiz1"
|   +-- version = 1
|   `-- RFC 1950 Zlib stream
|       +-- tzff "Setup.ini"
|       `-- repeated tzff payload records
`-- optional PE certificate table

InstallMate 3+ package
+-- PE image
|   `-- optional .tsustub/.tsuarch section
|       `-- section-relative +0x10: tiz2/tiz3/tiz4 archive
+-- optional overlay
|   +-- optional loader tiz archive
|   `-- package tiz archive
`-- optional PE certificate table
```

The certificate table uses file offsets rather than RVAs. When present, its offset is the logical end of overlay data. A TIZ candidate must fit before that boundary unless it is hosted in a validated PE section.

## TIZ1 header

All fields below are relative to the exact PE overlay offset.

```text
Offset  Size  Field
------  ----  -------------------------------------------------
0x00       4  ASCII "tiz1"
0x04       4  Version, uint32 LE; observed value 1
0x08     ...  RFC 1950 Zlib member
```

The parser validates the Zlib CMF/FLG pair before opening the decoder. The first decoded record must be a bounded `tzff` record named `Setup.ini`; an isolated `tiz1` marker is insufficient.

## TIZ2, TIZ3, and TIZ4 headers

The following fields are relative to the selected archive start. Only fields consumed by Dumplings are assigned semantics.

```text
Offset  Size  Field
------  ----  -------------------------------------------------
0x00       4  ASCII "tiz2", "tiz3", or "tiz4"
0x04       2  Physical version word A, uint16 LE
0x06       2  Physical version word B, uint16 LE
0x08       8  Reserved; required to be zero
0x10       8  Declared archive size, uint64 LE
0x18    0x20  Observed or reserved header bytes
0x38       0  tiz2 has no property block
0x38     ...  tiz2 RFC 1950 Zlib stream
0x38       5  tiz3 raw-LZMA properties
0x3D     ...  tiz3 raw-LZMA stream
0x38       1  tiz4 raw-LZMA2 property
0x39     ...  tiz4 raw-LZMA2 stream
```

Historical release media stores the two physical words in minor-major order. Dumplings retains `FormatVersion` in physical order for compatibility and exposes `BuilderFormatVersion` in release order. These values identify the archive revision; they are not a substitute for PE product-version evidence.

The declared archive range is bounded by the containing overlay or section. TIZ2 candidates additionally require a valid Zlib compression method and header checksum before decompression. InstallMate 5.7 and 5.9 compressed-EXE launchers contain a loader archive before the package archive, so selection must probe the first decoded record of every structurally valid candidate and choose the unique type-2 `tin?` database.

## TIZ1 tzff records

Each decoded legacy record has a 40-byte fixed header, a variable UTF-8/ANSI-compatible name, and the payload body.

```text
Record-relative offset  Size  Field
----------------------  ----  ---------------------------------
0x00                       4  ASCII "tzff"
0x04                       4  Observed or reserved
0x08                       4  Payload length, uint32 LE
0x0C                    0x1A  Observed or reserved
0x26                       2  Name length, uint16 LE
0x28                NameLen  Record name
0x28+NameLen       DataLen  Payload bytes
```

The first payload is `Setup.ini`. Later record names correspond to the archive names listed by repeated `[Files]` sections. Exact name and size agreement is required before a record is written.

## Legacy Setup.ini model

InstallMate 2.25 stores product metadata in `[Install]`; 2.99 moves many values into `[Symbols]` records encoded as `numeric-id|platform-mask|value`. Repeated `[Files]` sections are stateful: each `InstallDir` applies to the following `File` records in that section and must not be flattened into one dictionary.

```ini
[Install]
Title=...
Version=...
CompanyName=...
InstallDir=...
UninstallKey=...
AdminRights=...

[Symbols]
AppTitle=<id>|<mask>|<value>
Uninstall=<id>|<mask>|<value>

[Files]
InstallDir=<AppFolder>\Subdirectory
File=<archive-name>|<size>|...
```

Literal references such as `<AppFolder>` and `<ProgramFiles>` are recursively resolved with a depth limit. Registry-derived or unknown symbols remain unresolved. Files below `<AppFolder>` receive installed relative paths; files targeting other roots are placed below `_destinations` during extraction rather than being presented as application-relative files.

## Modern tzf3 records

The decoded TIZ3/TIZ4 stream is a sequence of 64-byte record headers followed by record data.

```text
Record-relative offset  Size  Field
----------------------  ----  ---------------------------------
0x00                       4  ASCII "tzf3"
0x04                       4  Observed or reserved
0x08                       2  Segment type, uint16 LE
0x0A                       6  Observed or reserved
0x10                       8  Segment length, uint64 LE
0x18                    0x28  Observed or reserved
0x40                 Length  Segment bytes
```

The package stream begins with segment type 2, whose body starts with a `tin?` signature. Subsequent segment types are matched to typed file catalog records by segment type and uncompressed size. Each catalog record can consume at most one payload segment, preserving stream order when different files share the same size and type.

## tin symbol records

The shipped `TsuSymbolRules.imdata` data anchors the symbol identifiers used for package and uninstall identity.

| Identifier | Symbol |
| ---: | --- |
| 403 | `ProductCode` |
| 404 | `ProductName` |
| 405 | `ProductVersion` |
| 410 | `UninstallKey` |
| 423 | `PackageCode` |
| 426 | `PRIMARYFOLDER` |
| 449 | `MainProductCode` |
| 523 | `TsuInstallLevel` |

Records begin with `symb\0\0\0\0`. `tin3` stores the identifier at `+0x18`, a value length at `+0x20`, and value bytes at `+0x24`. Verified `tin5` stores the identifier at `+0x10`, value length at `+0x18`, and value at `+0x1C`. `tin9`, `tinA`, and `tinB` store the identifier at `+0x10`, a name length at `+0x18`, the UTF-8 name at `+0x1C`, then a value length and UTF-8 value.

The parser resolves bounded literal `<SymbolName>` references. A resolved `UninstallKey` is preferred for ARP `ProductCode`; the typed `ProductCode` symbol and then the named PE `StringFileInfo.ProductCode` value are fallbacks. Arbitrary GUID scans are not used.

## tin file records

File catalog records begin with `file\0\0\0\0`. The eight-byte key at `+0x08` identifies the payload segment type in its first uint16, and the eight-byte parent key at `+0x14` links to the unresolved folder/component graph.

| Database route | File size | Name length | Name | Status |
| --- | ---: | ---: | ---: | --- |
| `tin3` | `+0x3C` uint64 | `+0x54` uint32 | `+0x58` | verified on 3.2 and 3.8 |
| `tin5`, physical word A <= 2 | `+0x38` uint64 | `+0x4C` uint32 | `+0x50` | verified on 5.2 |
| `tin5`, physical word A >= 7 | `+0x38` uint64 | `+0x50` uint32 | `+0x54` | verified on 5.7 and 5.9 |
| `tin5`, physical word A 3 through 6 | unknown | unknown | unknown | rejected for extraction pending fixtures |
| `tin9`, `tinA`, `tinB` | `+0x3C` uint64 | `+0x54` uint32 | `+0x58` | verified on 8, 9, and current media |

For current `tin9`, `tinA`, and `tinB` databases, the component-reference table and folder key are resolved through the folder graph described below. Files below the package's `PRIMARYFOLDER` receive installed relative paths. Files whose destination lies outside that root are placed below `_destinations`; a structurally valid record whose folder cannot be resolved retains the collision-safe `Payload/<record-key>/<leaf-name>` identity. `CanExpand` is false when the database revision lacks a verified file layout.

## Current component and folder graph

Current records use eight-byte object keys. References are stored as a bounded `uint32` count at record-relative `+0x10`, followed by that many keys at `+0x14`. The parser resolves keys case-insensitively and limits each reference list to 4,096 entries.

```text
cmp9 component record
Offset  Size  Field
------  ----  -------------------------------------------------
0x00       8  ASCII "cmp9" followed by four NUL bytes
0x08       8  Component object key
0x10     var  LP UTF-8 internal name
...      var  LP UTF-8 folder alias
...      var  LP UTF-8 condition
...        4  Reserved or observed uint32
...      var  LP UTF-8 display name
...        4  Display-name translation count
...      var  LP UTF-8 description
...        4  Description translation count

fldr folder record
Offset       Size  Field
-----------  ----  --------------------------------------------
0x00            8  ASCII "fldr" followed by four NUL bytes
0x08            8  Folder object key
0x10            4  Component-reference count N
0x14          8*N  Component object keys
0x14+8*N     0x10  Observed fixed fields
0x24+8*N        8  Parent folder key
0x2C+8*N      var  LP UTF-8 internal name
...             4  Name translation count
...           var  LP UTF-8 installed path segment
```

The graph resolver starts with standard folder symbols and typed symbol values, then repeatedly joins a folder's path segment to its resolved parent. Cycles, missing parents, and unresolved dynamic symbols remain unresolved. Controlled InstallMate 11 fixtures establish nested custom-folder and `INSTALLDIR` behavior.

## Current system-effect records

The following layouts are verified for current `tin9`, `tinA`, and `tinB` databases. They are not applied to older database generations merely because the same four-byte tag appears in arbitrary data.

```text
regk registry-key record
Offset  Size  Field
------  ----  -------------------------------------------------
0x00       8  "regk" + four NUL bytes
0x08       8  Registry-key object key
0x18       4  Observed remove-action word
0x1C       4  Observed fixed word
0x20       4  Observed fixed word
0x24     var  Localized key expression
...         4  Runtime registry-view code
...         4  Mirrored runtime registry-view code

regv registry-value record
Offset       Size  Field
-----------  ----  --------------------------------------------
0x00            8  "regv" + four NUL bytes
0x08            8  Registry-value object key
0x10            4  Component-reference count N
0x14          8*N  Component object keys
0x2C+8*N      var  Localized value name
...           var  Localized value data
...             4  Observed or reserved uint32
...             8  Parent regk object key
...             4  Registry value type code
...             4  Operation flags

evar environment record
Offset       Size  Field
-----------  ----  --------------------------------------------
0x00            8  "evar" + four NUL bytes
0x08            8  Environment object key
0x10            4  Component-reference count N
0x14          8*N  Component object keys
0x14+8*N        4  Install-action code
0x18+8*N        4  Negated remove-action code, int32 LE
0x1C+8*N        4  Reserved; observed zero
0x20+8*N        4  Keep-during-updates flag, 0 or 1
0x24+8*N        4  Current-user-only flag, 0 or 2
0x28+8*N        4  Separator Unicode scalar value, or zero
0x2C+8*N      var  Localized variable name
...           var  Localized value
```

Controlled one-option builds map project `RegView` values 0 through 4 to mirrored runtime codes 0, 2, 3, 4, and 5, corresponding to Existing key else Native, Native only, 64-bit then 32-bit, 64-bit only, and 32-bit only. The parser reports a fixed `RegistryView` only for the final two policies; native and fallback policies depend on the target system or existing key state. Registry projection emits a complete write only when the parent key, root hive, literal path, value type, and data can be resolved. A complete write becomes authoritative ARP or association evidence only when every referenced component resolves and none has a condition. Environment install-action codes 0 through 8 follow the builder's documented action order. Remove actions 0 through 4 compile as signed values 0 through -4 and mean Do not remove, Remove partial value, Remove if matched, Remove completely, and Restore original. Controlled checkbox and separator variants establish the remaining option words: `0x10000` in the project becomes keep-during-updates word 1, `0x2` becomes current-user-only word 2, and word 3 stores the separator as a Unicode scalar value.

```text
shct shortcut record
Offset       Size  Field
-----------  ----  --------------------------------------------
0x00            8  "shct" + four NUL bytes
0x08            8  Shortcut object key
0x10            4  Component-reference count N
0x14          8*N  Component object keys
0x24+8*N        8  Destination folder key
0x2C+8*N        8  Observed fixed fields
0x34+8*N      var  Localized title
...           var  Localized link name
...           var  Localized arguments
...           var  LP UTF-8 target path
...           var  LP UTF-8 working directory
...           var  LP UTF-8 icon path

a206 execution action
Offset  Size  Field
------  ----  -------------------------------------------------
0x00       8  "a206" + four NUL bytes
0x08       8  Action object key
0x24     var  LP UTF-8 internal name
...      var  LP UTF-8 condition
...      var  Localized action text
...        8  Observed fixed fields
...        4  Timeout in milliseconds
...     0x0C  Observed fixed fields
...      var  LP UTF-8 target path
...      var  LP UTF-8 working directory
...      var  LP UTF-8 arguments
...      var  LP UTF-8 shell verb
```

The parser resolves literal target, working-directory, icon, and destination-folder expressions through the same bounded symbol graph used for installed files. Component object keys are joined back to `cmp9` records for files, folders, registry values, environment changes, shortcuts, and services. Conditions are retained as source evidence; the parser does not execute actions or claim that a conditional action or component always runs.

```text
preh prerequisite group
Offset  Size  Field
------  ----  -------------------------------------------------
0x00       8  "preh" + four NUL bytes
0x08       8  Prerequisite object key
0x10     var  LP UTF-8 internal name
...        4  Linked-action count N
...      8*N  a206 action object keys
...        4  Observed option word 1
...        4  Administrator-rights requirement, 0 or 1
...        4  CPU support mask
...        4  Executable support mask
...        4  Executable match mode
...      var  LP UTF-8 condition

svc service record
Offset       Size  Field
-----------  ----  --------------------------------------------
0x00            8  ASCII "svc " followed by four NUL bytes
0x08            8  Service object key
0x10            4  Component-reference count N
0x14          8*N  Component object keys
0x24+8*N      var  LP UTF-8 internal service name
...           var  LP UTF-8 service arguments
...           var  Two LP UTF-8 observed or reserved strings
...             8  Target file object key
...             4  Target option word
...           var  LP UTF-8 load-order group
...           var  LP UTF-8 dependency list; U+001F delimited
...           var  LP UTF-8 service account or driver object name
...           var  LP UTF-8 account password
...             4  Win32 service type, uint32 LE
...             4  Win32 start type plus delayed-auto flag 0x10000
...             4  Win32 error-control value
...           var  Localized display name
...           var  Localized description
...           var  Localized recovery reboot message
...           var  LP UTF-8 recovery command
...             4  Failure-count reset period in seconds
...             4  Recovery-action count M
...           8*M  Recovery action and delay pairs, uint32 LE

svca service-control action
Offset       Size  Field
-----------  ----  --------------------------------------------
0x00            8  ASCII "svca" followed by four NUL bytes
0x08            8  Service-action object key
0x10            4  Component-reference count N
0x14          8*N  Component object keys
0x14+8*N     0x10  Four observed option words
0x24+8*N      var  LP UTF-8 service name
...           var  LP UTF-8 arguments
...             4  Install action bitmask, uint32 LE
...             4  Remove action bitmask, uint32 LE
```

Each service recovery entry is two uint32 values: action code followed by delay in milliseconds. Controlled projects map action codes 0 through 3 to Take no action, Restart the service, Restart the computer, and Run a program. Service type, start type, delayed automatic start, error control, LocalService and NetworkService account names, dependencies, load group, recovery command, localized reboot text, and recovery actions are all derived from independent builder variants. Controlled valid-driver builds establish that builder type 0 compiles to Win32 `SERVICE_FILE_SYSTEM_DRIVER` (`2`) and builder type 1 compiles to `SERVICE_KERNEL_DRIVER` (`1`); the parser reports the compiled Win32 value rather than the project index. The selected file object key is joined to the installed-file graph to produce the binary path. Account passwords are never returned; the parser exposes only `HasPassword`. Empty compiled account names cannot distinguish LocalSystem from a project that selected Other/Driver Name but supplied no name, so the parser reports `LocalSystemOrUnspecified`.

The project keyword for a service-control action is `svcctl`, while the compiled record tag is `svca`. Controlled one-action projects map runtime bitmasks `0`, `1`, `2`, `4`, `8`, and `0x20` to No action, Start service, Stop service, Resume service, Pause service, and Delete service. Install and remove fields use the same bitmask domain. Arguments are compiled as the length-prefixed string after the service name and apply to Start service. The four option words preceding the service name remain observed because no independent builder setting has changed them.

Prerequisite action keys are linked to decoded `a206` records without evaluating their conditions. Controlled projects differing only in the Prerequisite Handler's documented **Administrator rights required** checkbox map that setting to the second option word (`0` or `1`); the parser exposes it as `RequiresAdministrator`. This evidence does not by itself prove a WinGet `ElevationRequirement`, because the handler condition and the installer's silent elevation route still determine whether the prerequisite runs.

## Scope and ARP evidence

Legacy media uses the explicit uninstall hive when present; otherwise `AdminRights=1` is machine-scope evidence. Current controlled `tinB` media exposes `TsuInstallLevel` in the unique `inst\0\0\0\0` record at `+0x1B4`:

| Value | Runtime behavior |
| ---: | --- |
| 0 | all users without an access check |
| 1 | current user |
| 2 | all users when possible, otherwise current user |
| 3 | all users, with an interactive current-user fallback prompt |
| 4 | all users |
| 5 | administrator |

Older modern layouts retain scope from the PE requested-execution-level as fallback evidence because their install-record offset has not been mapped. `requireAdministrator` establishes machine scope, `asInvoker` establishes user scope, and `highestAvailable` remains elevation-dependent.

The built-in uninstall key is strong ARP identity evidence. Current literal custom registry records are decoded and can override the built-in ARP template or expose protocol and file-extension associations. Conditional, dynamically resolved, incomplete, or older-generation custom registrations remain diagnostics instead of being guessed.

## Bounds and failure behavior

Candidate scans are confined to 64 MiB of the logical overlay and exact `.tsustub`/`.tsuarch` section positions. Database bytes are limited to 128 MiB, record counts to 65,536, each payload segment to 16 GiB, and legacy Setup.ini to 4 MiB. Every declared range is checked before allocation or extraction. Sequential compressed streams are drained through bounded copies; caller-owned streams are not disposed by shared helpers.

Malformed headers, unsupported compression, ambiguous package archives, truncated records, impossible names, unknown file layouts, and output-limit violations fail closed. Unknown proprietary fields remain `Observed`, `Reserved`, or unresolved.

## Remaining gaps

- No fixture currently covers the `tin5` file-record revisions corresponding to physical word A 3 through 6.
- Current `tin9`, `tinA`, and `tinB` graph and system-effect layouts are decoded; corresponding `tin3` and `tin5` layouts remain generation-specific gaps.
- Only the current controlled `inst` record maps install-level values; older modern scope falls back to PE elevation evidence.
- The one-off Internet Archive samples outside the cached `tin2`, `tin3`, `tin5`, and `tin9` builder lineage were unavailable during this audit and are not claimed as covered.

## Source references

- [InstallMate setup command line](https://tarma.com/support/im9/setup/cmdline.htm)
- [InstallMate advanced build settings](https://tarma.com/support/im9/using/dialogs/build-advanced.htm)
- [InstallMate packaging](https://tarma.com/support/im11/using/packaging.htm)
- InstallMate 11 shipped help and the `TsuSymbolRules.imdata`, `Symbols.imdata`, and `StandardRegistry.imdata` builder data files
- [Internet Archive captures of `tin2.exe`](https://web.archive.org/web/*/http://www.tarma.com/download/tin2.exe)
- [Internet Archive captures of `tin3.exe`](https://web.archive.org/web/*/http://www.tarma.com/download/tin3.exe)
- [Internet Archive captures of `tin5.exe`](https://web.archive.org/web/*/http://www.tarma.com/download/tin5.exe)
- [Internet Archive capture of `tin9.114.exe`](https://web.archive.org/web/20230117131628/https://tarma.com/download/tin9.114.exe)
