# QSetup workflow

## When to use

Use `InstallerType: exe` for Pantaray QSetup installers.

## Detection

Strong evidence includes `QSetup` or `Pantaray`.

The parser expands QSetup's bounded length-prefixed zlib records, validates the record-count footer before any Authenticode certificate, and treats explicit `Setup.txt` directives as authoritative. It can recover display name, version, publisher, uninstall key, target directory, user/all-users scope, allowed architectures, literal association actions, structured Execution Engine actions, and nested process launches. An incomplete download may still expose metadata from complete leading records, but `Expand-QSetupInstaller` rejects an incomplete record table.

## Static analysis

Read [QSetup Parser Internals](../../internals/qsetup/overview.md) before changing detection, extraction, binary decoding, or parser limits.

### Parse QSetup metadata and commands

Load PackageModule, parse once, and treat explicit `Setup.txt` directives as stronger evidence than generic executable strings:

```powershell
. .\Modules\PackageModule\Index.ps1

$Info = Get-QSetupInfo -Path $InstallerPath
$Info | Select-Object DisplayName, DisplayVersion, Publisher, ProductCode,
  DefaultInstallLocation, Scope, SupportedScopes, SupportedArchitectures,
  WritesAppsAndFeaturesEntry, ExtractedFiles, Diagnostics
$Info.SetupDirectives
$Info.ExecutionActions
$Info.ExecutedPayloads
```

### Extract the complete record table

```powershell
$Files = Expand-QSetupInstaller -Path $InstallerPath -DestinationPath $DestinationPath -CollisionAction Rename
$Files | Select-Object FullName, Length
```

Use `-Name` to limit extraction. The extractor rejects incomplete/trailing record tables even when a complete leading `Setup.txt` record was sufficient for metadata.

### Resolve product and ARP identity

```powershell
$ArpWrites = $Info.RegistryWrites | Where-Object Key -Match '\\Uninstall\\'
$ArpWrites
$Info.RegistryAssociationInfo
$Info.Protocols
$Info.FileExtensions
```

Use `ProductCode` only when `WritesAppsAndFeaturesEntry` is true and the explicit add/remove-programs display-name directive supplies the uninstall-key identity. Verify conditional or unresolved ARP behavior in a VM.

### Validate download and script behavior

QSetup switch support can vary by project; validate the exact package.

## Manifest shape

Switch documentation: [QSetup manual](https://www.panta-ray.com/pdf/qsetup_manual.pdf).

```yaml
Installers:
- Architecture: x64
  InstallerType: exe # QSetup
  InstallerUrl: https://example.com/Product-1.2.3-x64.exe
  InstallerSha256: <SHA256>
  InstallModes:
  - interactive
  - silent
  - silentWithProgress
  InstallerSwitches:
    Silent: /hide
    SilentWithProgress: /silent
    InstallLocation: /InstallDir="<INSTALLPATH>"
  ProductCode: <ProductCode>
```

## WinGet defaults and overrides

WinGet supplies no QSetup defaults for generic `InstallerType: exe`. Treat QSetup switches as complete overrides, explicitly state supported modes, and preserve exact quoting and case returned by parser or vendor documentation.

## Apps & Features

Use structured parser evidence to identify the visible Apps & Features owner. Do not substitute metadata from a hidden or nested payload unless that payload writes the visible uninstall entry.

## Scope and architecture

Use explicit parser evidence for scope and installed payload architecture. Preserve existing manifest intent and use VM validation when either value is conditional or unresolved.

## VM validation

Follow [VM validation workflow](../../workflows/vm-validation.md) for project-defined switches, downloaded payloads, scope, and script-controlled ARP behavior.

## Known examples

- `AGTEK.Gradework`
- `AGTEK.MaterialsSA`
- `AGTEK.Reveal`
- `AGTEK.RevealClassify`
- `AGTEK.Trackwork`
- `AGTEK.UndergroundSA`
- `Pantaray.QSetup`
