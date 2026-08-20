# InstallForge workflow

## When to use

Use this page to reject or escalate InstallForge installers.

## Detection

Strong evidence includes `InstallForge`, `InstallForge Setup`, or `installforge.net`.

`Get-InstallForgeInfo` reads the named `SETUPCONFIGURATION` PE resource and structured `SC.dat` values, validates the embedded 7z payload, and reports identity, install directory, scope, registry associations, and payload files. `SupportsSilentInstallation` is authoritative when false. Extraction uses the bundled SharpCompress library and does not execute setup or require 7-Zip.

## Static analysis

Read [InstallForge Parser Internals](../../internals/installforge/overview.md) before changing detection, extraction, binary decoding, or parser limits.

### Parse metadata and confirm the installer family

Load PackageModule, parse once, and require the configuration and payload evidence to agree:

```powershell
. .\Modules\PackageModule\Index.ps1

$Info = Get-InstallForgeInfo -Path $InstallerPath
$Info | Select-Object DisplayName, DisplayVersion, Publisher, DefaultInstallationDirectory,
  Scope, SupportsSilentInstallation, WritesAppsAndFeaturesEntry, ExtractedFiles, Diagnostics
```

### Extract payload files

```powershell
$Files = Expand-InstallForgeInstaller -Path $InstallerPath -DestinationPath $DestinationPath -CollisionAction Rename
$Files | Select-Object FullName, Length
```

Analyze nested executables separately. Extraction is static evidence only and does not make the standard InstallForge launcher silent-capable.

### Inspect ARP and association evidence

```powershell
$Info.RegistryWrites | Where-Object Key -Match '\\Uninstall\\'
$Info.RegistryAssociationInfo
$Info.Protocols
$Info.FileExtensions
```

`WritesAppsAndFeaturesEntry` reflects the structured `Uninstaller=1` setting, but the parser does not invent the exact uninstall-key name; `ProductCode` remains null until explicit registry or VM evidence proves it.

### Confirm the silent-installation block

Do not submit an InstallForge-based installer unless the package provides a separate, verified silent-capable build or wrapper.

## Manifest shape

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

## WinGet defaults and overrides

WinGet supplies no InstallForge defaults for generic `InstallerType: exe`, and InstallForge does not provide a supported unattended installation mode. Do not fabricate silent switches or claim silent `InstallModes`; block WinGet submission unless the current package proves a separate supported mechanism.

## Apps & Features

Use structured parser evidence to identify the visible Apps & Features owner. Do not substitute metadata from a hidden or nested payload unless that payload writes the visible uninstall entry.

## Scope and architecture

Use explicit parser evidence for scope and installed payload architecture. Preserve existing manifest intent and use VM validation when either value is conditional or unresolved.

## VM validation

Complete the mandatory [VM validation workflow](../../workflows/vm-validation.md) for a claimed silent-capable wrapper or build. The standard InstallForge package remains blocked when it cannot install unattended.

## Known examples

InstallForge does not support unattended installation. Keep observed installers as rejection fixtures rather than accepted package examples.
