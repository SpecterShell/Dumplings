# QSetup workflow

## When to use

Use `InstallerType: exe` when structural parsing confirms a Pantaray QSetup package. Do not classify an executable from `QSetup` or `Pantaray` strings alone.

## Detection

`Test-QSetup` validates a PE overlay route, bounded zlib records, each decoded record header and body marker, a matching generation-specific footer, and a `Setup.txt` record containing composer directives. Fixtures verify QSetup 1.0 through 5.0, 7.0 through 8.1, and 12.0; 6.x and 9.x through 11.x have no stable fixtures and are reported through structurally compatible routes rather than guessed from version strings.

Read [QSetup internals](../../internals/qsetup/overview.md) before changing framing, footer, action, or extraction code.

## Static analysis

### 1. Parse the installer once

```powershell
. .\Modules\PackageModule\Index.ps1

$Info = Get-QSetupInfo -Path $InstallerPath -CompanionPath $CompanionPath
$Info | Select-Object DisplayName, DisplayVersion, Publisher, ProductCode, Scope, RegistryView, DefaultInstallLocation, PackageArchitecture, RequestedExecutionLevel, ElevationRequirement, WritesAppsAndFeaturesEntry, FormatGeneration, StructuralRoutes, Diagnostics
```

Use `SetupDirectives`, `PayloadCatalog`, `RegistryWrites`, `RegistryOperations`, `IniFileOperations`, `XmlOperations`, `SystemEffects`, `PayloadArchitectureInfo`, `PayloadDependencyInfo`, `Shortcuts`, `EnvironmentChanges`, `ExecutionActions`, `ExecutedPayloads`, `FileAssociationOperations`, `ExecutionRegistryOperations`, `ExecutionIniFileOperations`, `ExecutionEnvironmentOperations`, `ArchitectureStateOperations`, `UserInteractionOperations`, and `ProcessControlOperations` from the same result. Do not repeat the parse through the individual `Read-*FromQSetup` helpers.

### 2. Confirm ARP ownership

QSetup creates its visible uninstall key from the Add/Remove Programs display name, falling back to the program descriptive name when the display-name field is empty. Use `ProductCode` only when `WritesAppsAndFeaturesEntry` is true. Explicit `SET_PERFORM_REGISTRY_OP` uninstall keys override built-in defaults, and `SystemComponent=1` rows remain hidden evidence rather than WinGet-matchable Apps & Features entries. The parser first uses an explicit `SET_UNINSTALL_EXE_NAME`, then an exact compiled uninstall shortcut matching `SET_PROG_STAMP`. If neither exists, the verified QSetup 1–7 formula is `UnInstall_<stamp>.exe` and the VM-proven QSetup 12 formula is `<media>_<stamp>.exe`; a blank name in QSetup 8–11 remains unresolved because no fixture establishes its generation rule. Inspect `Uninstaller.NamingRoute`, `ComposerBuild`, and diagnostics before accepting a generated path.

```powershell
$Info.AppsAndFeaturesEntries
$Info.CustomArpEntries
$Info.RegistryWrites | Where-Object Key -Match '\\Uninstall\\'
```

### 3. Review scope and architecture

Explicit current-user or all-users directives take priority. The PE requested-execution level and resolved installation root provide fallback evidence. QSetup launchers are commonly x86 even when the package uses QSetup's 64-bit setup state, so `RegistryView` follows that setup state rather than payload architecture. `PackageArchitecture` prefers selective inspection of the configured main executable and adjacent DLLs, then the x64-only allowed-OS set, and only then the outer launcher. Review `InspectedPayloadFiles` and `PayloadDependencyInfo` before converting dependency evidence into manifest dependencies.

### 4. Review silent behavior and execution actions

The documented switches are `/hide`, `/silent`, and `/InstallDir="<INSTALLPATH>"`. A compiled User Information dialog disables `/hide` and `/silent`; in that case the parser returns interactive-only evidence. Review `ExecutionActions` and `ExecutedPayloads` for prerequisites, nested MSI packages, restarts, and custom commands. Each action reports condition category, runtime-state dependence, and user-interaction dependence. A user-interaction condition or command produces `QSetup.Execution.UserInteraction`; test that route interactively and unattended in the VM rather than assuming the command is skipped.

### 5. Extract installed files

Default extraction follows ordered `SET_SUB_DIR` and `SET_COPY_FILES` directives, removes the physical numeric record prefix, and writes application-root files at their installed relative paths. Files targeting other roots are placed below `_destinations`. For split, non-SFX, or spanned output, pass exact companion files or a containing directory through `-CompanionPath`; the parser does not guess neighboring media.

```powershell
$Files = Expand-QSetupInstaller -Path $InstallerPath -CompanionPath $CompanionPath -DestinationPath $DestinationPath -CollisionAction Rename
$Files | Select-Object FullName, Length
```

Omit `-Name` to extract every mapped installed file. Use `-Name` for an installed path or file name. Use `-RawRecords` only when investigating the requested physical media layer; raw entries are written below `_qsetup\records` and do not silently follow a nested wrapper. Split descriptors authenticate the exact companion name, length, preamble, and secret. Spanned `.001`, `.002`, and later parts must be explicitly supplied without gaps. Extraction rejects missing or duplicate companions, incomplete tables, invalid body markers, unsafe paths, and aggregate output-limit violations.

### 6. Review associations and other system effects

```powershell
$Info.RegistryAssociationInfo
$Info.Protocols
$Info.FileExtensions
$Info.FileAssociationOperations
$Info.Shortcuts
$Info.EnvironmentChanges
$Info.RegistryOperations
$Info.IniFileOperations
$Info.XmlOperations
$Info.ExecutionRegistryOperations
$Info.ExecutionIniFileOperations
$Info.ExecutionEnvironmentOperations
$Info.ArchitectureStateOperations
$Info.UserInteractionOperations
$Info.ProcessControlOperations
```

The parser decodes source-backed eight-field registry and INI records and seven-field XML records. Literal registry creates feed custom ARP and association projection; unsupported roots, types, actions, or malformed field counts become structured diagnostics instead of shifted evidence. It also classifies Execution Engine commands for file associations, registry, INI, environment, architecture state, user interaction, process control, services, COM, fonts, downloads, restarts, nested execution, and filesystem effects. Only unconditional setup-time `Create File Association` actions become authoritative `FileExtensions`; conditional associations remain operation evidence. Conditions retain `ConditionState`, category, and runtime or interaction requirements, so host-dependent predicates still require VM validation.

### 7. Validate in a VM

Follow [VM validation](../../workflows/vm-validation.md). Test the exact silent switch, install-location override, process exit code, requested elevation route, registry view, visible and hidden ARP tuples, generated uninstaller path, nested actions, and application launch. Test split or spanned media with every companion file present. A controlled QSetup 12 `/hide` installation returned `0`, wrote a quoted `InstallLocation` and quoted generated `<media>_<stamp>.exe` uninstall command to the 32-bit ARP view, and its generated uninstaller returned `0`; treat this as generation-specific evidence rather than a universal custom success code.

## Manifest shape

WinGet has no QSetup defaults for generic EXE installers. Emit only the switches and modes proven for the artifact.

```yaml
Installers:
- Architecture: x64
  InstallerType: exe # QSetup
  Scope: machine
  InstallModes:
  - interactive
  - silent
  - silentWithProgress
  InstallerSwitches:
    Silent: /hide
    SilentWithProgress: /silent
    InstallLocation: /InstallDir="<INSTALLPATH>"
  ProductCode: <ProductCode>
  InstallerUrl: https://example.com/Product-1.2.3-x64.exe
  InstallerSha256: <SHA256>
```

Omit silent modes and switches when `HasUserInformationDialog` is true. Preserve exact case and quoting. Do not add an installer success code from the QSetup Composer’s documented build exit code; that code applies to Composer compilation, not to the generated setup.

## Apps & Features

Use the parser’s explicit Add/Remove Programs directives. Do not substitute identity from PE version strings, a nested prerequisite, or a hidden record. Verify locale-dependent or conditionally assigned values in the VM.

## Known examples

- `AGTEK.Gradework`
- `AGTEK.MaterialsSA`
- `AGTEK.Reveal`
- `AGTEK.RevealClassify`
- `AGTEK.Trackwork`
- `AGTEK.UndergroundSA`
- `Pantaray.QSetup`

## Source references

- [Pantaray QSetup manual](https://www.panta-ray.com/pdf/qsetup_manual.pdf)
- [QSetup Execution Engine](https://www.pantaray.com/execute.html)
- [QSetup execution command reference](https://www.pantaray.com/execution_cmd.html)
- [Archived QSetup builder installers](https://web.archive.org/web/*/https://www.panta-ray.com/qstp.exe)
