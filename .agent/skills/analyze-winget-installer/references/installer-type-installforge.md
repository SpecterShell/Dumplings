# InstallForge

## When To Use

Use this page to reject or escalate InstallForge installers.

## Detection

Strong evidence includes `InstallForge`, `InstallForge Setup`, or `installforge.net`.

### Parser API

Use the PackageModule parser instead of marker strings:

```powershell
$Info = Get-InstallForgeInfo -Path $InstallerPath
Expand-InstallForgeInstaller -Path $InstallerPath -DestinationPath $DestinationPath
```

`Get-InstallForgeInfo` reads the named `SETUPCONFIGURATION` PE resource and
structured `SC.dat` values, validates the embedded 7z payload, and reports
identity, install directory, scope, registry associations, and payload files.
`SupportsSilentInstallation` is authoritative when false. Extraction uses the
bundled SharpCompress library and does not execute setup or require 7-Zip.

## Manifest Shape

InstallForge does not support silent installation for WinGet-compatible unattended installs.

```yaml
Installers:
- Architecture: x64
  InstallerType: exe # InstallForge
  InstallerUrl: https://example.com/Product-1.2.3-x64.exe
  InstallerSha256: <SHA256>
  InstallModes:
  - interactive
```

## WinGet Defaults And Overrides

WinGet supplies no InstallForge defaults for generic `InstallerType: exe`, and InstallForge does not provide a supported unattended installation mode. Do not fabricate silent switches or claim silent `InstallModes`; block WinGet submission unless the current package proves a separate supported mechanism.

## Step-By-Step Analysis

### Step 1: Parse Metadata And Confirm The Installer Family

Load PackageModule, parse once, and require the configuration and payload evidence to agree:

```powershell
. .\Modules\PackageModule\Index.ps1

$Info = Get-InstallForgeInfo -Path $InstallerPath
$Info | Select-Object DisplayName, DisplayVersion, Publisher, DefaultInstallationDirectory,
  Scope, SupportsSilentInstallation, WritesAppsAndFeaturesEntry, ExtractedFiles, Warnings
```

### Step 2: Extract Payload Files

```powershell
$Files = Expand-InstallForgeInstaller -Path $InstallerPath -DestinationPath $DestinationPath
$Files | Select-Object FullName, Length
```

Analyze nested executables separately. Extraction is static evidence only and does not make the standard InstallForge launcher silent-capable.

### Step 3: Inspect ARP And Association Evidence

```powershell
$Info.RegistryWrites | Where-Object Key -Match '\\Uninstall\\'
$Info.RegistryAssociationInfo
$Info.Protocols
$Info.FileExtensions
```

`WritesAppsAndFeaturesEntry` reflects the structured `Uninstaller=1` setting, but the parser does not invent the exact uninstall-key name; `ProductCode` remains null until explicit registry or VM evidence proves it.

### Step 4: Confirm The Silent-Installation Block

Do not submit an InstallForge-based installer unless the package provides a separate, verified silent-capable build or wrapper.

## VM Validation

Follow [VM-Only Dynamic Validation Workflow](vm-validation-workflow.md) only to verify a separate silent-capable wrapper or build. The standard InstallForge package remains blocked when it cannot install unattended.
