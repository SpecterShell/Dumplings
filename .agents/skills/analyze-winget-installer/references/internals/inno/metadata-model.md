# Inno Setup metadata model

The setup-data model is a header followed by counted arrays of declarative entries. The compiler and setup engine share the same record declarations. This page describes the current logical model; [format history](format-history.md) covers fields added or removed in older layouts.

## `TSetupHeader`

The setup header combines package identity, runtime directives, counts, UI settings, privilege and architecture behavior, compression, and compiled code.

### Identity and support strings

Current string fields include:

```text
AppName                  AppVerName
AppId                    AppVersion
AppCopyright             AppPublisher
AppPublisherURL          AppSupportPhone
AppSupportURL            AppUpdatesURL
AppReadmeFile            AppContact
AppComments              AppModifyPath
```

These are compiled forms of `[Setup]` directives. Most can contain runtime constants. `AppId` is especially important because it identifies previous installation data, the built-in uninstall key, and upgrade continuity.

### Installation locations and shell presentation

```text
DefaultDirName           DefaultGroupName
BaseFilename             UninstallFilesDir
UninstallDisplayName     UninstallDisplayIcon
```

`DefaultDirName` is an expression, not a final path. The setup engine expands constants after scope and 64-bit install mode are known. Wizard state or `/DIR=` can override the chosen directory.

### Synchronization, associations, and change declarations

```text
AppMutex                 SetupMutex
CloseApplicationsFilter  CloseApplicationsFilterExcludes
ChangesEnvironment       ChangesAssociations
```

Mutex directives can prevent setup or uninstall while application instances are running. `ChangesEnvironment` and `ChangesAssociations` tell setup to broadcast system notifications and record equivalent uninstall behavior. They do not enumerate every actual change.

### Previous-install preferences

```text
UsePreviousAppDir        UsePreviousGroup
UsePreviousSetupType     UsePreviousTasks
UsePreviousUserInfo      shUsePreviousLanguage
shUsePreviousPrivileges
```

The setup engine reads prior values from the built-in uninstall key for the effective AppId, scope, and registry view. These options can make the next installation differ from compiled defaults.

### Uninstall directives

```text
CreateUninstallRegKey    Uninstallable
UninstallLogMode         UninstallFilesDir
UninstallDisplayName     UninstallDisplayIcon
UninstallDisplaySize
```

`CreateUninstallRegKey` and `Uninstallable` are expression-capable strings in current formats. A package can create an uninstaller without registering it in ARP, register custom uninstall data through code, or disable the built-in mechanism entirely.

### Architecture and privilege directives

```text
ArchitecturesAllowed
ArchitecturesInstallIn64BitMode
PrivilegesRequired
PrivilegesRequiredOverridesAllowed
```

Current architecture directives are expression strings evaluated against runtime architecture identifiers. Privilege overrides are a set containing command-line and/or dialog support.

### Counts

The current header stores 17 table counts:

```text
Language          CustomMessage      Permission
Type              Component          Task
Dir               ISSigKey           File
FileLocation      Icon               Ini
Registry          InstallDelete      UninstallDelete
Run               UninstallRun
```

These counts define the record stream. There is no table directory containing byte offsets.

### Compiled code and text resources

```text
LicenseText
InfoBeforeText
InfoAfterText
CompiledCodeText
CompiledCodeVersion
```

The first three are ANSI byte strings in the serialized current structure even though the running setup engine exposes Unicode strings. `CompiledCodeText` contains compiled Pascal Script, not source code. The high bit of `CompiledCodeVersion` identifies 64-bit code execution in current compiler logic.

### Fixed settings

The packed non-string header tail also includes:

- minimum and upper-bound Windows versions;
- wizard dimensions, colors, image behavior, and dark-style settings;
- additional disk-space requirement;
- slices per disk;
- uninstall-log mode;
- directory-existence warning mode;
- language selection mode;
- compression method;
- page-disable modes;
- header option flags.

## Shared selector fields

Most install-entry records contain some combination of:

```text
Components
Tasks
Languages
Check or CheckOnce
MinVersion
OnlyBelowVersion
BeforeInstall
AfterInstall
```

These fields are evaluated at runtime. The compiler stores selector text rather than expanding it into every possible install scenario.

`Components`, `Tasks`, and `Languages` use Inno's selector syntax, including negation and hierarchical names. Version fields are packed Windows-version structures. `Check` and callbacks name Pascal Script functions or expressions according to the directive.

## Language entries

`TSetupLanguageEntry` stores:

- internal language name and display name;
- dialog and welcome fonts with size/scaling information;
- right-to-left state and language ID;
- compiled message data;
- language-specific license and before/after information text.

SetupLdr reads enough setup-0 data to choose a language before launching the setup engine. The setup engine activates the language again, then uses its messages for the wizard and generated uninstaller message file.

## Custom messages and permissions

`TSetupCustomMessageEntry` maps a message name/value to a language index.

`TSetupPermissionEntry` stores encoded grant entries in an ANSI byte string. Other records reference a permission entry by `Smallint` index. Current permission data supports a bounded number of SID/access-mask grants.

## Types, components, and tasks

### Types

`TSetupTypeEntry` represents a setup type such as full, compact, or custom. It contains name, description, language/check selectors, version bounds, type flags, and an internally calculated size.

### Components

`TSetupComponentEntry` represents a hierarchical feature. It includes names, type membership, language/check selectors, extra disk space, nesting level, and flags such as fixed, exclusive, restart, and inheritance behavior.

### Tasks

`TSetupTaskEntry` represents an optional action selected independently from components. It includes component/language/check selectors and flags such as unchecked, checked-once, exclusive, restart, and inheritance behavior.

Types choose an initial component set. Components and tasks then gate later records.

## Directory entries

`TSetupDirEntry` contains:

```text
DirName
Components / Tasks / Languages / Check
AfterInstall / BeforeInstall
Attribs
MinVersion / OnlyBelowVersion
PermissionsEntry
Options
```

Options can control uninstall retention, delete-after-install behavior, and NTFS compression. Directory constants are expanded only after install mode is established.

## Signature-key entries

`TSetupISSigKeyEntry` stores public-key coordinates and a runtime ID used by Inno's file-signature verification. File entries can refer to allowed key IDs and a signature source.

This mechanism is independent from Authenticode signing of `Setup.exe`.

## File entries

The current `TSetupFileEntry` includes:

```text
SourceFilename            DestName
InstallFontName           StrongAssemblyName
Components                Tasks
Languages                 Check
AfterInstall              BeforeInstall
Excludes                  DownloadISSigSource
DownloadUserName          DownloadPassword
ExtractArchivePassword
```

Its fixed tail contains:

- verification type and SHA-256/signature evidence;
- version bounds;
- `LocationEntry` index;
- destination attributes;
- external size;
- permission index;
- per-entry bitness;
- many copy/uninstall/registration options;
- file type, including the generated uninstaller executable.

Important options cover overwrite/version policy, restart replacement, delete-after-install, COM/type-library registration, shared-file counts, external/download/archive behavior, GAC installation, and uninstall retention.

The source filename is useful compiler/debug evidence. Runtime installation primarily uses destination behavior and the linked file location.

## File-location entries

`TSetupFileLocationEntry` is the physical payload index:

```text
FirstSlice / LastSlice
StartOffset
ChunkSuboffset
OriginalSize
ChunkCompressedSize
SHA256Sum
TimeStamp
FileVersionMS / FileVersionLS
Flags
```

Current flags identify valid version information, UTC timestamps, CALL-instruction optimization, encryption, and compression.

The logical file entry and physical location are separate because several logical destinations can share payload bytes, and one solid chunk can contain many files.

## Icon entries

`TSetupIconEntry` describes Start Menu, desktop, and other shell links:

```text
IconName                 Filename
Parameters               WorkingDir
IconFilename             Comment
Components / Tasks / Languages / Check
AfterInstall / BeforeInstall
AppUserModelID
AppUserModelToastActivatorCLSID
IconIndex / ShowCmd / HotKey
CloseOnExit / Options
```

Shell links can be conditional and can use `useapppaths`, pinning, toast-activator, and uninstall-retention options.

## INI entries

`TSetupIniEntry` stores filename, section, entry, value, selectors, callbacks, version bounds, and options. Options determine whether missing keys are created and which entry/section cleanup operation is recorded for uninstall.

## Registry entries

`TSetupRegistryEntry` stores:

```text
Subkey                    ValueName
ValueData                 Components / Tasks / Languages / Check
AfterInstall / BeforeInstall
MinVersion / OnlyBelowVersion
RootKey                   PermissionsEntry
Typ                       Bitness
Options
```

Types include none, string, expandable string, DWORD, binary, multi-string, and QWORD. Entry bitness selects registry view independently from the process. Options govern create-if-absent, preservation, deletion, uninstall deletion, errors, and whether to create the key.

The root can be a fixed hive or Inno's install-mode-sensitive automatic root. The actual HKCU/HKLM choice may therefore depend on privilege mode.

## Delete entries

`TSetupDeleteEntry` is used by both `[InstallDelete]` and `[UninstallDelete]`. It stores a path expression, common selectors/callbacks, version bounds, and one of:

- files;
- files and/or subdirectories;
- directory if empty.

Install-delete entries execute near the beginning of installation. Uninstall-delete entries are recorded into the uninstall log for later replay.

## Run entries

`TSetupRunEntry` is shared by `[Run]` and `[UninstallRun]`:

```text
Name / Parameters / WorkingDir
RunOnceId / StatusMsg / Verb / Description
Components / Tasks / Languages / Check
AfterInstall / BeforeInstall / OnLog
MinVersion / OnlyBelowVersion
ShowCmd / Wait / Bitness / Options
```

Options cover shell execution, missing-file behavior, post-install presentation, silent/non-silent filtering, wizard visibility, original-user execution, parameter logging, and output capture.

## Non-table resources after entries

Compressed block 1 continues after `UninstallRun[]` with:

- wizard image lists;
- small wizard images;
- background images;
- dynamic-dark variants, which can reference the normal images when identical;
- embedded decompressor DLL data for legacy compression methods;
- optional 7-Zip decoder library data.

A reader that stops at the final run entry has parsed all declarative records but not necessarily consumed the complete metadata block.

## Source references

- [Shared.Struct.pas](https://github.com/jrsoftware/issrc/blob/main/Projects/Src/Shared.Struct.pas)
- [Shared.SetupTypes.pas](https://github.com/jrsoftware/issrc/blob/main/Projects/Src/Shared.SetupTypes.pas)
- [Shared.SetupEntFunc.pas](https://github.com/jrsoftware/issrc/blob/main/Projects/Src/Shared.SetupEntFunc.pas)
