# Inno uninstaller and Apps & Features registration

Inno Setup builds uninstall support during installation. The generated uninstaller is a copy of the setup engine paired with an uninstall log and, when needed, a message sidecar. The log is both a record of installed state and an ordered program for reversing it.

## Uninstall identities

Several identifiers are involved:

| Value | Purpose |
| --- | --- |
| `AppId` | Logical application identity supplied by the setup author. It also controls upgrade continuity. |
| uninstall-key base name | Normalized form of expanded `AppId`. |
| ProductCode seen by WinGet | Full registry subkey name, normally `<base>_is1`. |
| `uninsNNN` base filename | Collision-free filename selected for the uninstaller files in one installation directory. |
| uninstall-log ID | Binary identity that distinguishes supported log format and 32/64-bit setup engine. |

`AppId` is an Inno string, not an MSI GUID requirement. Braces commonly appear because authors use GUID-shaped values, but ordinary names are valid.

## AppId normalization

Setup expands `AppId`, then obtains the uninstall-key base name. The current normalization preserves normal values. If the ASCII-safe representation exceeds the supported base length, Setup keeps an initial prefix and appends `~` plus an eight-character lowercase CRC32. The resulting key is:

```text
Software\Microsoft\Windows\CurrentVersion\Uninstall\<base>_is1
```

The `_is1` suffix is Inno's built-in uninstall-key convention. It is not appended to a custom key written by a `[Registry]` entry or Pascal Script.

The literal-brace escape from setup syntax is also relevant. `AppId={{A2CA...}` represents a single literal opening brace after constant expansion. The doubled source brace is not part of the registry key.

## Root key and registry view

The built-in key uses:

```text
root = InstallModeRootKey
view = InstallDefaultRegView
```

Administrative install mode selects HKLM; non-administrative mode selects HKCU. A 64-bit installation mode normally selects the 64-bit registry view, while a 32-bit mode uses the 32-bit view. HKCU uninstall state is shared differently by Windows than the two HKLM views, so Setup handles opposite-view checks accordingly.

Before creating the new key, Setup deletes an existing key with the same identity in the selected root/view. It can inspect the opposite scope and view for the same application identity. Current Inno versions may add localized scope or bitness marks to `DisplayName` when otherwise identical visible entries would coexist.

## When the built-in ARP key exists

The key is created only when all relevant conditions pass:

```text
Uninstallable evaluates true
AND installation reaches uninstall-info finalization
AND CreateUninstallRegKey evaluates true
```

`Uninstallable` and `CreateUninstallRegKey` can use directive checks backed by Pascal Script. A setup can copy files but intentionally omit the built-in uninstaller or ARP key.

An author can also create a custom ARP entry through `[Registry]` or Pascal Script. That entry does not inherit Inno's default key name, values, root, view, or visibility.

## Built-in values

Current Setup writes implementation-state values whose names begin with `Inno Setup:`. These record setup version, app path, icon group, user, language, setup type, component/task selection, and optional user information.

It then writes Windows ARP values:

| Value | Source and behavior |
| --- | --- |
| `DisplayName` | Expanded `UninstallDisplayName`, or expanded `AppVerName`; capped at 259 characters and possibly marked to distinguish scope/bitness. |
| `DisplayIcon` | Expanded `UninstallDisplayIcon`, omitted when empty. |
| `UninstallString` | Quoted generated uninstaller path, plus `/LOG` when uninstall logging is enabled. |
| `QuietUninstallString` | Same path with `/SILENT`, plus `/LOG` when enabled. |
| `DisplayVersion` | Expanded `AppVersion`, omitted when empty. |
| `Publisher` | Expanded `AppPublisher`, omitted when empty. |
| `URLInfoAbout` | Expanded `AppPublisherURL`. |
| `HelpTelephone` | Expanded `AppSupportPhone`. |
| `HelpLink` | Expanded `AppSupportURL`. |
| `URLUpdateInfo` | Expanded `AppUpdatesURL`. |
| `Readme`, `Contact`, `Comments` | Expanded matching setup directives. |
| `ModifyPath` | Expanded `AppModifyPath`; otherwise `NoModify=1`. |
| `NoRepair` | Always `1` for the built-in entry. |
| `InstallDate` | Current install date in the format expected by ARP. |
| version DWORDs | Major/minor parts extracted from expanded `AppVersion` when possible. |
| `EstimatedSize` | Explicit `UninstallDisplaySize`, or selected installed file sizes plus extra disk-space requirements, converted to KiB. |

`InstallLocation` is written from the selected application directory when `CreateAppDir` is enabled. The stored path has a trailing backslash. The uninstall log records deletion of the complete ARP key.

After standard values are written, Setup invokes `RegisterPreviousData`. Script code can add application-specific values under the same key through `SetPreviousData`. Such values are available to a later setup through the previous-data API.

## Uninstaller files

The usual output in `UninstallFilesDir` is:

```text
uninsNNN.exe   generated setup engine in uninstall mode
uninsNNN.dat   uninstall log and replay records
uninsNNN.msg   bound messages when required by signing/detached-message behavior
```

`NNN` is selected by enumerating existing `unins???.*` files. Setup can append to or overwrite a compatible existing uninstall log according to the configured uninstall-log mode and existing file state. Otherwise it allocates another number.

The executable may first be written to a temporary name when an existing uninstaller is being replaced, then renamed after file operations make replacement safe. Current filename generation also considers `AppId` when preparing the uninstaller image so unrelated products do not appear to share a byte-identical generic `unins*.exe`.

## Uninstall log layout

The current header is deliberately kept at or below 512 bytes so it can be written atomically within one disk sector.

```text
TUninstallLogHeader
+----------------------+------------------------------------------+
| ID                   | format and 32/64-bit engine identity     |
| AppId[128]           | bounded encoded application identity     |
| AppName[128]         | bounded encoded display identity         |
| Version              | uninstall-log format revision            |
| NumRecs              | record count                              |
| EndOffset            | end of valid data                         |
| Flags                | scope, mode, restart, environment state   |
| reserved fields      | compatibility space                       |
| CRC32                | header integrity                          |
+----------------------+------------------------------------------+
```

After the fixed header, the log is a sequence of CRC-framed blocks. Each block holds up to 4096 bytes of the serialized record stream:

```text
+----------------------+ 0
| Size                 | uint32 bytes in this block
+----------------------+ 4
| NotSize              | bitwise complement of Size
+----------------------+ 8
| CRC32                | checksum of Data
+----------------------+ 12
| Data                 | up to 4096 record-stream bytes
+----------------------+
```

Records are packed into that stream and may cross a block boundary:

```text
+----------------------+ 0
| Typ                  | uint16 record type
+----------------------+ 2
| ExtraData            | uint32 type-specific flags/data
+----------------------+ 6
| DataSize             | uint32 payload byte count
+----------------------+ 10
| Data                 | encoded string fields or custom bytes
+----------------------+
```

The in-memory linked-list pointers in `TUninstallRec` are not serialized. On-disk records use `TUninstallFileRec` followed by payload data; integrity belongs to the surrounding 4096-byte block stream rather than each record.

## Record types

Built-in records include:

- start/end installation markers;
- compiled Pascal Script and expanded uninstall state;
- run commands;
- file and directory deletion;
- Start Menu group/item deletion;
- INI entry and section deletion;
- registry key/value deletion and restoration-oriented actions;
- shared-file count decrement;
- file-association/environment refresh;
- mutex checks.

`ExtraData` stores flags such as registry view, file bitness, shared-file behavior, registration kind, wait behavior, and whether a file existed before setup. Inno reserves `utUserDefined` for private extensions; assigning new numeric built-in record types would risk future incompatibility.

## Recording inverse operations

Setup adds log entries as it applies installation changes. The records describe the action needed at uninstall time, not a copy of the original setup entry.

Examples:

- creating a new file records its removal;
- replacing an existing file can preserve state needed to avoid deleting a pre-existing file incorrectly;
- creating a registry value records delete, clear, or key cleanup behavior according to flags and prior state;
- creating an icon records both modern and legacy filename variants where required;
- `[UninstallRun]` and `[UninstallDelete]` are inserted in reverse construction order so reverse log traversal executes them in authored order.

This log is also used for installation rollback. It cannot automatically reverse arbitrary side effects performed by an external program or an opaque DLL.

## Upgrade modes

The uninstall-log update setting can create a new log, append to a compatible log, or overwrite it. Appending preserves records from previous installations so the eventual uninstall removes state accumulated across upgrades. Compatibility checks include log identity, format version, application identity, and relevant install-mode flags.

The latest compatible compiled-code record for the current setup-engine version is used by the uninstaller. This avoids feeding bytecode produced for one embedded script-engine version to an incompatible uninstaller.

## Uninstaller startup

The visible `uninsNNN.exe` does not perform destructive work in place. It validates the paired `.dat`, checks required privileges and mutexes, copies itself to a protected temporary directory as `_unins.tmp`, and starts that copy. The temporary process performs uninstallation so the original executable and directory can be removed.

The uninstaller:

1. validates the header and record CRCs;
2. restores install mode, architecture mode, identity, and restart flags;
3. locates compatible compiled Pascal Script and loads uninstall events;
4. confirms the operation unless silent behavior suppresses the prompt;
5. replays records in reverse logical order and in phase-aware passes;
6. handles shared files, registrations, files, registry, directories, and run actions;
7. invokes uninstall script events;
8. removes the original uninstall files and signals temporary-process completion.

Multiple passes are required because registrations and shared-file decisions must occur before some files disappear, while directory cleanup must occur after their contents have been removed.

## Silent uninstall

The built-in quiet ARP command uses `/SILENT`, not `/VERYSILENT`. An authored uninstaller can still present custom script UI, execute child processes, or require handling that the standard switch does not suppress. `/SUPPRESSMSGBOXES` has the same dependency on silent mode as setup.

## Source references

- [Setup.Install.pas](https://github.com/jrsoftware/issrc/blob/main/Projects/Src/Setup.Install.pas)
- [Setup.MainFunc.pas](https://github.com/jrsoftware/issrc/blob/main/Projects/Src/Setup.MainFunc.pas)
- [Setup.UninstallLog.pas](https://github.com/jrsoftware/issrc/blob/main/Projects/Src/Setup.UninstallLog.pas)
- [Setup.Uninstall.pas](https://github.com/jrsoftware/issrc/blob/main/Projects/Src/Setup.Uninstall.pas)
- [Inno Setup uninstall directives](https://jrsoftware.org/ishelp/topic_setup_uninstallable.htm)
