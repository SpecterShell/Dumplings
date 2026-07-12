# QSetup

## When To Use

Use `InstallerType: exe` for Pantaray QSetup installers.

## Detection

Strong evidence includes `QSetup` or `Pantaray`.

### Parser API

```powershell
$Info = Get-QSetupInfo -Path $InstallerPath
Expand-QSetupInstaller -Path $InstallerPath -DestinationPath $DestinationPath
```

The parser expands QSetup's bounded length-prefixed zlib records and treats
explicit `Setup.txt` directives as authoritative. It can recover display
name, version, publisher, uninstall key, target directory, user/all-users
scope, allowed architectures, and literal association actions. An incomplete
download may still expose metadata from complete leading records, but
`Expand-QSetupInstaller` rejects an incomplete record table.

## Manifest Shape

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

## WinGet Defaults And Overrides

WinGet supplies no QSetup defaults for generic `InstallerType: exe`. Treat QSetup switches as complete overrides, explicitly state supported modes, and preserve exact quoting and case returned by parser or vendor documentation.

## Step-By-Step Analysis

### Step 1: Parse QSetup Metadata And Commands

Load PackageModule, parse once, and treat explicit `Setup.txt` directives as stronger evidence than generic executable strings:

```powershell
. .\Modules\PackageModule\Index.ps1

$Info = Get-QSetupInfo -Path $InstallerPath
$Info | Select-Object DisplayName, DisplayVersion, Publisher, ProductCode,
  DefaultInstallationDirectory, Scope, SupportedScopes, SupportedArchitectures,
  WritesAppsAndFeaturesEntry, ExtractedFiles, Warnings
$Info.SetupDirectives
```

### Step 2: Extract The Complete Record Table

```powershell
$Files = Expand-QSetupInstaller -Path $InstallerPath -DestinationPath $DestinationPath
$Files | Select-Object FullName, Length
```

Use `-Name` to limit extraction. The extractor rejects incomplete/trailing record tables even when a complete leading `Setup.txt` record was sufficient for metadata.

### Step 3: Resolve Product And ARP Identity

```powershell
$ArpWrites = $Info.RegistryWrites | Where-Object Key -Match '\\Uninstall\\'
$ArpWrites
$Info.RegistryAssociationInfo
$Info.Protocols
$Info.FileExtensions
```

Use `ProductCode` only when `WritesAppsAndFeaturesEntry` is true and the explicit add/remove-programs display-name directive supplies the uninstall-key identity. Verify conditional or unresolved ARP behavior in a VM.

### Step 4: Validate Download And Script Behavior

QSetup switch support can vary by project; validate the exact package.

## Known QSetup Packages

- `AGTEK.Gradework`
- `AGTEK.MaterialsSA`
- `AGTEK.Reveal`
- `AGTEK.RevealClassify`
- `AGTEK.Trackwork`
- `AGTEK.UndergroundSA`
- `Pantaray.QSetup`

## VM Validation

Follow [VM-Only Dynamic Validation Workflow](vm-validation-workflow.md) for project-defined switches, downloaded payloads, scope, and script-controlled ARP behavior.
