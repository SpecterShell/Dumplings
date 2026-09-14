# Setup Factory workflow

## When to use

Use `InstallerType: exe # Setup Factory` when content-based analysis identifies an Indigo Rose Setup Factory single-file installer. Dumplings also recognizes Setup Factory 3.1 multi-file media when `SETUP.EXE` and `IRDATA.IRD` are supplied with their companion payload files. It extracts SF3.1 Crusher catalogs, extracts outer catalogs from Setup Factory 4 through 10, parses generation-specific metadata and uninstall behavior, and never executes the installer.

## Detection

Setup Factory 3.1 uses a 16-bit MZ/NE `SETUP.EXE`, a sibling Crusher archive named `IRDATA.IRD`, and independent compressed companion files. Detection validates both the launcher references and the complete ARQ and `IRDATA.DAT` framing; a filename or marker string is insufficient. Setup Factory 4 begins its PE overlay with `E0 E1 E2 E3 E4 E5 E6`, followed by a one-byte entry count. Versions 5 through 7 use `E0 E1 E2 E3 E4 E5 E6 E7`; versions 8 through 10 use `E0 E0 E1 E1 ... E7 E7`. The single signature is ambiguous without validated catalog framing and trusted runtime evidence, so do not classify a file from those eight bytes or from `Setup Factory`, `Indigo Rose`, or `IRSetup` strings alone.

Read [Setup Factory internals](../../internals/setup-factory/overview.md) before changing detection, extraction, binary decoding, or parser limits.

## Manifest shape

Setup Factory has no WinGet-native installer type or default switches, so the manifest uses generic `exe`. Add only switches and fields proved for the exact artifact.

```yaml
Installers:
- Architecture: x64
  InstallerType: exe # Setup Factory
  InstallerUrl: https://example.com/Product-1.2.3-x64.exe
  InstallerSha256: <SHA256>
  ProductCode: <ProductCode>
```

Add `InstallModes: [interactive, silent]` and `InstallerSwitches.Silent: /S` only when `$Info.SupportsSilentInstallation` is true. Use `InstallModes: [interactive]` when it is false. Setup Factory 3.1, 4, and 5 are interactive-only. A null result indicates malformed, conflicting, or unsupported project data; do not add either field until the artifact is validated.

## Static parsing

### 1. Parse the installer once

```powershell
$Info = Get-SetupFactoryInfo -Path C:\Path\To\Setup.exe # SETUP.EXE or IRDATA.IRD for version 3.1
$Info | Select-Object DisplayName, DisplayVersion, Publisher, ProductCode, Scope, DefaultInstallLocation, WritesAppsAndFeaturesEntry, SupportsSilentInstallation, StartsInSilentMode, InstallerSwitches, InstallModes, ParserVersionInfo, Diagnostics, UnresolvedFields
```

Reuse `$Info` for the remaining steps. Do not call individual readers after `Get-SetupFactoryInfo`.

### 2. Route by structural profile

Inspect `$Info.ParserVersionInfo.ProfileId`, `FormatGeneration`, `BuilderVersion`, `EmbeddedRuntimeVersion`, and `HeaderPrefixLength`. `EmbeddedRuntimeInfo` exposes the decoded runtime's trusted version-resource identity and the structural profiles compatible with that identity.

- `setup-factory-3.1-multifile` validates the MZ/NE launcher, the Crusher ARQ records in `IRDATA.IRD`, the 3.1.0 project header, duplicated-length product strings, installed-file records, sibling media sizes, and both compression profiles. `DisplayName` and `DefaultInstallLocation` are available. The verified project record has no separate application version, publisher, Windows scope, or Apps & Features identity. `ContainerEntries` lists the four ARQ members and `PayloadCatalog` maps 15 logical installed paths to their companion files in the historical builder media.
- `setup-factory-4` decodes the source-backed `CGeneralData`, `CConclusionData`, `CUninInfo`, `CRegistryData`, `CINIData`, and `CFileInfo` routes. Its built-in Control Panel description and unique uninstall key are authoritative only when `IncludeUninstall` is true; version, publisher, and default install directory are absent from these global objects and remain unresolved. Do not fill those fields from the launcher's PE version resource. Version 4 INI action code 1 is source-backed as Set Value; unnamed action codes remain unresolved.
- `setup-factory-5` and `setup-factory-6` decode their fixed product block and built-in uninstall settings. Version 5 also decodes complete `CRegistryData`, `CExecuteData`, `CFileOpData`, `CINIData`, `CVarRegistry`, and nested `CConditionData` lists. It projects a registry write only when the common selectors are unconditional and the advanced-condition list is empty, while runtime-dependent execution and file effects remain catalog evidence with `ConditionState: Unknown`. Version 6 reconstructs counted action lists, assigns every source-backed action name and category, resolves the Boolean subset of its control flow, projects Modify Registry actions only when their install-time condition resolves true, and groups assignment, execution, interaction, shortcut, service, reboot, and external-code evidence under `ActionEffects`. Inspect the catalog and diagnostics before treating built-in ARP as the only system effect.
- `setup-factory-7` supports both observed runtime prefixes. A prefix length of 8 or 9 is a structural result, not an error.
- `setup-factory-8-plus` covers the shared observed archive profile used by Setup Factory 8, 9, and 10. The installed-file records have three validated revisions: Setup Factory 8.1 and 9.0 use ten destination-layout bytes, 9.1 through 9.5 use eleven, and 10.2 additionally uses a one-byte compression prefix. The parser selects a revision only after validating the complete table and payload ranges. Use `BuilderVersion` only when `BuilderVersionSource` is present.

Stop if detection is rejected or catalog validation throws. A marker-only match is not enough to continue as Setup Factory.

### 3. Review product metadata

Use `DisplayName`, `DisplayVersion`, `Publisher`, and `DefaultInstallLocation` only when the parser resolves them from the Setup Factory 3.1 product record, the Setup Factory 4 built-in uninstall identity, the Setup Factory 5/6 product block, modern `CSessionVar` records, or a more specific deterministic uninstall-key write. `ProductMetadata` exposes the decoded project block for review. Values in `UnresolvedFields` require another source or VM evidence.

Version 4 returns `SetupFactory.Metadata.Classic4ProductFieldsUnavailable` for metadata that the format does not store in its decoded global objects. Versions 4 through 6 return `SetupFactory.Metadata.LegacyRegistryActionsPartial` when a counted registry table is structurally malformed and `SetupFactory.Metadata.LegacyActionsPartial` when another decoded command table is incomplete. Well-formed runtime-dependent conditions stay in `LegacyActionCatalog` with `ConditionState: Unknown` and produce field-scoped diagnostics instead of invalidating the catalog. Version 5 uses `SetupFactory.Metadata.RegistryActionsUnresolved` for registry writes whose conditions are not statically true; version 6 also uses it for unsupported registry-action control flow or conditions. Built-in product and uninstall values remain valid independently of those diagnostics.

### 4. Establish ARP ownership

Inspect `RegistryArpEntries`, `WritesAppsAndFeaturesEntry`, `ProductCode`, and `AppsAndFeaturesEntries` together.

Setup Factory 4 through 6 store the built-in uninstall enable flag, Control Panel display expression, and unique registry key directly; `UninstallConfiguration` exposes those fields, and the enable flag gates ARP projection. Modern media derives its built-in key from the exact `%ProductName%%ProductVer%` expression. Exact condition-resolved legacy writes or literal modern writes under `Software\Microsoft\Windows\CurrentVersion\Uninstall\<key>` take precedence. Registry actions outside that path may establish protocols or file associations, but they do not establish ProductCode, ARP visibility, or scope.

Setup Factory 3.1 targets Windows 3.1 Program Manager and predates the Windows Add/Remove Programs contract. `IRUNIN31.EXE` is an uninstall runtime, not ProductCode evidence. Do not derive an Apps & Features entry from its filename, product name, or program group.

Hidden entries remain evidence with `IsVisible: false`; do not project them as the visible package owner. If more than one visible custom uninstall entry exists, retain the individual entries and do not invent one installer-level ProductCode.

### 5. Inspect associations, prerequisites, and payload records

```powershell
$Info.RegistryAssociationInfo
$Info.Protocols
$Info.FileExtensions
$Info.LegacyActionCatalog | Select-Object IsPresent, IsComplete, Error, UnresolvedCount
$Info.LegacyActionCatalog.Entries | Select-Object Offset, Phase, Action, ActionId, ActionName, Category, ProjectionStatus, ConditionState, Details
$Info.ActionEffects
$Info.ExecutionActions | Select-Object Phase, ActionName, Target, Arguments, WorkingDirectory, ConditionState, Conditions, Details
$Info.FileSystemActions | Select-Object Phase, ActionName, Source, Destination, ConfirmWithUser, SuppressErrors, ConditionState, Conditions
$Info.IniActions | Select-Object Phase, ActionName, FileName, Section, Key, Value, ExistingValueActionName, ConditionState, Conditions
$Info.VariableReads | Select-Object VariableName, Root, Key, ValueName, UseKeyExistence, DefaultValue
$Info.VariableAssignments | Select-Object Phase, ConditionState, Details
$Info.ContainerEntries | Select-Object Name, Kind, PackedSize, Crc32
$Info.DependencyPayloads | Select-Object Name, SourcePath, Label, PackedSize, ExpandedSize
$Info.PayloadCatalog | Select-Object Name, DestinationPath, Condition, InstallType, Packages, Policy, IsEmbedded, PackedSize, ExpandedSize, Crc32
$Info.FilePolicySummary
$Info.InstalledFileCatalog | Select-Object IsComplete, CanExtract, CanExtractPartial, ExtractableEntryCount, UnavailableEntryCount, DestinationPolicyLength, HasAppUserModelID

Expand-SetupFactoryInstaller -Path C:\Path\To\Setup.exe -DestinationPath C:\Temp\SetupFactory -Name '*.exe' -CollisionAction Rename
Expand-SetupFactoryInstaller -Path C:\Path\To\Setup.exe -DestinationPath C:\Temp\SetupFactoryRaw -Name 'irsetup.*' -RawEntries -CollisionAction Rename
# Version 3.1 accepts SETUP.EXE or IRDATA.IRD and resolves payloads from the same directory.
Expand-SetupFactoryInstaller -Path C:\Path\To\SF31\SETUP.EXE -DestinationPath C:\Temp\SetupFactory31 -Name '*.EXE' -CollisionAction Rename
Expand-SetupFactoryInstaller -Path C:\Path\To\SF31\IRDATA.IRD -DestinationPath C:\Temp\SetupFactory31Raw -Name 'IR*.EXE' -RawEntries -CollisionAction Rename
```

`PayloadCatalog` is the installed-file table and is the default extraction source. Omit `-Name` only when `CanExpand` is true. For SF3.1, `CanExpandPartial` means one or more sibling companion files are missing or have the wrong packed size; present entries remain individually extractable. For SF4-10, it means the declared payload exceeds the available bytes and must be treated as an incomplete or corrupt download, even though intact prefix records remain available for forensic extraction. Compare the local length with the response `Content-Length` or redownload the artifact before drawing conclusions about optional or remote payloads. `ContainerEntries` describes the bootstrap records, while `-RawEntries` exports those records and any separately framed `DependencyPayloads`. Extraction validates bounds, decompression framing, expanded size, CRC32, paths, and collisions. Never execute a setup runtime, prerequisite, generated uninstaller, or extracted payload on the host.

`DependencyPayloads` identifies prerequisite executables physically stored before the application payload. Treat them as installability evidence rather than automatic WinGet dependencies: inspect the prerequisite identity and compiled conditions, then confirm whether silent installation launches, skips, or refuses them. A catalog-only installed record has no safe physical offset and must not be used as extracted-file evidence.

Review each record's `Policy` and the aggregate `FilePolicySummary` before accepting unattended behavior or treating `PayloadCatalog` as the unconditional installed-file set. `AskUserOverwriteEntries` can introduce an overwrite prompt; `ConditionalEntries` vary by OS, language, advanced comparison, runtime expression, build configuration, or package; `SelfRegisteringEntries` can create associations through installed code; and `SuppressInUseNoticeEntries` can defer replacement until restart. Setup Factory 4 exposes its true-file-version overwrite inputs separately because they select replacement behavior rather than file eligibility. `NeverRemoveEntries`, `SharedSystemFileEntries`, `StoreOnlyEntries`, `ShortcutEntries`, `ProtectedEntries`, `BackupEntries`, and `CrcCheckDisabledEntries` are retained as installed-state and security evidence even when they do not map directly to a WinGet field.

### 6. Determine scope and architecture

Literal HKCU uninstall writes indicate user scope; HKLM writes indicate machine scope. A resolved Program Files destination supplies machine-scope evidence when no explicit uninstall write contradicts it. Mixed visible ARP hives produce no single scope.

Determine architecture from installed application binaries or runtime behavior. The 32-bit setup launcher and WOW64 registry view do not necessarily describe the payload architecture.

### 7. Determine switches and installability

Inspect `SupportsSilentInstallation`, `StartsInSilentMode`, `InstallerSwitches`, `InstallModes`, and `SilentInstallationEvidence`. Setup Factory 3.1, 4, and 5 are interactive-only: SF3.1 is a Windows 3.x multi-file runtime, and the Setup Factory 6 builder documentation identifies `/S` silent installation as a new 6.0 feature while the version 5 help and runtime do not expose that facility. Setup Factory 6 accepts `/S` as a generation capability; its separate "Run setup in silent mode" project default is not required to use the switch, so `StartsInSilentMode` may remain null. For Setup Factory 7 through 10, the parser reads `EnableSilentMode` from the serialized `CProjectData` record and validates the following `CMainWindowSettings` structure before accepting the flag. A true value proves that the artifact enables `/S`; a false value proves that the project disables silent mode even when the runtime contains `/S` strings.

For a true result, still test license acceptance, reboot suppression, custom prerequisites, external DLL actions, exit codes, and whether the application can launch after silent installation. Setup Factory 5 execution and file-operation records can be guarded by runtime variables or request removable media, while Setup Factory 6 action scripts can assign `%SilentMode%` during startup and override the command-line request. Inspect `VariableReads`, `VariableAssignments`, `ExecutionActions`, `FileSystemActions`, `InstallabilityActions`, `RebootActions`, `ExternalCodeActions`, and `SetupFactory.Installability.*` diagnostics; validate any reachable or runtime-dependent action that affects unattended behavior. A false result is interactive-only. Duplicate modern project records are accepted only when all validated records agree on both silent flags; conflicting or missing records return null with `SetupFactory.Installability.SilentSupportUnresolved`.

When Lua conditions, unresolved variables, nested execution, or external DLL calls affect unattended installation, keep the parser diagnostic and use VM evidence. Do not infer `silentWithProgress` merely because `/S` performs an unattended installation.

### 8. Compose the manifest

Use the authoring workflow after static and dynamic evidence agree. Add `ProductCode` or `AppsAndFeaturesEntries` only when the resulting ARP identity differs from the locale metadata or is otherwise required by the manifest rules. Preserve existing scope and dependencies during partial updates unless the task explicitly supplies stronger evidence.

## Apps and Features

Use the visible ARP owner written by the installer. Built-in and custom registry routes can coexist, so explicit custom uninstall writes take precedence. `WritesAppsAndFeaturesEntry: false` means the outer installer does not expose proven visible ARP evidence; inspect nested actions and compare VM installed-state snapshots before changing existing fields.

For SF3.1, `WritesAppsAndFeaturesEntry: false` is a generation fact for the verified Windows 3.1 route, not a request to search the extracted runtime for a modern ProductCode.

## Scope and architecture

Scope is derived from explicit uninstall hives before installation paths. Architecture comes from installed payload evidence. Neither should be guessed from the outer launcher alone.

## Known examples

- `BicomSystems.OutCALL`
- `BicomSystems.gloCOM`
- `BicomSystems.Communicator`
- `Locklizard.SafeguardPDFViewer`
- `Locklizard.SafeguardPDFWriter`
- Historical Indigo Rose Setup Factory 3.1 builder media, used as a structural regression rather than a current WinGet package

## Validation notes

Follow the [VM validation workflow](../../workflows/vm-validation.md). For Setup Factory, compare visible and hidden ARP entries, registry view, installed destinations, protocols and file associations after first run, silent exit code, reboot behavior, and any external DLL or nested-process effects. Missing version 4 product fields, unnamed version 4 action codes, scenario-dependent version 5 execution, file, INI, or registry-variable conditions, unsupported version 6 control flow or expressions, and conditional Lua are mandatory VM-review cases when they influence authored fields.

## Source references

- [Indigo Rose Setup Factory](https://www.indigorose.com/products/setup-factory/)
- [Setup Factory command-line options](https://www.indigorose.com/docs/suf/program_reference_command_line_options.htm)
- [Setup Factory release notes](https://www.indigorose.com/customers/release_notes/suf-release-notes.html)
- [sfextract](https://github.com/CybercentreCanada/sfextract)
- [SFUnpacker](https://github.com/Puyodead1/SFUnpacker)
- [defactory](https://codeberg.org/CYBERDEV/defactory)
- [Lhasa](https://github.com/fragglet/lhasa)
- [Archived Setup Factory 3.1 media](https://web.archive.org/web/*/http://www.indigorose.com/files/suf310.zip)
- [Archived Setup Factory 5 installer](https://web.archive.org/web/*/http://www.indigorose.com/files/suf50.exe)
- [Archived Setup Factory 6 installer](https://web.archive.org/web/*/http://www.indigorose.com/files/suf60ev.exe)
