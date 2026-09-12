# InstallBuilder internals

This reference describes the installer structures and runtime behavior needed to maintain the parser. Use the [InstallBuilder workflow](../../families/installbuilder/workflow.md) for package analysis and manifest authoring.

Read [binary notation](../../parser-development/binary-notation.md), [parser contracts](../../parser-development/contracts.md), and [performance guidance](../../parser-development/performance.md) before changing the implementation.

## Product lineage

The same Windows installer family has appeared under BitRock InstallBuilder, VMware InstallBuilder, InstallBuilder, and Backstaff InstallBuilder branding. Branding and builder editions do not select the parser route. A release may preserve an older container or compression choice, and third-party installers generally do not expose an authoritative builder version. Dispatch from validated physical structures and report project schema, PE version, and branding as separate evidence.

The changelog establishes several useful feature boundaries: payload encryption was introduced in 8.2, the newer compression system and LZMA-ultra appeared in 9.0, native Windows x64 runtimes appeared in 19.5, the VMware name was removed in favor of InstallBuilder in 20.2, and Backstaff branding appeared in 23.1. These boundaries constrain interpretation but do not prove that every installer built by a later release enabled the feature.

## Container routes

### Legacy Metakit route

Verified 3.6.0 and 3.7.0 builder media, plus an archived installer whose recovered project identifies itself as 4.5.3, use a PE/TclKit launcher with a Metakit VFS. The project and installed payload are stored in Metakit-owned records; `project.xml` is a bounded zlib stream, but there is no CookFS `CFS0002` footer.

```text
PE image, commonly UPX-packed
`-- appended TclKit/Metakit VFS
    +-- Metakit header: "JL\x1A\x00" or "LJ\x1A\x00"
    +-- column and data records
    |   +-- names including project.xml
    |   +-- zlib-compressed project.xml
    |   `-- zlib-compressed payload records
    `-- commit records and root descriptor at the Metakit logical end
```

Metadata recovery retains a bounded RFC 1950 candidate fallback, but payload cataloging uses the Metakit root descriptor and the exact TclKit schema `dirs[name:S,parent:I,files[name:S,size:I,date:I,contents:B]]`. The root `origindist` file identifies the payload directory, while `manifest.txt` independently records the packaged distribution paths. The parser follows directory parent indices and byte-column ownership, then projects only files below `origindist`; Tcl/Tk runtime files elsewhere in the same VFS are excluded. Compiled project folder destinations map those physical records to logical extraction paths.

### CookFS2 route

Verified JXplorer 3.3.1.2 and InstallBuilder 8.2.0, 9.5.5, 23.1.0, and 26.8.0 media use a Metakit-backed launcher plus a CookFS2 payload. JXplorer's package version is not evidence of the builder version. The project XML and CookFS are independent records: metadata can remain usable when payload decoding is unsupported. The 8.2.0 builder contains two valid Metakit VFS records; only one owns `project.xml`, so route selection validates required-entry ownership instead of taking the first physical VFS.

```text
PE/TclKit launcher
+-- Metakit VFS
|   `-- bounded zlib project.xml
`-- CookFS payload ending at CFS0002
    +-- compressed page records
    +-- opaque page metadata                 PageCount * 16 bytes
    +-- stored page-size table               PageCount * uint32 BE
    +-- stored file index                    IndexSize bytes
    +-- 16-byte footer fields
    `-- 43 46 53 30 30 30 32                "CFS0002"
```

Authenticode data or launcher records may follow other logical structures, so the parser locates and validates candidate logical endings instead of assuming the physical file end is the container end.

## Metakit boundary records

The parser first validates the Metakit boundary, then reads only the schema-specific columns needed by the TclKit VFS. All Metakit positions are relative to the database header; physical reads add `HeaderOffset` after validating the range against `Distance`.

```text
Metakit-header-relative offset  Size  Meaning
------------------------------  ----  ----------------------------------------------
0x00                               2  "JL" or "LJ" byte-order signature
0x02                               1  0x1A
0x03                               1  0x00 storage style used by observed media
0x04                               4  distance to logical database end, uint32 BE
...
EndOffset - 0x10                   8  first commit mark
EndOffset - 0x08                   1  0x80 second/root commit mark
EndOffset - 0x07                   3  root descriptor length, uint24 BE
EndOffset - 0x04                   4  root descriptor position, uint32 BE
```

`HeaderOffset + Distance` defines the logical end. The root position and length must remain within that declared extent. The `JL` and `LJ` signatures describe Metakit byte order; the distance and terminal root fields consumed here are encoded as shown above. Candidate records with impossible extents, missing `0x80`, zero roots, or out-of-range roots are rejected.

The first terminal record must also be a valid skip mark. This prevents an incidental `JL` marker and arbitrary trailing `0x80` bytes from being accepted as a database.

## Metakit root and column descriptors

Metakit stores unsigned and signed descriptor integers as one to six base-128 bytes, most-significant group first, with bit 7 set on the final byte. A leading zero complements the decoded value and represents negative numbers such as the root directory's parent `-1`. Every persisted column location is encoded as `Size` followed by `Position` when `Size` is nonzero; a zero-sized column omits `Position`.

```text
Root descriptor, root-position relative
+----------------------+-----------------------------------------------+
| FormatCode           | adaptive integer; 0 in supported media        |
+----------------------+-----------------------------------------------+
| SchemaLength         | adaptive integer                              |
+----------------------+-----------------------------------------------+
| Schema UTF-8         | dirs[name:S,parent:I,files[...]]               |
+----------------------+-----------------------------------------------+
| RootRowCount         | adaptive integer; exactly 1                    |
+----------------------+-----------------------------------------------+
| DirectoryView.Size   | adaptive integer                              |
+----------------------+-----------------------------------------------+
| DirectoryView.Pos    | adaptive integer, Metakit-header-relative     |
+----------------------+-----------------------------------------------+
```

The directory view has one row per directory. `name:S` is a Metakit byte column interpreted as UTF-8 strings, `parent:I` is an adaptive signed-integer column, and `files:V` points to concatenated child-view descriptors. The root row is named `<root>` and has parent `-1`; every other parent index must resolve inside the directory table without cycles.

```text
Directory sequence
+----------------------+-----------------------------------------------+
| FormatCode = 0       | adaptive integer                              |
+----------------------+-----------------------------------------------+
| DirectoryCount       | adaptive integer, bounded                     |
+----------------------+-----------------------------------------------+
| name byte column     | Data, SizeVector, MemoVector locations        |
+----------------------+-----------------------------------------------+
| parent int column    | one location; width derived from rows/bytes   |
+----------------------+-----------------------------------------------+
| files view column    | one location containing child descriptors     |
+----------------------+-----------------------------------------------+
```

Each nonempty `files` child view repeats the schema-specific column sequence `name:S`, `size:I`, `date:I`, and `contents:B`. Empty child views contain only format code zero and row count zero. Integer columns use 0, 1, 2, 4, 8, 16, or 32 bits per row; sub-byte values are packed least-significant slot first, while multi-byte values follow the `JL` or `LJ` byte order.

Metakit `S` and `B` values share a byte-column representation. Inline data is concatenated in one data column and split by an adaptive integer size vector. Large values are stored as memos: the memo vector contains adaptive row deltas followed by separate `Size,Position` locations. The parser reconstructs every row range and requires inline sizes to cover the data column exactly.

```text
contents:B row
+----------------------+-----------------------------------------------+
| Catalog size:I       | logical expanded file size                    |
+----------------------+-----------------------------------------------+
| Byte-column range    | stored bytes, inline or memo-owned            |
+----------------------+-----------------------------------------------+
| StoredSize == Size   | bytes are stored verbatim                     |
+----------------------+-----------------------------------------------+
| StoredSize != Size   | valid RFC 1950 zlib member required            |
+----------------------+-----------------------------------------------+
```

Extraction streams the owned range and requires the final expanded byte count to equal `size:I`. Unknown framing, truncated columns, malformed memo deltas, invalid UTF-8 path components, path traversal, duplicate logical destinations, and configured limits fail without searching for a replacement blob elsewhere in the executable.

## Project record

`project.xml` is stored as an RFC 1950 zlib stream in the TclKit VFS. The primary route resolves the exact catalog-owned `project.xml` record through the Metakit schema, which proves ownership and avoids unrelated compressed members. A bounded candidate scanner remains only as a fallback for incomplete or synthetic evidence without a readable Metakit catalog. InstallBuilder uses CMF `0x78`; that fallback searches complete valid no-dictionary CMF/FLG pairs (`78 01`, `78 5E`, `78 9C`, and `78 DA`) rather than every `0x78` byte. This matters for old UPX/TclKit launchers containing thousands of unrelated `0x78` bytes before the real project stream.

The decompressed document must be bounded, valid UTF-8, parse as XML, have a `project` document element, and contain InstallBuilder project fields. Candidate order does not confer authority. The fallback validates each candidate and returns the first structurally valid project record.

Important project values include identity (`shortName`, `fullName`, `version`, and `vendor`), `projectSchemaVersion`, `installationType`, `createUninstaller`, `createWindowsARPEntry`, `windowsARPRegistryPrefix`, `productDisplayName`, `requireInstallationByRootUser`, `requestedExecutionLevel`, `windows64bitMode`, `allowedInstallationModes`, parameters, components, folders, shortcuts, action lists, and literal registry writes. Elements may store values as child text or same-named attributes; both encodings occur in compiled projects. `${...}` substitutions are recursively resolved only from deterministic project and PE evidence. The parser supplies manifest-safe values for the stable Windows folder variables documented by the builder, including Program Files, Common Files, Windows and System32, AppData and LocalAppData, ProgramData, the user profile, desktop, Documents, media folders, Start Menu and Startup folders, administrative tools, templates, recent items, Send To, and network or printer shortcuts. The paths retain `%SystemRoot%`, `%APPDATA%`, `%LOCALAPPDATA%`, `%ProgramData%`, `%PUBLIC%`, and `%USERPROFILE%` instead of embedding values from the analysis host. Host-state folders whose actual locations are not safely represented by those variables, including Internet cache and history, remain unresolved. Tcl expressions, runtime state, and unknown variables also stay unresolved.

Rules belong to actions, folders, components, and enclosing action groups. The static evaluator propagates inherited `ruleList` conditions and the sibling `conditionRuleList` used by `if` and `while` action lists. Builder manuals extracted from 3.7.0, 4.5.3, 7.2.5, and 16.1.0 describe a stable portable subset: `isTrue` and `isFalse` recognize `1`, `yes`, and `true`; `compareText` supports equals, inequality, contains, and does-not-contain with optional case folding; `compareTextLength` and `compareValues` support equality and ordered comparisons; `compareVersions` compares resolved version values; `platformTest` distinguishes Windows from non-Windows targets; and `regExMatch` applies matches or does-not-match. The parser evaluates these with three-valued `True`, `False`, or `Unknown` results, bounded regular-expression execution, negation, nested rule groups, and all/any list logic. Numeric `compareValues` operands compare numerically, while other values compare ordinally. Tcl-specific regular-expression syntax remains unknown because .NET regular expressions cannot be assumed equivalent. An x86 launcher does not prove a 32-bit target host, and version-specific Windows tests depend on the future target machine, so those platform rules remain unknown unless the launcher itself constrains the answer. Unknown rules keep their XML evidence and prevent affected registry or association values from becoming authoritative.

## CookFS2 footer

Offsets in this section are relative to the byte immediately after the `CFS0002` marker.

```text
Offset  Size  Meaning
------  ----  ----------------------------------------------------
-0x10      4  stored file-index size, uint32 BE
-0x0C      4  page count, uint32 BE
-0x08      1  stored file-index compression identifier
-0x07      7  observed footer fields not interpreted by this parser
 0x00      7  magic "CFS0002" immediately before the logical end
```

The index starts `16 + IndexSize + PageCount * 20` bytes before the marker end. The parser treats the first `PageCount * 16` bytes in that region as opaque page metadata, reads the following `PageCount * 4` bytes as big-endian stored page sizes, and derives each page-data offset by walking backward from the metadata boundary. The sum of stored page sizes must land exactly on that boundary.

## Stored records and compression

Every stored page and the stored file index begins with a one-byte handler identifier.

```text
Handler  Stored layout                                      Expanded form
-------  -------------------------------------------------  --------------------------
0        00 | bytes                                         bytes
1        01 | raw-Deflate stream                            Deflate output
2        02 | four observed prefix bytes | BZip2 stream     BZip2 output
255      FF | LZMA properties | dict | size | LZMA stream   LZMA-alone-style output
```

For handler 255, the parser accepts only the source-backed unencrypted `lzmadec` shape: one property byte, a little-endian dictionary size, an eight-byte little-endian expected output length, and compressed data. Dictionary and output sizes are bounded before allocation. Other custom handlers, `tcltwofish`, and encrypted payload markers are not decoded without the project password.

The expanded index starts with `CFS2.200` and contains recursive directory nodes:

```text
Node-relative field             Encoding
------------------------------  --------------------------------------------
ItemCount                       uint32 BE
NameLength                      uint8
Name                            UTF-8 bytes
Terminator                      0x00
ModificationTime                8 bytes, retained only as skipped metadata
BlockCount                      uint32 BE; 0xFFFFFFFF means child directory
Block[BlockCount].Page          uint32 BE
Block[BlockCount].Offset        uint32 BE
Block[BlockCount].Length        uint32 BE
```

Names are validated as individual path components before recursion. File blocks must reference an existing page and remain within its expanded bounds. Physical CookFS paths commonly begin with compiled component and folder names; the parser maps those prefixes through project folder destinations and classifies the default selection from component `selected`, folder/component platform lists, and inherited rules. Unmapped or runtime-dependent entries remain conditional, and ambiguous destinations stay under a safe `_destinations` namespace instead of being guessed. InstallBuilder splits large files into a base entry followed by `___bitrockBigFile1`, `___bitrockBigFile2`, and later segments; extraction exposes and reconstructs the logical base path.

## ARP and scope behavior

The documented project defaults model a normal installation with an uninstaller and Windows ARP entry enabled. The built-in ARP route is active only when `installationType` is `normal`, `createUninstaller` is true, and `createWindowsARPEntry` is true. It writes an HKLM uninstall key named by `windowsARPRegistryPrefix`, default `${project.fullName} ${project.version}`, and uses `productDisplayName`, default `${product_fullname}`, for `DisplayName`. The built-in row also writes the configured publisher, version, icon, install location, information URL, comments, contact, help link, and a quoted uninstaller path, with `NoModify=1` and `NoRepair=1`; it omits `SystemComponent`, which makes the row visible. `EstimatedSize` and `InstallDate` are computed at installation time and cannot be reproduced exactly from the package catalog alone.

Unconditional literal `registrySet` actions targeting HKLM or HKCU uninstall paths are separate authoritative evidence only when they belong to a persistent installation phase. Each raw write records its enclosing action-list `Phase` and normalized `Lifecycle` plus raw and deterministically resolved key/value forms. Association projection consumes the resolved form, while unresolved runtime substitutions remain diagnostics. Initialization, presentation, rollback, failure, uninstallation, and unknown-phase writes remain available for analysis but cannot define the successful installed state. Duplicate built-in and custom entries are deduplicated by hive, view, and key. A nonzero numeric `SystemComponent` hides an entry; hidden and condition-dependent rows remain evidence but do not become WinGet `ProductCode` or `AppsAndFeaturesEntries`. Upgrade-mode projects may locate and update a prior registration; the absence of a new literal key is not permission to invent one.

`requireInstallationByRootUser`, the PE requested execution level, HKLM/HKCU registry actions, and built-in ARP behavior jointly establish scope. `installationScope` is unrelated: it selects whether Start Menu and desktop shortcuts belong to the current user or all users. `windows64bitMode` selects the 64-bit Program Files and registry view even with an x86 launcher. A native x64 launcher also selects the 64-bit view. Payload architecture remains independent from launcher architecture.

A controlled current 26.8 x64 installation using `--mode unattended --prefix <INSTALLPATH>` exited 0 and wrote the predicted HKLM 64-bit uninstall key. `DisplayName`, `DisplayVersion`, `Publisher`, `DisplayIcon`, `InstallLocation`, `UrlInfoAbout`, `HelpLink`, the quoted `UninstallString`, `NoModify=1`, and `NoRepair=1` matched the compiled project after substituting the requested prefix. `SystemComponent` was absent. `EstimatedSize` and `InstallDate` were added at runtime, confirming that static parsing must leave them unresolved. Running the generated uninstaller with `--mode unattended` exited 0 and removed both the ARP key and installed directory.

## Actions, nested payloads, and shortcuts

`ProjectActions` records every compiled leaf action with its XML `LocalName`, phase, lifecycle, scalar parameters, deterministically resolved values, inherited condition state, and unresolved variables. `LocalName` is required because PowerShell's XML adapter can otherwise return a child or attribute named `name` in place of the element name. Password-like scalar properties are replaced by `<redacted>` and listed under `SensitiveProperties`; normalized service and scheduled-task records expose only `PasswordConfigured`. Specialized `runProgram` records carry program, arguments, working directory, and payload ownership. Installer-like programs executed during persistent installation phases are reported as nested candidates because they may own ARP or switch behavior. Programs attached to presentation phases such as `finalPageActionList` are application launches and are kept separate. Shortcuts retain resolved target, arguments, working directory, icon, location, conditions, and packaged-payload ownership; the project-level `installationScope` applies to their ownership. `PrimaryExecutableCandidates` combines embedded executable shortcut targets with installation and final-page executable actions so callers can selectively extract binaries for architecture and dependency analysis.

`DynamicProjectLogic` is the handoff boundary for logic outside the bounded evaluator. It never translates project expressions into PowerShell or runs Tcl. Each record retains the exact `SourceCode`, its owning XML element and property, phase and lifecycle, affected manifest fields, and referenced variable evidence. Deterministic context variables are labeled `DeterministicProjectContext`; parameter values are labeled `ParameterDefault` and remain `IsRuntimeMutable` because command-line input or UI can replace them; values assigned by `setInstallerVariable` retain the assigning phase and condition state; names without static values are labeled `RuntimeOrUnknown`. Unknown rule records preserve the complete rule XML because rewriting Tcl or InstallBuilder rule syntax would lose semantics. Script properties preserve the packaged script reference or expression supplied by the project, not the contents of an external payload file. Password, passphrase, secret, token, credential, and private-key properties are redacted before this evidence is returned.

`associateWindowsFileExtension` writes one ProgID for a space-separated list of extensions. Its compiled properties are `extensions`, `progID`, `icon`, `scope` (`system` by default or `user`), `mimeType`, `friendlyName`, and a `commandList`; each command has `verb`, `runProgram`, and `runProgramArguments`. The parser normalizes these into `FileExtensionAssociations` and admits an extension into the authoritative `FileExtensions` list only when the extension text resolves and its installation-phase action is true. Unresolved optional command, icon, or description values remain diagnostics without erasing proven registration. Registry-authored and action-authored associations stay distinguishable in `AssociationInfo`.

Persistent environment actions are `addEnvironmentVariable`, `deleteEnvironmentVariable`, `addDirectoryToPath`, and `removeDirectoryFromPath`; their default scope is `system`, and user-scoped environment actions may name a specific user. `addDirectoryToPath.insertAt` is retained even though the builder documentation states that placement is Unix-only. `setEnvironmentVariable` changes the current installer process only and cannot describe installed state. Windows service actions are normalized from `createWindowsService`, `deleteWindowsService`, `startWindowsService`, `stopWindowsService`, and `restartWindowsService`. Create records preserve service name, display name, description, executable, arguments, start type (default `auto`), account (default `LocalSystem`), dependency names, and abort-on-error behavior. Start, stop, and restart records preserve their documented wait delay, default 15000 milliseconds. Password text is intentionally not returned in the normalized service record; `PasswordConfigured` records only its presence.

The same phase-aware system-effect projection covers `addScheduledTask` and `deleteScheduledTask`, `addFonts` and `removeFonts`, `addSharedDLL` and `removeSharedDLL`, and `setWindowsACL` and `clearWindowsACL`. Scheduled-task records preserve the documented trigger, executable, arguments, working directory, account, privilege, date, interval, duration, and battery settings; a task password is reduced to `PasswordConfigured`. Omitted task values use the builder defaults `DAILY`, day and period `1`, execution limit `72` hours, and battery blocking enabled. Font records retain include and exclude patterns, shared-DLL records retain the reference-counted path, and ACL records retain patterns, principals, permissions, owner, access direction, and recursion flags. These actions are documented in the recovered 7.2.5, 16.1.0, and 26.8.0 manuals; font and shared-DLL actions also occur in the recovered 4.5.3 manual. Every specialized record keeps lifecycle, condition state, unresolved variables, and `AppliesToInstalledState`, while `ProjectActions` remains the lossless generic view.

`autodetectJava` actions are structured runtime requirement evidence. Each accepted version row retains minimum and maximum versions, vendor, bitness, and whether a JDK rather than a JRE is required. `compareVersions` rules involving `${windows_os_version_number}` are retained as Windows-version constraints because the target host version is unknown during static parsing. Requirement evidence is not automatically converted into a package dependency.

## Command-line behavior

The runtime accepts `--mode unattended` only when `allowedInstallationModes` is empty or explicitly contains `unattended`. A nonempty allowlist containing only `unattended` excludes interactive mode; a list without `unattended` excludes both silent modes. CookFS-era projects expose `unattendedModeUI`, so the parser uses `--mode unattended --unattendedmodeui none` for silent installation and `--mode unattended --unattendedmodeui minimal` for progress, overriding a compiled `minimal` or `minimalWithDialogs` default. Recovered 3.x and 4.x Metakit-only manuals document unattended mode but not `unattendedModeUI`; those runtimes expose `--mode unattended` as silent mode and do not receive a progress-mode claim. The `installdir` parameter normally maps to `--prefix`; custom parameters can define `cliOptionName`, and the runtime falls back to the parameter name when it is omitted. `--debugtrace` supplies a log path. Rules, license pages, validation expressions, and action lists can still constrain these otherwise recognized options.

## Format catalog

- 3.6.0 and 3.7.0 builder media: verified legacy Metakit-only route, 317 VFS records, 88 projected payload files, stored and zlib `contents` records, project schema 1.2, x86 launcher, and no CookFS footer.
- Archived media replayed from a nominal 4.2.0 URL: the recovered project identifies itself as 4.5.3 and verifies a 380-record legacy VFS with 107 projected payload files. Catalog artifacts by recovered identity rather than archived filename.
- JXplorer 3.3.1.2: verified third-party CookFS2 route with stored and Deflate pages, 32-bit mode, and no explicit project schema value. Its package version does not identify the InstallBuilder release.
- 7.2.5 builder media: verified CookFS2/LZMA route with a single project-owning Metakit VFS; no new physical handler was required.
- 8.2.0 enterprise builder media: verified CookFS2/LZMA route with two valid Metakit VFS records. Required-entry ownership selects the project VFS and prevents metadata from being taken from the unrelated runtime VFS. Version 8.2 is also the changelog boundary for encrypted payload support; this is not proof that a given 8.2-or-later payload is encrypted.
- 9.0: changelog boundary for the newer compression system and LZMA-ultra.
- 9.5.5 builder media: verified CookFS2 route with the unencrypted custom LZMA record and BitRock branding.
- 16.1.0 builder media: verified the same unencrypted CookFS2/LZMA structural route; it is retained as research evidence rather than a redundant routine fixture.
- 19.5: changelog boundary for native Windows x64 runtime support; older Windows installers may still install 64-bit payloads through an x86 runtime and `windows64bitMode`.
- 20.2: changelog branding boundary from VMware InstallBuilder to InstallBuilder.
- 23.1.0 builder media: verified CookFS2/LZMA route with Backstaff branding and a 32-bit launcher.
- 26.8.0 x64 builder media: verified current CookFS2/LZMA route with a native x64 launcher and 64-bit registry view.

Static extraction of the recovered 3.7.0, 4.5.3, 7.2.5, 8.2.0, 9.5.5, 16.1.0, 23.1.0, and 26.8.0 builder payloads produced 15 distinct Windows runtime templates. Their builders remain TclKit/Metakit applications and package Windows runtime template PEs under `paks/windows*.pak`; recovered generated installers still reduce to the two physical media routes above. The templates change packing, bitness, branding, and supported project vocabulary, but do not justify a third container parser. Builder Tcl files use TclPro bytecode and are research evidence rather than runtime parser dependencies.

Historical 2.6.1 and 5.x media have not been recovered as valid installer binaries. Additional captures should be promoted to persistent regression fixtures only when they expose a structure or behavior not represented by the catalog above.

## Detection invariants

Accept the family only after the PE and project record validate and at least one InstallBuilder container relationship is coherent. `CFS0002`, Metakit signatures, branding, option strings, and `project.xml` names are individual evidence, not sufficient detection by themselves. Keep project, Metakit, and CookFS parsing independent so a malformed payload cannot erase valid metadata evidence and a stray marker cannot validate an unrelated PE.

## Bounds and performance

Bound candidate counts, project expansion, Metakit extents, CookFS page counts and sizes, expanded index size, recursion, entry count, LZMA dictionary size, cache bytes, total output, and extraction paths. The parser opens one caller-owned installer stream for a CookFS extraction and keeps a small FIFO page cache because multiple logical files can share CookFS pages. It never mounts TclKit, executes Tcl, loads the installer, or materializes the complete installer in memory.

Primary executable analysis is opt-in. It reuses the already parsed logical catalog and CookFS layout, selects no more than four default-install executables proven by shortcut or execution-action references, adds at most 64 adjacent DLL or .NET sidecar candidates per executable, enforces one aggregate byte budget, and extracts only those records into a temporary directory. PE architecture and dependency helpers inspect the materialized selection before the directory is removed. Conditional or excluded payloads are never promoted into default target architecture evidence.

## Remaining gaps

- Encrypted CookFS pages and unknown custom handlers require the project password. The parser reports the limitation without exposing or guessing secrets.
- Arbitrary Tcl expressions, scripts, external program side effects, and rule types outside the bounded static subset cannot be reduced safely. `DynamicProjectLogic` exposes their exact source, referenced variables, known values, owner, phase, and affected fields for direct agent analysis; preserve unresolved outcomes and validate their effects in a VM rather than executing the source on the host.
- Native file associations, persistent environment variables, PATH changes, Windows services, scheduled tasks, fonts, shared-DLL reference counts, and Windows ACL changes have normalized projections. Other action families remain available as generic `ProjectActions`; normalize another family only when its compiled properties and installed-state semantics are established from source or builder documentation.
- Exact builder release identity is usually unavailable in third-party media. Project schema, runtime PE metadata, structural route, and product branding must remain separate evidence.
- The archived 2.6.1 URL resolves to 3.7.0 media, and the available 5.4.15 download captures are HTML or redirects to later releases rather than installer binaries. Treat those versions as unavailable historical evidence, not active download gaps and not proof of an unsupported format; a structurally compatible installer should continue through content-based routing.

## Implementation mapping

- `Modules/PackageModule/Libraries/Installers/InstallBuilder.psm1`
- `Modules/PackageModule/Assets/Source/InstallBuilder/InstallBuilderMetakitReader.cs`

## Source references

- [InstallBuilder downloads](https://installbuilder.com/download-step-2)
- [InstallBuilder changelog](https://installbuilder.com/changelog)
- [InstallBuilder project settings](https://releases.installbuilder.com/installbuilder/docs/installbuilder-userguide/project.html)
- [InstallBuilder Windows behavior](https://releases.installbuilder.com/installbuilder/docs/installbuilder-userguide/_windows.html)
- [InstallBuilder installer modes](https://releases.installbuilder.com/installbuilder/docs/installbuilder-userguide/_user_interface.html)
- [InstallBuilder user-input and command-line options](https://releases.installbuilder.com/installbuilder/docs/installbuilder-userguide/userinput.html)
- [InstallBuilder rules](https://releases.installbuilder.com/installbuilder/docs/installbuilder-userguide/_rules.html)
- [InstallBuilder actions](https://releases.installbuilder.com/installbuilder/docs/installbuilder-userguide/action.html)
- [InstallBuilder file associations](https://releases.installbuilder.com/installbuilder/docs/installbuilder-userguide/_file_associations.html)
- [InstallBuilder built-in variables](https://releases.installbuilder.com/installbuilder/docs/installbuilder-userguide/variables.html)
- [Metakit file format](https://www.equi4.com/metakit/metakit-ff.html)
- [Metakit format overview](https://www.equi4.com/metakit/format.html)
- [Archived InstallBuilder 3.7.0 media](https://web.archive.org/web/20060511074856id_/http://www.bitrock.com/installbuilder-3.7.0-windows-installer.exe)
- [Archived nominal 4.2.0 media](https://web.archive.org/web/20070816175458id_/http://www.bitrock.com/installbuilder-enterprise-4.2.0-windows-installer.exe)
- [MIT CookFS extraction research](https://github.com/vpetrigo/bitrock-unpacker)
- [Legacy InstallBuilder loader research](https://gist.github.com/mickael9/0b902da7c13207d1b86e)
- [Password-protected InstallBuilder extraction research](https://gist.github.com/NyaMisty/3d3b9a39fca463ca9e16628e96877b5c)
