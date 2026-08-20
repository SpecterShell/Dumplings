# MicaSetup workflow

## When to use

Use `InstallerType: exe` with `# MicaSetup` when the installer is a compiled MicaSetup v1 or v2 WPF application. MicaSetup packages a 7z application payload in a managed WPF resource and configures installation behavior through compiled `MicaSetup.Option` assignments.

Do not route Kachina Installer here. Kachina is a different format even when a historical package, discussion, or analyzer label associates it with MicaSetup. Current BetterGI releases use Kachina rather than MicaSetup.

## Detection

Run the analyzer first, then confirm the family with the strict detector:

```powershell
$Analysis = Get-WinGetInstallerAnalysis -Path $InstallerPath
$IsMicaSetup = Test-MicaSetupInstaller -Path $InstallerPath
```

`Test-MicaSetupInstaller` requires the payload structure plus one of the two source-backed configuration hosts:

- v1.0 `MicaSetup.Core.Pack` member references with a MicaSetup `UsePack` host-builder method, or `MicaSetup.Option` with `UseOptions` for later releases.
- A valid WPF `*.g.resources` container with exactly one `ResourceTypeCode.Stream` entry named `resources/setups/publish.7z`.

MicaSetup strings, assembly identity, icons, PE version fields, or a standalone 7z signature are routing hints only. Read [MicaSetup internals](../../internals/micasetup/overview.md) before changing the detector, managed reader, IL evaluator, or resource decoder.

## Static parsing

### 1. Parse once

Call `Get-MicaSetupInfo` once and reuse its result. Do not follow it with the individual `Read-*FromMicaSetup` helpers.

```powershell
$Info = Get-MicaSetupInfo -Path $InstallerPath
$Info | Select-Object BuilderGeneration, DisplayName, DisplayVersion, Publisher, ProductCode, Scope, DefaultInstallLocation, WritesAppsAndFeaturesEntry
```

Inspect `Diagnostics`, `UnresolvedFields`, and `UnresolvedExpressions` before applying evidence. `OptionValues` and `OptionEvidence` expose normalized Pack/Option configuration, except that `UnpackingPassword` is always redacted. `ConfigurationModel` identifies `Pack`, `OptionLegacy`, or `OptionModern`; `BuilderGeneration` reports the source-compatible `v1` or `v2` configuration generation. An early v2 release can still carry the v1-compatible option schema. Do not report an exact MicaSetup builder version unless the installer contains separate explicit structured evidence because MakeMica replaces ordinary assembly versions with the packaged application's version.

### 2. Resolve scope and elevation

MicaSetup v1 calls `UseElevated()` unconditionally and is machine scope.

MicaSetup v2 uses the resolved `UseElevated(bool?)` argument first and the compiled `RequestExecutionLevel` assembly attribute as supporting evidence. A proven elevated route is machine scope. A proven non-elevated route is user scope. Preserve unresolved scope and validate it in the VM when either expression is dynamic or contradictory.

User-mode v2 installations write `Uninst.dat` in the installation directory instead of an uninstall registry entry. Do not create `ProductCode` or `AppsAndFeaturesEntries` for that route solely from `KeyName`.

### 3. Resolve Apps & Features evidence

A visible ARP entry exists only when all of these conditions are proven:

- The selected installation route is elevated and machine scope.
- `IsCreateRegistryKeys` is enabled.
- `KeyName` resolves to a non-empty value.
- `SystemComponent` is disabled.

The uninstall key name is the EXE `ProductCode`. The entry is under HKLM and uses the registry view selected by `IsUseRegistryPreferX86`: `true` means 32-bit, `false` means 64-bit, and null means the process-default view. `DisplayName`, `DisplayVersion`, `Publisher`, `InstallLocation`, `UninstallString`, `DisplayIcon`, `NoModify`, `NoRepair`, and `SystemComponent` come from the compiled options and runtime defaults.

When `SystemComponent=1`, keep the registry write as hidden evidence but do not treat it as a visible WinGet-matchable ARP entry. Add `AppsAndFeaturesEntries` only when the visible identity differs meaningfully from the default locale or another installer-level field; omit a duplicate AppsAndFeatures `ProductCode` when installer-level `ProductCode` already matches.

### 4. Inspect payload architecture and dependencies

`Get-MicaSetupInfo` enumerates `publish.7z`, selectively materializes the configured main executable and relevant adjacent DLL/JSON sidecars, and returns `PayloadArchitectures`, `PayloadArchitectureInfo`, `DependencyInfo`, and `RecommendedPackageDependencies`.

Treat dependency output as authoring evidence rather than automatic manifest mutation. Inspect unknown or conditional dependencies manually. Never use `Architecture: neutral` when the payload contains a PE binary.

### 5. Inspect system effects

Review `Shortcuts`, `AutorunEntries`, `EnvironmentChanges`, `FirewallRules`, `Certificates`, and `CloseApplications`. Literal custom `Microsoft.Win32.Registry.SetValue` calls are projected into `RegistryWrites`, `Protocols`, `FileExtensions`, and their detailed association records. Computed paths, `RegistryKey` object flows, custom handlers, and arbitrary edited C# remain unresolved and require static source review or VM validation.

Protocols and file extensions may also be registered during application first run. Compare installed state before installation, after installation, and after first run before treating the lists as complete.

### 6. Extract when necessary

Omitting `Name` extracts the complete installed payload and the configured uninstaller. Pass `Rename` from automation so extraction never prompts.

```powershell
$Files = Expand-MicaSetupInstaller -Path $InstallerPath -DestinationPath $Destination -CollisionAction Rename
$Main = Expand-MicaSetupInstaller -Path $InstallerPath -DestinationPath $OtherDestination -Name $Info.ExeName -CollisionAction Rename
$Resources = Expand-MicaSetupInstaller -Path $InstallerPath -DestinationPath $ResourceDestination -RawResources -CollisionAction Rename
```

`-RawResources` exports supported WPF stream and byte-array records instead of expanding `publish.7z`. Constant payload passwords are recovered only inside the extraction operation and are never returned or logged. A dynamic password makes static extraction unresolved.

## Manifest shape

MicaSetup is a generic EXE family to WinGet. The upstream v1/v2 command-line parser recognizes arguments, but the documented `/q` and `/a` behavior is unfinished and does not prove unattended installation. Do not fabricate silent switches or dependencies.

```yaml
InstallerType: exe # MicaSetup
Scope: machine
InstallModes:
- interactive
Installers:
- Architecture: x64
  InstallerUrl: https://example.com/ProductSetup.exe
  InstallerSha256: <SHA256>
  ProductCode: ProductKeyName
```

Keep `InstallModes: interactive` until the exact fork proves another mode and passes unattended VM validation. If a fork implements silent behavior, author only the proven switches and distinguish switches handled by the outer MicaSetup host from arguments forwarded to the installed application.

Use `%ProgramFiles%`, `%ProgramFiles(x86)%`, `%LOCALAPPDATA%`, or `%APPDATA%` paths returned by `DefaultInstallLocation`; do not preserve host-specific expanded user paths in the manifest.

## WinGet defaults and overrides

MicaSetup has no WinGet-known installer type, switches, return codes, or install modes. Explicitly author only behavior proven by the exact installer. Follow the [manifest installer-field guidance](../../../../author-winget-manifest/references/manifest/installer-fields.md) for field placement, compaction, and redundant Apps & Features removal.

## Scope and architecture

The outer WPF setup's PE architecture is not necessarily the installed application architecture. Use `PayloadArchitectures` and the payload's native sidecars. Mixed native sidecars may constrain an AnyCPU main executable; preserve parser warnings when they disagree.

MicaSetup's installation directory preferences do not independently establish binary architecture. `IsUseInstallPathPreferX86` selects a path convention, while payload PE evidence determines WinGet `Architecture`.

## VM validation

Follow the [VM validation workflow](../../workflows/vm-validation.md). For MicaSetup, verify elevation, the selected scope, blocker-free command-line behavior, exit code, visible or hidden ARP entry, registry view, exact uninstall key, shortcuts, autorun, PATH changes, firewall rules, certificate installation, and whether the application registers associations only on first run.

If static analysis reports custom managed behavior, compare registry and filesystem state around both installation and first run. Never treat the existence of `CommandLineHelper` as silent-installation support.

## Known examples

- Official MicaSetup v1.0 demo installer: Costura-referenced `Pack`/`UsePack` configuration and unconditional machine elevation.
- Official MicaSetup v1.3 and v2.0 demo installers: legacy `Option`/`UseOptions` schema; the v2.0 release demonstrates why structural generation must not be inferred from a release tag or assembly version.
- Official MicaSetup v2.5 demo installer: modern option schema, compiled `RequestExecutionLevel`, generated option initializer, WPF stream resources, and 7z payload.
- Historical LyricStudio and Fischless packages may be added as fixtures only when they expose a structure or behavior not covered by the official generations.

## Source references

- [lemutec/MicaSetup](https://github.com/lemutec/MicaSetup): installer, builder, option schema, resource names, extraction, ARP, elevation, and command-line behavior.
- [MicaSetup `Option`](https://github.com/lemutec/MicaSetup/blob/v2/build/MicaSetup/Option.cs)
- [MicaSetup v1.0 `Pack`](https://github.com/lemutec/MicaSetup/blob/v1.0.0/src/MicaSetup.Core/Pack.cs)
- [MicaSetup v1.0 host configuration](https://github.com/lemutec/MicaSetup/blob/v1.0.0/src/MicaSetup/Program.cs)
- [MicaSetup installation behavior](https://github.com/lemutec/MicaSetup/blob/v2/build/MicaSetup/Helper/Setup/InstallHelper.cs)
- [MicaSetup uninstall registry helper](https://github.com/lemutec/MicaSetup/blob/v2/build/MicaSetup/Helper/System/RegistyUninstallHelper.cs)
- [.NET `ResourceReader`](https://github.com/dotnet/runtime/blob/main/src/libraries/System.Private.CoreLib/src/System/Resources/ResourceReader.cs): `.resources` v2 framing and resource type codes.
- [ECMA-335](https://ecma-international.org/publications-and-standards/standards/ecma-335/): CLR metadata and CIL structure.
