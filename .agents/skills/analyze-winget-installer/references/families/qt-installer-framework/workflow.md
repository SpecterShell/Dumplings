# Qt Installer Framework workflow

## When to use

Use `InstallerType: exe # Qt Installer Framework` when the IFW binary-content cookie/parser identifies the installer. WinGet does not have a dedicated Qt IFW type.

Qt IFW has GUI-only and CLI-capable launcher variants. Only a CLI-capable launcher with its command-line interface enabled supports the silent manifest shape below.

Switch documentation: [Qt Installer Framework CLI](https://doc.qt.io/qtinstallerframework/ifw-cli.html).

## Detection

Require a validated Qt IFW catalog profile rather than accepting an isolated cookie, `installerbase` string, or maintenance-tool marker. Normal manifest analysis accepts the installer media role. Uninstaller, updater, package-manager, and separate DAT media remain useful diagnostic evidence but are not standalone installer entries.

For ordinary authoring, call `Get-QtInstallerFrameworkInfo` once and reuse the result. Use `Get-QtInstallerFrameworkFormatInfo` when diagnosing an unsupported layout, confirming a historical generation, or inspecting a non-installer media role:

```powershell
$Format = Get-QtInstallerFrameworkFormatInfo -Path $InstallerFile
$Format.FrameworkVersion
$Format.FrameworkVersionRange
$Format.FormatGeneration
$Format.MediaRole
$Format.CookieKind
$Format.TrailerRoute
$Format.PackageIndexRoute
$Format.PayloadRoute
$Format.Capabilities
$Format.Diagnostics
```

The parser then reads the PE optional-header subsystem. `WindowsCui` identifies the CLI/headless launcher and `WindowsGui` identifies the GUI launcher. It scans only the executable prefix before appended IFW resources for source-backed CLI option and command markers as corroborating evidence or as a fallback for malformed test fixtures.

Interpret the result as follows:

| Result | Meaning |
| --- | --- |
| `InterfaceVariant: CLI`, `CommandLineInterface: Enabled` | Silent CLI is available. |
| `InterfaceVariant: CLI`, `CommandLineInterface: Disabled` | CLI code exists, but `<DisableCommandLineInterface>true</DisableCommandLineInterface>` disables it. |
| `InterfaceVariant: GUI`, `CommandLineInterface: Unavailable` | GUI-only launcher; no WinGet-compatible silent installation. |
| `InterfaceVariant: Unknown` | Partial/ambiguous evidence; validate manually. |

Do not infer CLI support merely from Qt IFW cookies, `installerbase`, maintenance-tool strings, or the existence of generic command-line options.

## Static analysis

Read [Qt Installer Framework Installers Parser Internals](../../internals/qt-installer-framework/overview.md) before changing detection, extraction, binary decoding, or parser limits.

### Parse metadata and extract required payloads

```powershell
$Info = Get-QtInstallerFrameworkInfo -Path $InstallerFile
$Info.PackageName
$Info.DisplayVersion
$Info.Publisher
$Info.ProductCode
$Info.FrameworkVersion
$Info.FrameworkVersionRange
$Info.FormatGeneration
$Info.FormatProfileId
$Info.PayloadAvailability
$Info.PayloadAvailabilityEvidence
$Info.PackageMetadata
$Info.RepositoryUrls
$Info.Scope
$Info.SupportedScopes
$Info.ScopeEvidence
$Info.RequiresExplicitInstallLocation
$Info.SupportsExistingInstallationOverride
$Info.RecommendedUpgradeBehavior
$Info.UpgradeEvidence
$Info.FileSystemEffects
$Info.RegistryWrites
$Info.ShortcutEffects
$Info.FileExtensions
$Info.Protocols
$Info.AppsAndFeaturesEffects
$Info.Diagnostics

$ExpandedPath = Expand-QtInstallerFramework -Path $InstallerFile -Name '*.exe' -CollisionAction Rename
Get-ChildItem -Path $ExpandedPath -Recurse -File
```

When scripts are present, read the returned source directly instead of inferring behavior from isolated keyword matches:

```powershell
$Info.KnownInstallerValues
$Info.JavaScriptResources | Select-Object Source, Role, VariableAssignments, RawJavaScript
$Info.JavaScriptAnalysisInstructions
```

`RawJavaScript` is the complete decoded controller or component script and is the primary evidence. Read it verbatim. `VariableAssignments` is an assignment-site index that preserves each variable name, declaration kind, line, right-hand expression, resolution state, value, value type, and resolution source. It deliberately does not collapse repeated assignments into one supposed final value.

`IsResolved: true` means the right-hand value at that assignment site is statically known; it does not prove the branch executes or that the value becomes the variable's final runtime state. The parser resolves quoted literals, numbers, booleans, null, direct references to earlier resolved assignments, and one-argument `installer.value()` or `component.value()` calls backed by `KnownInstallerValues`. Calls into the host, concatenation, runtime state, branch-dependent expressions, and other JavaScript remain unresolved with the original expression intact.

Follow `JavaScriptAnalysisInstructions`: trace `Controller`, `Component`, prototype callbacks, page callbacks, `beginInstallation`, `createOperations*`, `installer.setValue`, `component.setValue`, package selection, downloadable archives, and operation calls. Evaluate user/machine scope, elevation, architecture, CLI/GUI mode, installer role, and online/offline branches separately. Never execute returned JavaScript on the host; use the VM when manifest-critical behavior depends on environment, registry, filesystem, network, GUI, user input, dynamic property access, `eval`, or another unresolved call.

Use the same result to classify the command-line interface and install-location behavior:

```powershell
$Info.InterfaceVariant
$Info.CommandLineInterface
$Info.SupportsSilentInstallation
$Info.PESubsystem
$Info.CommandLineInterfaceEvidence
$Info.DefaultInstallLocation
$Info.RequiresExplicitInstallLocation
$Info.InstallLocationEvidence
```

The CLI uses `--root` when supplied and otherwise falls back to config `<TargetDir>`. An empty `TargetDir` fails silent installation, so keep `--root "<INSTALLPATH>"` directly in both silent switches when `RequiresExplicitInstallLocation` is true. MSYS2 is a validated example.

When `RequiresExplicitInstallLocation` is false, omit `--root` from the ordinary silent switches and expose it as the optional `InstallLocation` switch instead.

The parser reads IFW binary-content trailers and RCC metadata without execution. It maps config `<Name>`, `<Version>`, `<Publisher>`, and `<ProductUUID>` to manifest-authoring evidence. `FrameworkVersion` identifies Qt IFW itself; it is not the packaged application's `PackageVersion`.

Use `PayloadAvailability` with `PayloadAvailabilityEvidence`, `PackageMetadata`, and `RepositoryUrls` rather than treating every archive-free binary as an online installer:

| Value | Meaning |
| --- | --- |
| `Embedded` | At least one package archive is indexed in the analyzed binary content. |
| `SidecarData` | The input is a DAT container or a same-base `.dat` sidecar is present. Supply any differently named paired DAT file explicitly with `-DataPath` for extraction. |
| `OnlinePackages` | Embedded `PackageUpdate` records, `<RemoteRepositories>`, or static `addDownloadableArchive()` evidence proves repository delivery. The parser reports URLs and archive names but does not download them. |
| `MissingFiles` | Package archive declarations exist without a resolved embedded, sidecar, or online source, or no package metadata proves that an archive-free medium is intentional. |
| `IntentionallyEmpty` | Package metadata exists and declares no archives or dynamic downloadable archive additions. |

`Expand-QtInstallerFramework` writes RCC files with their virtual paths, raw modern resources under `metadata\<collection>`, raw legacy component archives under `packages\<component>`, and selected files from embedded archives under `packages\<component>\<archive>`. Extraction uses the GPL parser process with bounded, traversal-safe paths and no external archive executable.

Supply local external content explicitly. `-DataPath` accepts paired Qt IFW DAT containers, `-RepositoryPath` accepts local repository roots or `Updates.xml`, and `-PackagePath` accepts package archive files or directories. Repository resolution follows Qt IFW's source-defined `<component>\<version><archive>` convention. These parameters never fetch network URLs:

```powershell
$ExpandedPath = Expand-QtInstallerFramework -Path $InstallerFile -DataPath $PairedDat -Name '*.dll' -CollisionAction Rename
$ExpandedPath = Expand-QtInstallerFramework -Path $InstallerFile -RepositoryPath $LocalRepository -Name '*.exe' -CollisionAction Rename
$ExpandedPath = Expand-QtInstallerFramework -Path $InstallerFile -PackagePath $DownloadedPackageArchives -Name '*' -CollisionAction Rename
```

Qt IFW package archives can be TAR, TAR+gzip, TAR+bzip2, TAR+xz, ZIP, 7z, or QBSP. QBSP is physically 7z. The extractor handles each source-supported format directly and validates selected-entry paths, links, collisions, entry counts, expanded sizes, and total output before writing.

Maintenance media can contain performed-operation XML. `Operations` retains each decoded argument/value envelope and its raw XML, while `OperationEffects`, `FileSystemEffects`, `RegistryWrites`, `ShortcutEffects`, `EnvironmentEffects`, and `ExecutionEffects` provide static projections of built-in Qt IFW operations. Read `Diagnostics` and an operation's `RawXml` when its name is unknown or it launches another process. These projections describe operations already serialized into the media; they do not replace reviewing controller/component JavaScript that conditionally adds operations at runtime.

`FileExtensions`, `Protocols`, `FileAssociationEffects`, and `ProtocolEffects` are derived only from explicit registry-write evidence such as `RegisterFileType` or `GlobalConfig`. Do not infer missing associations from package names or payload extensions. `AppsAndFeaturesEffects` reconstructs Qt IFW's separate maintenance-tool registration from installer configuration and source-defined runtime behavior.

### Resolve product UUID and visible ARP identity

Qt IFW 1.x uses `ProductName` as the Windows uninstall key. Qt IFW 2.0 and later use `ProductUUID`; if no UUID is embedded, IFW generates one at installation time and stores it in maintenance configuration. Do not invent a modern `ProductCode`; prefer name/publisher matching or VM ARP validation.

### Determine upgrade behavior

Standard IFW installers do not overwrite an existing IFW installation in the same target directory. `PackageManagerCore::installationAllowedToDirectory` rejects the target when `<MaintenanceToolName>.exe` exists. Use `UpgradeBehavior: uninstallPrevious` so WinGet removes the previous installation first. Use `deny` instead only when the package intentionally does not support WinGet upgrades.

The individual `Test-*` and `Read-*FromQtInstallerFramework` functions remain available for callers that need one isolated value. Do not use them after `Get-QtInstallerFrameworkInfo`; each helper starts a separate parser operation.

### Determine scope and installed architecture

IFW writes HKLM only when `AllUsers=true`; otherwise it writes HKCU. CLI-enabled installers can accept `AllUsers=true` or `AllUsers=false` as user arguments, so the parser reports both scopes only when the command-line interface is enabled. GUI-only or CLI-disabled installers report only their configured default scope.

When duplicating CLI-enabled user/machine entries, keep `Scope` and the corresponding `AllUsers` custom value on each installer entry.

Determine architecture from launcher support and installed binaries, not the ARP registry path.

### Compare CLI and GUI examples

CLI-capable and statically validated:

- `MSYS2.MSYS2`
- `reMarkable.reMarkableCompanionApp`

GUI-only and statically validated:

- Qt Linguist 5.12.2: `https://download.qt.io/linguist_releases/qtlinguistinstaller-5.12.2.exe`

Other Qt IFW family examples that must be classified individually:

- `TravisGoodspeed.MaskROMTool`
- `MoganLab.Mogan` (earlier versions)
- `KhronosGroup.VulkanSDK`

### Validate ambiguous interface or script behavior

Do not execute `--help` on the host to distinguish variants. Use PE subsystem and parser evidence. Require VM validation when `InterfaceVariant` is unknown, subsystem and marker evidence conflict, `JavaScriptResources` contain unresolved manifest-critical control flow, scripts conditionally modify `AllUsers`, the product UUID is generated at runtime, or the package requires a controller script.

## Manifest shape

Use this when both `SupportsSilentInstallation` and `RequiresExplicitInstallLocation` are true:

```yaml
Installers:
- Architecture: x64
  InstallerType: exe # Qt Installer Framework
  InstallerUrl: https://example.com/Product-1.2.3-x64.exe
  InstallerSha256: <SHA256>
  InstallModes:
  - interactive
  - silent
  - silentWithProgress
  InstallerSwitches:
    Silent: install --root "<INSTALLPATH>" --accept-licenses --default-answer --confirm-command
    SilentWithProgress: install --root "<INSTALLPATH>" --accept-licenses --default-answer --confirm-command
  UpgradeBehavior: uninstallPrevious
  # ProductCode: <ProductUUID> # Only when static metadata provides a deterministic value
```

Use this when a valid embedded target directory exists:

```yaml
  InstallerSwitches:
    Silent: install --accept-licenses --default-answer --confirm-command
    SilentWithProgress: install --accept-licenses --default-answer --confirm-command
    InstallLocation: --root "<INSTALLPATH>"
  UpgradeBehavior: uninstallPrevious
```

Do not author silent switches for GUI-only or CLI-disabled installers. Find another official installer build or block submission.

## WinGet defaults and overrides

WinGet supplies no Qt IFW defaults for generic `InstallerType: exe`. Treat the CLI commands in the selected shape as complete overrides and explicitly list the supported modes. GUI-only or CLI-disabled builds have no valid silent override and must not receive fabricated switches.

## Apps & Features

Use `AppsAndFeaturesEffects` and `AppsAndFeaturesEntries` to identify the visible maintenance-tool registration. Qt IFW writes this entry outside the performed-operation stream, so an empty `Operations` collection does not mean the installer lacks ARP registration. Do not substitute metadata from a hidden or nested payload unless that payload writes the visible uninstall entry.

## Scope and architecture

Use explicit parser evidence for scope and installed payload architecture. Preserve existing manifest intent and use VM validation when either value is conditional or unresolved.

## VM validation

Follow [VM validation workflow](../../workflows/vm-validation.md) when CLI/GUI evidence conflicts, silent mode requires a target directory, existing-installation override is uncertain, or scripts conditionally change scope.

## Known examples

- `MSYS2.MSYS2`: CLI-capable installer requiring an explicit target directory.
- `KhronosGroup.VulkanSDK`: generated ProductUUID behavior.
- `reMarkable.reMarkableCompanionApp`: Qt IFW package metadata and scope evidence.

## Source references

- [Qt Installer Framework source](https://github.com/qtproject/installer-framework)
- [Qt Installer Framework archive](https://download.qt.io/archive/qt-installer-framework/)
- [Qt Installer Framework command-line interface](https://doc.qt.io/qtinstallerframework/ifw-cli.html)
