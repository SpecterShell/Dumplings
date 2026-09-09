# dotNetInstaller workflow

## When to use

Use `InstallerType: exe` when the distributed file is a dotNetInstaller bootstrapper. The wrapper selects and runs configured components; the selected nested installer normally owns the visible Apps & Features entry.

## Detection

Run `Test-DotNetInstaller -Path $InstallerFile` for a cheap structural check. A normal packaged result requires a PE with exactly one bounded `CUSTOM/RES_CONFIGURATION` resource whose XML root is `configurations`. `RES_CAB` resources may be absent in configuration-only or online media. For a launcher intentionally driven by `/ConfigFile` or a sidecar `configuration.xml`, use `Test-DotNetInstaller -Path $InstallerFile -ConfigurationPath $ConfigurationFile`; this route additionally requires compiled dotNetInstaller capability evidence so arbitrary PE and XML files are rejected.

Read [dotNetInstaller internals](../../internals/dotnetinstaller/overview.md) before changing detection, extraction, resource routing, or command interpretation.

## Static analysis

### 1. Parse once

```powershell
$Info = Get-DotNetInstallerInfo -Path $InstallerFile
```

Reuse `$Info` for all later decisions. Do not call separate readers or expand the complete wrapper merely to recover fields already present in `NestedInstallerInfos`.

When the embedded graph references local XML or payload files that you have already acquired from the same trusted package source, supply them explicitly:

```powershell
$Info = Get-DotNetInstallerInfo -Path $InstallerFile -ReferencedConfigurationPath $ReferenceFiles -CompanionPath $PayloadFiles
```

Use `-ConfigurationPath` only when replacing the primary embedded configuration, matching dotNetInstaller's `/ConfigFile` behavior. The parser never downloads a reference or payload.

Inspect `FormatGeneration`, `XmlStorageRoute`, `RuntimeCapabilityProfile`, `RuntimeVersion`, `LauncherKind`, `ConfigurationDocuments`, `Configurations`, `Components`, `Commands`, `UninstallCommands`, `CompleteCommands`, `Controls`, `InstalledProductChecks`, `Downloads`, `References`, `UnresolvedReferences`, `PayloadCatalog`, `CompanionFiles`, `NestedInstallerInfos`, `Diagnostics`, and `UnresolvedFields`.

### 2. Route configurations and component filters

Each install configuration can select components by LCID, operating system, processor architecture, installed checks, and authored selection flags. Use `Get-DotNetInstallerNestedMsiSelection -Info $Info -Architecture $Architecture -InstallerLocale $InstallerLocale` to apply the runtime's positive or negated architecture and LCID filters before selecting ProductCode or nested behavior. An `Ambiguous` or `NoMatch` result is unresolved evidence, not permission to choose the first MSI.

`ConfigurationOnly` media and `configuration type="reference"` records can load downloaded or sidecar XML. Pass trusted local copies through `-ReferencedConfigurationPath`; the parser follows only authored references, bounds every document to 16 MiB and the graph to ten levels, detects cycles and schema disagreements, and reports unused supplied files. Missing, ambiguous, cyclic, and incompatible branches remain unresolved. Do not fetch an arbitrary URL from a parser result automatically.

### 3. Identify the executed payload

Use `Commands` for component installation, `UninstallCommands` for the corresponding removal routes, and `CompleteCommands` for post-install actions. `ModeSource`, `ModeAttributes`, `UsesModeFallback`, and `IsUnattendedRouteProven` show which authored attributes the runtime selected. The parser keeps `#CABPATH` separate from `#TEMPPATH`, `#APPPATH`, and `#STARTPATH`, resolves exact and path-suffix matches before basename fallback, and leaves duplicate basenames ambiguous instead of choosing one. All resolved install targets appear in `ExecutedPayloads`.

Post-install commands can launch the application after an otherwise silent installation. Record this behavior and check whether the package offers an application-specific suppression mechanism; dotNetInstaller has no general switch that disables every authored completion command.

### 4. Identify the Apps & Features owner

When exactly one distinct embedded or explicitly supplied nested MSI is configured, `Get-DotNetInstallerInfo` parses it once and projects its ProductCode, UpgradeCode, display metadata, install-location property, associations, architecture evidence, installer builder, and ARP visibility. `NestedInstallerInfos.SourceKind` distinguishes `Cabinet` from `Companion` evidence. Use `AppsAndFeaturesInstallerType` to distinguish MSI from WiX only when the nested MSI evidence proves it. If `WritesAppsAndFeaturesEntry` is false, do not author the hidden MSI as a visible `AppsAndFeaturesEntries` row.

When `NestedInstallerInfos` contains multiple records, use `Get-DotNetInstallerNestedMsiSelection` for the current installer architecture and locale. Do not combine ProductCodes from mutually exclusive component routes. For a nested EXE, obtain its ARP evidence from that payload parser or VM validation.

### 5. Extract only what is needed

```powershell
$Files = Expand-DotNetInstaller -Path $InstallerFile -DestinationPath $Folder -Name 'payload\Product.msi' -CollisionAction Rename
```

Omit `-Name` to extract all embedded files. Internal callers use `Rename`; an interactive direct call defaults to `Prompt` and prompts only after a collision. Files from global and component-specific cabinet sets are routed independently.

Pass `-CompanionPath` when the package ships sidecars separately. Selected companions are copied through the same resolved-path, collision, and aggregate output limits; reference XML remains analysis input and is not emitted as an installed payload.

### 6. Author switches from compiled capabilities

Use `$Info.InstallModes` and `$Info.InstallerSwitches` as outer-launcher capability evidence. Use `$Info.NestedInstallModes` before authoring those modes: it contains only modes proved across every default-selected embedded component and excludes unresolved reference configurations. The WinGet analyzer uses this conservative set for suggestions.

Current runtimes commonly return:

```yaml
InstallModes:
- interactive
- silent
- silentWithProgress
InstallerSwitches:
  Silent: /q /nosplash /noreboot
  SilentWithProgress: /qb /noreboot
  Log: /Log /LogFile "<LOGPATH>"
```

Historical launchers can support only `/q`, while intermediate builds can lack `/nosplash` or `/noreboot`. A launcher can accept `/q` while a nested component falls back to its interactive command. Review `DotNetInstaller.Installability.SilentRouteUnproven` and `DotNetInstaller.Installability.BasicRouteUnproven`; omit every unproven end-to-end mode.

Do not add `/ComponentArgs "*":"/quiet /norestart"` or another blanket component override. dotNetInstaller already chooses the authored interactive, basic, or silent command for each component. A global override can corrupt non-MSI commands and bypass package-specific arguments.

`RuntimeVersion` is reported only when the structured `schema.version` agrees with an exact null-terminated token compiled into non-resource PE data. PE file and product versions remain application metadata.

WinGet has no dotNetInstaller defaults for generic `InstallerType: exe`, so retain the proven outer switches. Nested switches belong in `/ComponentArgs` only when the specific component ID, payload type, and required appended arguments are proven and VM-tested.

### 7. Resolve scope and elevation

Use nested installer scope when one selected payload proves it. `administrator_required="true"` or a `requireAdministrator` PE manifest supports `ElevationRequirement: elevationRequired`; disagreement between configuration routes remains conditional. Preserve existing scope when the static evidence is incomplete. `InstalledProductChecks` can identify prerequisite ProductCodes or UpgradeCodes, but a check is detection evidence and does not by itself prove the package's own ARP identity.

### 8. Validate unresolved behavior

Follow [VM validation workflow](../../workflows/vm-validation.md) when configuration filters depend on target state, a referenced configuration or downloaded payload remains unavailable, a nested EXE or custom command owns registration, more than one ARP owner remains possible, a completion command launches the application, or exit-code propagation is unknown. Validate the outer switch and final installed state together.

## Manifest shape

```yaml
Installers:
- Architecture: x64
  InstallerType: exe # dotNetInstaller
  InstallerUrl: https://example.com/Product-1.2.3-x64.exe
  InstallerSha256: <SHA256>
  InstallModes:
  - interactive
  - silent
  - silentWithProgress
  InstallerSwitches:
    Silent: /q /nosplash /noreboot
    SilentWithProgress: /qb /noreboot
    Log: /Log /LogFile "<LOGPATH>"
  ProductCode: <NestedProductCode>
  AppsAndFeaturesEntries:
  - InstallerType: wix
    UpgradeCode: <NestedUpgradeCode>
```

Keep only fields proved by the selected artifact. Remove `AppsAndFeaturesEntries.InstallerType` when it is redundant with other effective manifest evidence, and let `Optimize-WinGetManifest` remove other redundant ARP values.

## Known example

- `Wibu-Systems.CodeMeterRuntimeKit`: modern dotNetInstaller global cabinet containing one WiX MSI, repeated across locale configurations.

## Source references

- [dotNetInstaller repository](https://github.com/dotnetinstaller/dotnetinstaller)
- [Command-line parser](https://github.com/dotnetinstaller/dotnetinstaller/blob/master/dotNetInstallerLib/InstallerCommandLineInfo.cpp)
- [UI mode fallback](https://github.com/dotnetinstaller/dotnetinstaller/blob/master/dotNetInstallerLib/InstallUILevel.cpp)
