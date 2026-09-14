# Setup Factory metadata model

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

Setup Factory 4 uses `CFileInfo` records beginning with the physical packed size and CRC, followed by a variable-length source path, split local timestamp, file-comparison values, destination, overwrite policy, shortcut settings, registration policy, and schema-dependent condition fields. Setup Factory 5 and 6 move the source and destination strings before the sizes and use one-byte strings. Version 5 separates records with a two-byte marker; version 6 stores that marker as part of each record.

```text
Setup Factory 4 CFileInfo
+0x00       4  PackedSize, uint32
+0x04       4  Expanded CRC32, uint32
+0x08       *  SourcePath, variable-length string
next        8  year:uint16, month/day/hour/minute/second/pad:uint8
next       16  four legacy file-comparison words, uint32[4]
next        4  ExpandedSize, uint32
next        1  OriginalAttributes
next        *  DestinationPath
next        1  OverwriteMode: 0 same-or-older, 1 older, 2 always, 3 never, 4 ask
next        1  CreateShortcut
next        *  ShortcutDescription, ShortcutLocation, Arguments, WorkingDirectory
next        4  IconIndex, uint32
next        4  ShortcutHotKey, uint32
next        4  ShortcutWindowMode, uint32
next        *  Components
next        1  RegisterTrueTypeFont
next        *  FontRegistryName
schema 1+   1  RegisterWithDllRegisterServer
schema 1+   1  StoreUncompressed; inverse of IsCompressed
schema 2    1  LegacyOperatingSystemMask; default 0x1F
schema 2    1  UseTrueVersion; read VS_FIXEDFILEINFO when true
schema 2    4  FileVersionMS; expected dwFileVersionMS
schema 2    4  FileVersionLS; expected dwFileVersionLS

Setup Factory 5/6 CFileInfo
+0x00     0|4  version 6 record prefix, absent in version 5
next        *  FullSourcePath, BaseName, SourceDirectory, suffix, RuntimeFolder
next        4  ExpandedSize, uint32
next        1  OriginalAttributes
next       12  creation, access, and modification time, uint32[3]
next        1  UseTrueVersion
next       24  product version, file version, and file date words
next        *  destination, overwrite, backup, protection, shortcut, icon, font, registration, in-use, compression, attributes, removal, shared-file, and condition fields
SF5         4  LegacyOperatingSystemMask, uint32; 0xFFFFFFFF accepts every supported OS
SF5         4  LegacyLanguageCondition, uint32; zero accepts every global language
SF5         *  ANDed LegacyAdvancedConditions, variable-length CConditionData records
SF6         *  runtime condition, install-type selector, and option-value list
tail        4  PackedSize, uint32
tail+4      4  Expanded CRC32, uint32
tail+8      1  StoreOnly
tail+9     32  builder bookkeeping words; word 4 supplies DisableCrcCheck
tail+41     *  four builder-side strings retained only for record alignment
```

The string historically labeled `StorageClass` is the builder's run-time folder. Values such as `Archive\qml\QtQuick` describe a folder inside the run-time archive and do not prove that a record is external or absent. The first source string is the complete source path; the following source-directory string is retained independently and must not be prepended to the complete path.

Version 7 introduces `CSetupFileData`. Its five-byte prefix belongs to every record. Version 8 moves those five bytes to the table header and expands sizes and timestamps to 64 bits. The validated 8.1, 9.0, and 9.1.0 media use ten destination-layout bytes, while 9.1.1, 9.2, and 9.5 use eleven. Version 10.2 adds a separate reserved byte immediately before the compression and attribute flags, and its object grows by the same change set observed in the 10.2.0.0 runtime. The parser selects these layouts by validating the complete table rather than by trusting the outer product version.

```text
Setup Factory 7 CSetupFileData
+0x00       4  Schema = 1, uint32
+0x04       1  FieldReference, Boolean
next        *  source path, base name, source directory, suffix, runtime folder, description
next        1  Recurse
next        1  MatchMode
next        4  ExpandedSize, uint32
next        1  OriginalAttributes
next       12  creation, access, and modification time, uint32[3]
next       25  true-version flag and product/file/date comparison words
next        *  DestinationPath
next       10  overwrite, backup, protection, and seven shortcut-location flags
next        *  shortcut location, comment, description, arguments, working directory, and icon path
next        4  IconIndex, uint32
next        1  ShortcutWindowMode
next        2  ShortcutHotKey, uint16
next        *  font and registration policy, attributes, CRC policy, install order, removal policy, conditions, build configurations, package selector, packages, and notes
tail        4  PackedSize, uint32
tail+4      4  Expanded CRC32, uint32
tail+8      1  StoreOnly

Setup Factory 8-10 CSetupFileData table
+0x00       5  table-wide observed prefix
next        *  repeated records

Setup Factory 8-10 record
+0x00       *  source path, base name, source directory, suffix, runtime folder, description
next        1  Recurse
next        1  MatchMode
next        8  ExpandedSize, int64
next        1  OriginalAttributes
next        4  CArchive int64 marker 0x8000000A
next        8  CreationTime, Unix seconds
next        4  CArchive int64 marker 0x8000000A
next        8  AccessTime, Unix seconds
next        4  CArchive int64 marker 0x8000000A
next        8  ModificationTime, Unix seconds
next        1  UseTrueVersion
next       24  product version, file version, and file date words
next        *  DestinationPath
next    10|11  overwrite, backup, protection, seven shortcut-location flags, and optional StartScreenPinning; 11-byte route begins at runtime 9.1.1
next        *  shortcut location, comment, description, arguments, and working directory
next        1  UseExternalIcon
next        *  IconPath
next        4  IconIndex, uint32
next        1  ShortcutWindowMode
next        2  ShortcutHotKey, uint16
SF10        *  AppUserModelID
next        *  font and registration policy, in-use handling, compression, attributes, CRC policy, install order, removal policy, conditions, build configurations, package selector, packages, and notes
tail        8  PackedSize, int64
tail+8      4  Expanded CRC32, uint32
tail+12     1  StoreOnly
```

Each `PayloadCatalog` record has a `Policy` object. `FilePolicySummary` groups entries that can prompt on overwrite, are conditionally installed, self-register code or type libraries, register fonts, suppress in-use notices, remain after uninstall, participate in shared-file accounting, create shortcuts, protect or back up an existing file, skip CRC checking, or are stored without normal installation. These values are installer behavior, not padding.

`OverwriteMode: 4` is especially relevant to unattended installation because an existing destination can open a prompt. `SuppressInUseNotice` can defer replacement until restart. `RegisterWithDllRegisterServer` and `RegisterTypeLibrary` make registry effects depend on code in the installed binary. The parser reports these cases with field-scoped diagnostics instead of changing manifest fields directly.

Setup Factory 4 schema 0 and 1 file policy is decoded. Schema 2 adds an OS eligibility mask followed by `UseTrueVersion`, `FileVersionMS`, and `FileVersionLS`. Runtime code calls `GetFileVersionInfoSize`, `GetFileVersionInfo`, and `VerQueryValue("\\")` only when `UseTrueVersion` is true, then compares the existing file's `VS_FIXEDFILEINFO.dwFileVersionMS` and `dwFileVersionLS` against those words; otherwise it uses the serialized file timestamp. The five OS bits represent Windows 3.1 or Win32s, Windows 95, Windows NT 3, Windows NT 4, and `Any OS`; `Any OS` makes the predicate unconditional. The preceding `Components` string is the independent package selector. `LegacyOperatingSystemPolicy` exposes the evaluated targets and ignored bits, while the version fields use the common policy properties.

Setup Factory 5 exposes its 32-bit `LegacyOperatingSystemMask`, `LegacyLanguageCondition`, package selector, and complete ANDed `LegacyAdvancedConditions`. The seven low OS bits correspond to Windows 95, Windows 98, Windows NT 3.51, Windows NT 4, Windows 2000, Windows ME, and Windows XP; higher bits are ignored by the runtime. Zero language accepts every global language, while a nonzero value must equal the runtime language selector. Every advanced condition expands both operands and applies one case-insensitive lexical comparison. Operator values are `0 Equals`, `1 GreaterThan`, `2 LessThan`, `3 GreaterThanOrEqual`, `4 LessThanOrEqual`, and `5 NotEqual`; an unknown value fails that condition. All rows must succeed. These decoded predicates remain scenario-dependent evidence and place the file in `ConditionalEntries`, but they no longer produce an unsupported-encoding diagnostic.

```text
Setup Factory 5 CConditionData
+0x00       *  LeftOperand, one-byte-length CString
next        *  RightOperand, one-byte-length CString
next        4  Operator, uint32; 0 through 5
next        4  Reserved builder/UI value, uint32
next        4  Reserved builder/UI value, uint32
next        *  Reserved builder/UI CString
next        *  Reserved builder/UI CString
```

The two reserved integers and strings are serialized by `CConditionData` but are not read by the runtime evaluator. They remain exact evidence because non-empty strings change record length. The common all-zero case occupies 14 bytes after the operands only because the two empty strings each consume a one-byte zero length; treating that observed size as a fixed suffix desynchronizes records whose builder metadata is non-empty.

## Metadata and system effects

Setup Factory 5 and 6 use the fixed product and built-in uninstall blocks described above. Modern `irsetup.dat` media exposes a bounded `CSessionVar` table. Each record stores a short name and value with generation-specific padding. The parser resolves only names present in the applicable generation, follows nested `%Variable%` references to a depth of 32, and rejects cycles or unknown variables.

`%ProductName%`, `%ProductVer%`, `%CompanyName%`, and `%AppFolder%` provide product metadata when they resolve. For Setup Factory 5 and 6, the enabled built-in uninstall route uses the stored `UniqueRegistryKey` and `ControlPanelDescription`. For modern media, the built-in route is accepted only when the compiled data contains the exact `%ProductName%%ProductVer%` key expression. Literal `Registry.SetValue` calls targeting `Software\Microsoft\Windows\CurrentVersion\Uninstall\<key>` provide more precise ARP evidence and take precedence over built-in defaults.

Registry writes outside the exact uninstall path remain registry or association evidence; they do not prove ARP visibility, ProductCode, or scope. An uninstall entry is visible only when it has a non-empty `DisplayName` and `SystemComponent` is not `1`. HKCU and HKLM entries remain separate, and mixed visible scopes do not collapse into one `Scope` or `ProductCode`.

Legacy and modern registry writes can also establish protocols and file extensions through the shared registry-association projector. Setup Factory 4 and 5 use their generation-specific typed `CRegistryData` records, Setup Factory 6 uses condition-resolved Modify Registry actions, and modern media uses literal Lua calls. The Lua string reader preserves ordinary Windows backslashes while decoding escaped quotes, backslashes, control escapes, and decimal byte escapes. Computed arguments, long-bracket strings, unsupported registry roots, runtime-dependent legacy conditions, external DLL calls, and dynamically assembled paths remain unresolved and produce field-scoped diagnostics. An unresolved call does not invalidate an independently proven built-in ProductCode or scope, but it can leave additional ARP entries, protocols, and file extensions incomplete.

Setup Factory 7 and earlier commonly stores project text in a Western Windows code page. Text decoding tries strict UTF-8 first and falls back to Windows-1252, which preserves legacy names such as `365dní`.
