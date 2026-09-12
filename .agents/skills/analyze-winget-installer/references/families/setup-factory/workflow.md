# Setup Factory workflow

## When to use

Use `InstallerType: exe # Setup Factory` when content-based analysis identifies an Indigo Rose Setup Factory single-file installer. Dumplings extracts outer catalogs from Setup Factory 4 through 10, parses the generation-specific global and built-in uninstall objects from version 4, parses the fixed product and built-in uninstall blocks from versions 5 and 6, and parses structured modern metadata from versions 7 through 10 without executing the installer. Version 3.1 multi-file media requires the separate handling described below.

## Detection

Setup Factory 4 begins its PE overlay with `E0 E1 E2 E3 E4 E5 E6`, followed by a one-byte entry count. Versions 5 through 7 use `E0 E1 E2 E3 E4 E5 E6 E7`; versions 8 through 10 use `E0 E0 E1 E1 ... E7 E7`. The single signature is ambiguous without validated catalog framing and trusted runtime evidence, so do not classify a file from those eight bytes or from `Setup Factory`, `Indigo Rose`, or `IRSetup` strings alone.

Read [Setup Factory internals](../../internals/setup-factory/overview.md) before changing detection, extraction, binary decoding, or parser limits.

## Manifest shape

Setup Factory has no WinGet-native installer type or default switches, so the manifest uses generic `exe`. Add only switches and fields proved for the exact artifact.

```yaml
Installers:
- Architecture: x64
  InstallerType: exe # Setup Factory
  InstallerUrl: https://example.com/Product-1.2.3-x64.exe
  InstallerSha256: <SHA256>
  InstallModes:
  - interactive
  - silent
  InstallerSwitches:
    Silent: /S
  ProductCode: <ProductCode>
```

Do not copy `/S` into a manifest only because another Setup Factory package uses it. Treat command-line documentation as a candidate and confirm silent completion, installed state, exit code, and ARP ownership in the VM.

## Static parsing

### 1. Parse the installer once

```powershell
$Info = Get-SetupFactoryInfo -Path C:\Path\To\Setup.exe
$Info | Select-Object DisplayName, DisplayVersion, Publisher, ProductCode, Scope, DefaultInstallLocation, WritesAppsAndFeaturesEntry, ParserVersionInfo, Diagnostics, UnresolvedFields
```

Reuse `$Info` for the remaining steps. Do not call individual readers after `Get-SetupFactoryInfo`.

### 2. Route by structural profile

Inspect `$Info.ParserVersionInfo.ProfileId`, `FormatGeneration`, `BuilderVersion`, `EmbeddedRuntimeVersion`, and `HeaderPrefixLength`. `EmbeddedRuntimeInfo` exposes the decoded runtime's trusted version-resource identity and the structural profiles compatible with that identity.

- `setup-factory-4` decodes the source-backed `CGeneralData`, `CConclusionData`, `CUninInfo`, `CRegistryData`, and `CFileInfo` routes. Its built-in Control Panel description and unique uninstall key are authoritative only when `IncludeUninstall` is true; version, publisher, and default install directory are absent from these global objects and remain unresolved. Do not fill those fields from the launcher's PE version resource.
- `setup-factory-5` and `setup-factory-6` decode their fixed product block and built-in uninstall settings. Version 5 also decodes complete `CRegistryData` and nested `CConditionData` lists, but projects a write only when the common selectors are unconditional and the advanced-condition list is empty. Version 6 reconstructs counted action lists and projects Modify Registry actions only when their install-time condition resolves true. Inspect `LegacyActionCatalog` and diagnostics before treating built-in ARP as the only system effect.
- `setup-factory-7` supports both observed runtime prefixes. A prefix length of 8 or 9 is a structural result, not an error.
- `setup-factory-8-plus` covers the shared observed archive profile used by Setup Factory 8, 9, and 10. The installed-file records have three validated revisions: Setup Factory 8.1 and 9.0 use ten destination-layout bytes, 9.1 through 9.5 use eleven, and 10.2 additionally uses a one-byte compression prefix. The parser selects a revision only after validating the complete table and payload ranges. Use `BuilderVersion` only when `BuilderVersionSource` is present.

Stop if detection is rejected or catalog validation throws. A marker-only match is not enough to continue as Setup Factory.

### 3. Review product metadata

Use `DisplayName`, `DisplayVersion`, `Publisher`, and `DefaultInstallLocation` only when the parser resolves them from the Setup Factory 4 built-in uninstall identity, the Setup Factory 5/6 product block, modern `CSessionVar` records, or a more specific deterministic uninstall-key write. `ProductMetadata` exposes the decoded legacy block for review. Values in `UnresolvedFields` require another source or VM evidence.

Version 4 returns `SetupFactory.Metadata.Classic4ProductFieldsUnavailable` for metadata that the format does not store in its decoded global objects. Version 5 returns `SetupFactory.Metadata.LegacyRegistryActionsPartial` only when a counted registry or condition object is structurally malformed; well-formed runtime-dependent conditions stay in `LegacyActionCatalog` with `ConditionState: Unknown` and produce the field-scoped `SetupFactory.Metadata.RegistryActionsUnresolved` diagnostic instead. Version 6 uses the same unresolved diagnostic for unsupported action control flow or conditions. Built-in product and uninstall values remain valid independently of those diagnostics.

### 4. Establish ARP ownership

Inspect `RegistryArpEntries`, `WritesAppsAndFeaturesEntry`, `ProductCode`, and `AppsAndFeaturesEntries` together.

Setup Factory 4 through 6 store the built-in uninstall enable flag, Control Panel display expression, and unique registry key directly; `UninstallConfiguration` exposes those fields, and the enable flag gates ARP projection. Modern media derives its built-in key from the exact `%ProductName%%ProductVer%` expression. Exact condition-resolved legacy writes or literal modern writes under `Software\Microsoft\Windows\CurrentVersion\Uninstall\<key>` take precedence. Registry actions outside that path may establish protocols or file associations, but they do not establish ProductCode, ARP visibility, or scope.

Hidden entries remain evidence with `IsVisible: false`; do not project them as the visible package owner. If more than one visible custom uninstall entry exists, retain the individual entries and do not invent one installer-level ProductCode.

### 5. Inspect associations, prerequisites, and payload records

```powershell
$Info.RegistryAssociationInfo
$Info.Protocols
$Info.FileExtensions
$Info.LegacyActionCatalog | Select-Object IsPresent, IsComplete, Error, UnresolvedCount
$Info.LegacyActionCatalog.Entries | Select-Object Offset, Phase, ActionId, ActionName, Root, Key, Name, Value, Type, ConditionState
$Info.ContainerEntries | Select-Object Name, Kind, PackedSize, Crc32
$Info.DependencyPayloads | Select-Object Name, SourcePath, Label, PackedSize, ExpandedSize
$Info.PayloadCatalog | Select-Object Name, DestinationPath, Condition, InstallType, Packages, IsEmbedded, PackedSize, ExpandedSize, Crc32
$Info.InstalledFileCatalog | Select-Object IsComplete, CanExtract, CanExtractPartial, ExtractableEntryCount, UnavailableEntryCount, DestinationPadding, CompressionPrefixLength

Expand-SetupFactoryInstaller -Path C:\Path\To\Setup.exe -DestinationPath C:\Temp\SetupFactory -Name '*.exe' -CollisionAction Rename
Expand-SetupFactoryInstaller -Path C:\Path\To\Setup.exe -DestinationPath C:\Temp\SetupFactoryRaw -Name 'irsetup.*' -RawEntries -CollisionAction Rename
```

`PayloadCatalog` is the installed-file table and is the default extraction source. Omit `-Name` only when `CanExpand` is true. `CanExpandPartial` means the declared payload exceeds the available bytes and must be treated as an incomplete or corrupt download, even though intact prefix records remain available for forensic extraction. Compare the local length with the response `Content-Length` or redownload the artifact before drawing conclusions about optional or remote payloads. `ContainerEntries` describes the outer bootstrap records, while `-RawEntries` exports those records and any separately framed `DependencyPayloads`; use `-Name 'irsetup.*'` when only the bootstrap metadata is needed. Extraction validates bounds, decompression framing, expanded size, CRC32, paths, and collisions. Never execute `irsetup.exe`, a prerequisite, or another extracted payload on the host.

`DependencyPayloads` identifies prerequisite executables physically stored before the application payload. Treat them as installability evidence rather than automatic WinGet dependencies: inspect the prerequisite identity and compiled conditions, then confirm whether silent installation launches, skips, or refuses them. A catalog-only installed record has no safe physical offset and must not be used as extracted-file evidence.

### 6. Determine scope and architecture

Literal HKCU uninstall writes indicate user scope; HKLM writes indicate machine scope. A resolved Program Files destination supplies machine-scope evidence when no explicit uninstall write contradicts it. Mixed visible ARP hives produce no single scope.

Determine architecture from installed application binaries or runtime behavior. The 32-bit setup launcher and WOW64 registry view do not necessarily describe the payload architecture.

### 7. Determine switches and installability

The current Setup Factory command-line documentation lists silent and runtime options, but old releases and custom Lua can differ. For generic EXE authoring, validate `/S` first only when static or publisher evidence supports it. Test license acceptance, reboot suppression, custom prerequisites, external DLL actions, exit codes, and whether the application can launch after silent installation.

When Lua conditions, unresolved variables, nested execution, or external DLL calls affect unattended installation, keep the parser diagnostic and use VM evidence. Do not infer `silentWithProgress` merely because `/S` performs an unattended installation.

### 8. Compose the manifest

Use the authoring workflow after static and dynamic evidence agree. Add `ProductCode` or `AppsAndFeaturesEntries` only when the resulting ARP identity differs from the locale metadata or is otherwise required by the manifest rules. Preserve existing scope and dependencies during partial updates unless the task explicitly supplies stronger evidence.

## Apps and Features

Use the visible ARP owner written by the installer. Built-in and custom registry routes can coexist, so explicit custom uninstall writes take precedence. `WritesAppsAndFeaturesEntry: false` means the outer installer does not expose proven visible ARP evidence; inspect nested actions and compare VM installed-state snapshots before changing existing fields.

## Scope and architecture

Scope is derived from explicit uninstall hives before installation paths. Architecture comes from installed payload evidence. Neither should be guessed from the outer launcher alone.

## Known examples

- `BicomSystems.OutCALL`
- `BicomSystems.gloCOM`
- `BicomSystems.Communicator`
- `Locklizard.SafeguardPDFViewer`
- `Locklizard.SafeguardPDFWriter`

## Validation notes

Follow the [VM validation workflow](../../workflows/vm-validation.md). For Setup Factory, compare visible and hidden ARP entries, registry view, installed destinations, protocols and file associations after first run, silent exit code, reboot behavior, and any external DLL or nested-process effects. Missing version 4 product fields, runtime-dependent version 5 conditions, unsupported version 6 control flow or expressions, and conditional Lua are mandatory VM-review cases when they influence authored fields.

## Source references

- [Indigo Rose Setup Factory](https://www.indigorose.com/products/setup-factory/)
- [Setup Factory command-line options](https://www.indigorose.com/docs/suf/program_reference_command_line_options.htm)
- [Setup Factory release notes](https://www.indigorose.com/customers/release_notes/suf-release-notes.html)
- [sfextract](https://github.com/CybercentreCanada/sfextract)
- [SFUnpacker](https://github.com/Puyodead1/SFUnpacker)
- [defactory](https://codeberg.org/CYBERDEV/defactory)
- [Archived Setup Factory 5 installer](https://web.archive.org/web/*/http://www.indigorose.com/files/suf50.exe)
- [Archived Setup Factory 6 installer](https://web.archive.org/web/*/http://www.indigorose.com/files/suf60ev.exe)
