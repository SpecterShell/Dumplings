# InstallAware workflow

## When to use

Use `InstallerType: exe` for InstallAware setup EXEs.

## Detection

Strong evidence includes `InstallAware` or `MimarSinan` strings.

The parser requires a validated embedded 7z archive with InstallAware project evidence; a string match alone is insufficient. It reports PE identity, requested elevation, nested setup files, protocols, and file extensions. Current project metadata does not prove a visible uninstall key, so keep `ProductCode` unset until explicit payload or VM evidence is available.

## Static analysis

Read [InstallAware Parser Internals](../../internals/installaware/overview.md) before changing detection, extraction, binary decoding, or parser limits.

### Parse InstallAware metadata and payloads

Load PackageModule, parse once, and inspect the validated embedded archive:

```powershell
. .\Modules\PackageModule\Index.ps1

$Info = Get-InstallAwareInfo -Path $InstallerPath
$Info | Select-Object DisplayName, DisplayVersion, Publisher, Scope, SupportedScopes,
  RequestedExecutionLevel, WritesAppsAndFeaturesEntry, NestedInstallerFiles, MsiPayloads, Diagnostics
```

### Extract and analyze nested installers

```powershell
$Files = Expand-InstallAwareInstaller -Path $InstallerPath -DestinationPath $DestinationPath -CollisionAction Rename
$Files | Where-Object Extension -In '.exe', '.msi', '.msp', '.msix', '.appx' | ForEach-Object {
  Get-WinGetInstallerAnalysis -Path $_.FullName
}
```

Use `-Name` to extract a specific entry when full extraction is unnecessary. A nested MSI/MSP must be analyzed as a Windows Installer database; the outer InstallAware family does not prove that the MSI owns the visible ARP entry.

### Resolve outer or nested ARP ownership

```powershell
$Info.RegistryWrites | Where-Object Key -Match '\\Uninstall\\'
$Info.RegistryAssociationInfo
$Info.Protocols
$Info.FileExtensions
```

Current InstallAware project parsing does not prove a visible uninstall key, so `ProductCode` and `WritesAppsAndFeaturesEntry` remain null. Some packages are MSI-backed and may forward MSI properties. Decide visible ARP type from nested database evidence or VM ARP deltas, not from the outer EXE family.

### Validate conditional scripts and exit codes

Confirm exact switches and restart behavior per package.

## Manifest shape

Switch documentation: [InstallAware setup command line parameters](https://www.installaware.com/mh52/desktop/setupcommandlineparameters.htm).

```yaml
Installers:
- Architecture: x64
  InstallerType: exe # InstallAware
  Scope: machine
  InstallerUrl: https://example.com/Product-1.2.3-x64.exe
  InstallerSha256: <SHA256>
  InstallModes:
  - interactive
  - silent
  - silentWithProgress
  InstallerSwitches:
    Silent: /s
    SilentWithProgress: /s
    InstallLocation: TARGETDIR="<INSTALLPATH>"
    Log: /l="<LOGPATH>"
```

## WinGet defaults and overrides

WinGet supplies no InstallAware defaults for generic `InstallerType: exe`. Treat the family switches as complete overrides, explicitly state supported modes, and preserve no-reboot behavior in silent variants. Do not infer MSI forwarding unless the parser proves a nested MSI command.

## Apps & Features

Use structured parser evidence to identify the visible Apps & Features owner. Do not substitute metadata from a hidden or nested payload unless that payload writes the visible uninstall entry.

## Scope and architecture

Use explicit parser evidence for scope and installed payload architecture. Preserve existing manifest intent and use VM validation when either value is conditional or unresolved.

## VM validation

Follow [VM validation workflow](../../workflows/vm-validation.md) for MSI-backed property forwarding, custom scripts, restart behavior, exit codes, and visible ARP type.

## Known examples

- `OpenSight.FlashFXP`
- `MaestroSoft.MaestroAarsoppgjoer`
