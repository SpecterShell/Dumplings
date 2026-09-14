# Setup Factory binary format

## Setup Factory 3.1 media

Setup Factory 3.1 is multi-file media. `SETUP.EXE` is an MZ executable with an NE header and literal references to `\\IRDATA.IRD` and `IRSETUP.EXE`. Detection requires the launcher structure and a valid sibling archive, or a directly supplied valid `IRDATA.IRD`; strings alone are not sufficient.

```text
media directory
+-- SETUP.EXE
|   +-- DOS MZ header
|   +-- e_lfanew -> NE header
|   `-- runtime references to IRDATA.IRD and IRSETUP.EXE
+-- IRDATA.IRD
|   +-- IRDATA.DAT
|   +-- IRSETUP.EXE
|   +-- IRUNIN31.EXE
|   +-- OWNER.ARQ
|   `-- empty-name end record
`-- W31ENG.*, *.SF_, *.EX_, *.HL_, *.TX_, and other companion payloads
```

### Crusher ARQ framing

All integer fields are little-endian except where stated. Offsets returned by the parser are absolute within `IRDATA.IRD`.

```text
ARQ record
Offset  Size  Field
------  ----  ----------------------------------------------------------
0x00       4  Magic: 67 57 04 01
0x04       2  ArchiveVersion: 0x1230
0x06       2  NameLength, uint16
0x08       N  Name, Windows byte string
next       33  Descriptor
next        P  PackedData, PackedSize bytes

Descriptor
+0x00       1  FileMode, observed ASCII B
+0x01       1  FileAttributes, observed 0x20
+0x02       4  DOS date/time
+0x06       4  Reserved or runtime-owned
+0x0A       4  PackedSize, uint32
+0x0E       4  ExpandedSize, uint32
+0x12       4  Packed CRC32, uint32
+0x16       1  Method: 1 stored, 2 Crusher LH5
+0x17      10  Observed or runtime-owned fields

End record
0x00       4  Magic
0x04       2  ArchiveVersion
0x06       2  NameLength = 0
0x08      33  Runtime-owned descriptor template
0x29          End of file
```

The ARQ CRC covers the packed bytes. Stored records require equal packed and expanded sizes. Method 2 is an LH5-compatible bitstream with a 16 KiB history, four offset-low bits, 510 command symbols, canonical Huffman tables, and LZSS back-references. The parser validates the packed CRC before decompression and requires the decoder to consume only the bounded input range and produce the exact declared output size.

### IRDATA.DAT project header and product record

`IRDATA.DAT` is decoded from its ARQ record before project parsing.

```text
Project header
Offset  Size  Field
------  ----  ----------------------------------------------------------
0x00       4  Marker: 3A D0 00 7B
0x04       4  Signature: 0xABCD1234, uint32
0x08       2  FormatMajor = 3
0x0A       2  FormatMinor = 1
0x0C       2  FormatRevision
next        1  Closing marker: 7D

Product record
0x00       4  Marker: 3A D2 00 7B
next        *  SourceDirectory, duplicated-length string
next        *  ProductName, duplicated-length string
next        *  ProgramGroup, duplicated-length string
next        *  DefaultInstallLocation, duplicated-length string
next        *  SourceDrive, duplicated-length string
next        1  Closing marker: 7D

Duplicated-length string
+0x00       2  ByteLengthA, uint16
+0x02       2  ByteLengthB, uint16; must equal ByteLengthA
+0x04       N  Windows text bytes
```

The parser requires exactly one product record. The duplicated lengths, closing marker, format signature, and bounded strings prevent arbitrary text elsewhere in the data file from becoming package identity.

### Installed-file group

```text
Installed-file group
Offset  Size  Field
------  ----  ----------------------------------------------------------
0x00       4  Marker: 3A 01 80 7B
0x04       2  FileCount, uint16
0x06       *  FileRecord[FileCount]
next        1  Closing marker: 7D

FileRecord
+0x00       4  Marker: 3A C8 00 7B
next        *  ProjectSourcePath, duplicated-length string
next        *  InstalledName, duplicated-length string
next        4  DOS date/time
next        4  ExpandedSize, uint32
next        1  FileAttributes
next        1  CreateShortcut, Boolean
next        1  RecordFlags
next        *  ShortName, duplicated-length string
next       28  Policy bytes, retained without invented names
next        *  Description, duplicated-length string
next        *  MediaName, duplicated-length string
next        4  Expanded CRC32, uint32
next        4  PackedSize, uint32
next       22  Payload flags, retained without invented names
next        1  Closing marker: 7D
```

Each record maps one logical installed name to one sibling media file. Unlike ARQ records, the file-record CRC covers expanded bytes. A companion is available only when the catalog resolves one unique file and its physical length equals `PackedSize`.

Compressed companion files use a second Crusher profile: a 32 KiB history, five offset-low bits, and 511 command symbols. Stored companions have equal packed and expanded sizes. This profile difference is structural and must not be hidden behind a decoder fallback because accepting the wrong history or symbol count can produce plausible but corrupt output.

## Setup Factory 4-10 container layers

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

Setup Factory 4 and 5 serialize non-file commands as additional MFC object tables. Each table begins with a counted `CObList`, a first-object `FFFF` new-class declaration, schema 1, and the exact runtime class name. Later objects use one stable high-bit object reference. The first nested `CConditionData` object can itself use an existing high-bit class reference when an earlier table already declared the class; this reference is archive-global rather than local to the containing action table. Rejecting that form truncates otherwise valid later action records.

Setup Factory 4 `CINIData` is a compact predecessor to the version 5 action. The 4.0 builder media contains two records in the generated-uninstaller region that update `%AppDir%\irunin.ini`; runtime and media comparison establishes action code 1 as Set Value for this layout. Other action codes remain unnamed until a source-backed artifact or builder project establishes them.

```text
Setup Factory 4 CINIData
+0x00       1  Action; observed 1 = SetValue
next        *  FileName, variable string
next        *  Section, variable string
next        *  Key, variable string
next        *  Value, variable string
next        1  OperatingSystemMask; 1F selects every version-4 target
next        *  LanguageSelector, variable string
```

Setup Factory 5 `CExecuteData` matches the builder's Execute command page. The first three strings are target, command-line arguments, and working directory in that order. Action timing is independent of physical table placement for installation commands, while a table physically stored in the generated-uninstaller region is always uninstall behavior.

```text
Setup Factory 5 CExecuteData
+0x00       1  Action: 0 ExecuteProgram, 1 OpenDocument, 2 OpenUrl, 3 PrintDocument, 4 ExploreFolder, 5 PlayMultimedia
next        *  Target, variable string
next        *  CommandLineArguments, variable string
next        *  WorkingDirectory, variable string
next        1  WaitForProgram, Boolean
next        1  RunMode: 0 Normal, 1 Maximized, 2 Minimized
next        1  PromptForDisk, Boolean
next        *  DiskTitle, variable string
next        4  Timing: 0 Startup, 1 BeforeInstalling, 2 AfterInstalling, 3 Shutdown
next        1  Observed flag
next        4  OperatingSystemMask, uint32 LE
next        4  PackageSelector, uint32 LE
next        *  LanguageSelector, variable string
next        2  ConditionCount, uint16 LE
if nonzero  *  MFC CObList of CConditionData records
next       16  Four observed uint32 policy values
next        *  Four observed variable strings
```

`CFileOpData` covers operations separate from installed-file extraction. These actions can remove, relocate, or create paths at startup, before or after installation, at shutdown, or during uninstall. The prompt and error-suppression flags are behavior-relevant even when the target path is not a manifest field.

```text
Setup Factory 5 CFileOpData
+0x00       1  Action: 0 Copy, 1 Delete, 2 Move, 3 Rename, 4 MakeDirectory, 5 RemoveDirectory
next        *  Source, variable string
next        *  Destination, variable string
next        1  ConfirmWithUser, Boolean
next        1  SuppressErrors, Boolean
next        1  PromptForDisk, Boolean
next        *  DiskTitle, variable string
next        4  Timing: 0 Startup, 1 BeforeInstalling, 2 AfterInstalling, 3 Shutdown
next        4  OperatingSystemMask, uint32 LE
next        4  PackageSelector, uint32 LE
next        *  LanguageSelector, variable string
next        2  ConditionCount, uint16 LE
if nonzero  *  MFC CObList of CConditionData records
next       16  Four observed uint32 policy values
next        *  Four observed variable strings
```

The version 5 INI action adds existing-value policy and the same common conditions used by registry, execute, and file-operation records. The builder documentation names its three actions Add, Delete Key, and Delete Section; the runtime serializer establishes numeric order 0, 1, and 2, while the parser exposes action 0 as `SetValue` to describe the resulting system effect precisely.

```text
Setup Factory 5 CINIData
+0x00       1  Action: 0 SetValue/Add, 1 DeleteKey, 2 DeleteSection
next        *  FileName, variable string
next        *  Section, variable string
next        *  Key, variable string
next        *  Value, variable string
next        1  ExistingValueAction: 0 Overwrite, 1 DoNotOverwrite, 2 Prepend, 3 PrependIfMissing, 4 Append, 5 AppendIfMissing, 6 Increment, 7 Decrement
next        *  Separator, variable string
next        1  Flags
next        4  OperatingSystemMask, uint32 LE
next        4  PackageSelector, uint32 LE
next        *  LanguageSelector, variable string
next        2  ConditionCount, uint16 LE
if nonzero  *  MFC CObList of CConditionData records
next       16  Four observed uint32 policy values
next        *  Four observed variable strings
```

`CVarRegistry` reads a registry value into a Setup Factory variable before actions are evaluated. It can instead test key existence and return the configured default when no value is available. These records are runtime inputs, not writes, and must not be projected as ARP or association evidence.

```text
Setup Factory 5 CVarRegistry
+0x00       *  VariableName, variable string
next        1  Root: 0 HKCR, 1 HKCC, 2 HKCU, 3 HKLM, 4 HKU
next        *  Key, variable string
next        *  ValueName, variable string
next        1  UseKeyExistence, Boolean
next        *  DefaultValue, variable string
next       16  Four observed uint32 policy values
next        *  Four observed variable strings
```

The official 5.0.1.6 builder media provides complete production examples: two shutdown execution records guarded by `%ViewReadme%` and `%StartApp%`, six uninstall file operations, three HKCU-backed registry-variable reads, and four install-time registry writes. This gives an end-to-end alignment check across adjacent object tables rather than validating each record reader only against synthetic bytes.

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
member +0C  *  Primary file or target path for Execute, Open Document, Create Shortcut, and Call DLL Function
member +2C  *  Command-line arguments for Execute, Create Shortcut, Run File on Reboot, and Call DLL Function
member +30  *  Working directory for Execute, Open Document, and Create Shortcut
member +38  4  Registry operation for ActionId 17: 0 CreateKey, 1 DeleteKey, 2 SetValue, 3 DeleteValue
member +54  *  Boolean expression for ActionId 100 (IF) and 102 (WHILE)
member +58  *  Registry value name for ActionId 17
member +58  *  Assigned value for ActionId 14; source/file operand for several filesystem and reboot actions
member +5C  *  Target label for ActionId 104 and label name for ActionId 105
member +60  *  Variable name for ActionId 14 and other data-producing actions
member +68  *  Registry value data for ActionId 17
member +74  *  Registry subkey for ActionId 17
member +78  4  Registry root enum for ActionId 17
member +90  4  Registry type for ActionId 17: 1 SZ, 2 EXPAND_SZ, 3 BINARY, 4 DWORD, 7 MULTI_SZ
```

The source-backed action vocabulary is grouped below. Action identity is complete for the 6.0 runtime; named operand projection is deliberately narrower than identity because unrelated action types reuse the same generic object members.

| IDs | Builder action names |
| --- | --- |
| 0-6 | Latest Version, Download (FTP), HTTP Download, Execute, Open Document, Unzip Files, Close Program |
| 7-14 | Copy Files, Delete Files, Rename File, Create Directory, Remove Directory, Read from Registry, Read from INI File, Assign Value |
| 17-29 | Modify Registry, Modify INI File, Submit to Web, Show Message Box, Read File Association, Abort Setup, Send Email, Upload File FTP, Show Yes/No Dialog, Read File Information |
| 30-39 | Find String, Mid String, Left String, Right String, Length of String, Move Files, Read Text File, Write to Text File, Generate Random Value, Zip Files |
| 42-56 | Count/Delete/Find/Get/Insert Text Line, Create/Remove Shortcut, Install File, Register File, Register Font, Check Internet Connection, Set File Attributes |
| 57-63 | Stop, Pause, Continue, Delete, Query, Start, and Create Service |
| 70-80 | Count/Get Delimited String, Parse Path, Search for File, Move/Delete/Run File on Reboot, Call DLL Function, Format Number, Write to Log File, Get Disk Space |
| 100-105 | IF, END IF, WHILE, END WHILE, GOTO Label, Label |
| 200-201 | Comment, Blank line |

`Read-SetupFactoryActionRecord6` returns `ActionName`, `Category`, `ProjectionStatus`, the complete generic `Fields`, and source-backed `Details` for Execute, Open Document, Read from Registry, Assign Value, Modify Registry, Show Yes/No Dialog, Create Shortcut, reboot file actions, Call DLL Function, IF/WHILE, GOTO/Label, and comments. `Get-SetupFactoryActionCatalog6` attaches `Phase`, `ConditionState`, and condition evidence, and groups effects under `VariableAssignments`, `ExecutionActions`, `UserInteractionActions`, `InstallabilityActions`, `ShortcutActions`, `ServiceActions`, `RebootActions`, `ExternalCodeActions`, and `UnknownActions`.

Setup Factory expressions use both textual `AND`, `OR`, and `NOT` and symbolic operators, and wrap runtime variables as `%Name%`. The parser normalizes that Boolean surface syntax before using the shared three-valued evaluator. Literal Boolean Assign Value actions reached on a proven path feed later conditions. Comparisons, arithmetic, functions, host state, loops with runtime bounds, and conditional jumps remain unresolved rather than being executed. The 6.0.1.4 builder fixture contains 136 actions across five lists: its constant-false outer action block is now rejected deterministically, two evaluation registry writes under `TRUE` are projected, five commercial writes under `!TRUE` and two uninstall delete actions remain catalog evidence, and only one runtime-dependent uninstall loop remains unresolved.

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
