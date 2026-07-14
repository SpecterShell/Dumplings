# MSIX And AppX Installer Type

## When To Use

Use `InstallerType: msix` for `.msix` and `.msixbundle` URLs, or `InstallerType: appx` for `.appx` and `.appxbundle` URLs. Do not use `.appinstaller` URLs as manifest installers.

## Detection

Route here when ZIP content contains `AppxManifest.xml`, `AppxMetadata/AppxBundleManifest.xml`, or `AppxSignature.p7x`, even if the extension is wrong. Also route here for `.appinstaller` metadata, but parse `MainPackage` or `MainBundle`, then analyze the resolved package URL.

## Manifest Shape

```yaml
Installers:
- Platform:
  - Windows.Desktop
  MinimumOSVersion: 10.0.17763.0
  Architecture: x64
  InstallerType: msix
  InstallerUrl: https://example.com/Product-1.2.3-x64.msix
  InstallerSha256: <SHA256>
  SignatureSha256: <APPX_SIGNATURE_SHA256>
  Dependencies:
    PackageDependencies:
    - PackageIdentifier: Microsoft.VCLibs.Desktop.14
      MinimumVersion: 14.0.30704.0
  PackageFamilyName: Publisher.Package_abcdefghijklm
  Capabilities:
  - internetClient
  RestrictedCapabilities:
  - runFullTrust
```

WinGet accepts `.appx` and `.appxbundle` under `InstallerType: appx`, and `.msix` and `.msixbundle` under `InstallerType: msix`. The WinGet manifest schema does not expose separate `appxbundle` or `msixbundle` installer-type values.

`.appinstaller` is not accepted by winget-pkgs manifests. Treat it as update metadata only: parse the `.appinstaller` file, find `MainPackage` or `MainBundle`, then use that real `.appx`, `.appxbundle`, `.msix`, or `.msixbundle` URL as `InstallerUrl`. Examples of `.appinstaller`-sourced packages include `OrbForge.Orb`, `Dalux.Dalux`, `DuckDuckGo.DesktopBrowser`, `TheBrowserCompany.Arc`, and `Python.PythonInstallManager`.

These fields must be filled when present in package metadata:

- `Platform`
- `MinimumOSVersion`
- `Dependencies`
- `PackageFamilyName`
- `Capabilities`
- `RestrictedCapabilities`
- `SignatureSha256`

Omit `Capabilities` or `RestrictedCapabilities` only when the package manifest does not declare them.

For `Dependencies`, include only these framework package families in WinGet manifests:

- `Microsoft.VCLibs.Desktop.14`
- `Microsoft.VCLibs.14`
- `Microsoft.WindowsAppRuntime.*.*`
- `Microsoft.UI.Xaml.*.*`

Preserve `MinimumVersion` when the MSIX/AppX manifest declares `MinVersion`. If the package XML declares other `PackageDependency` names, do not write them into `Dependencies`; report them as unknown dependencies for manual review. Current examples with allowed dependency packages include `Elgato.WaveLink`, `BicomSystems.gloCOM`, `FilesCommunity.Files`, `Microsoft.WindowsApp`, `TheBrowserCompany.Arc`, `Elgato.Studio`, `CharlesMilette.TranslucentTB`, and `Microsoft.FoundryLocal`.

MSIX/AppX-family packages must have a signature that is valid and trusted by the local system certificate roots. Reject packages that have no embedded `AppxSignature.p7x`, no Authenticode signature, or `Get-AuthenticodeSignature` does not return `Status: Valid`.

Known signature-validation examples:

- `Chill-Astro.LaminaCalculator`: `Lamina_11.28000.16.0_x64.msix` is signed but not trusted on this system, so it must be rejected.
- `Microsoft.XmlNotepad`: `XmlNotepadPackage_2.9.0.17_AnyCPU.msixbundle` is unsigned, so it must be rejected.
- `Microsoft.XmlNotepad`: `XmlNotepadPackage_2.9.0.20_AnyCPU.msixbundle` is signed and trusted on this system, so it can be authored if the remaining metadata is valid.

## WinGet Defaults And Overrides

MSIX/AppX deployment does not use EXE command-line switch fields. Omit `InstallModes` and `InstallerSwitches`; reject untrusted or unsigned packages as described below rather than attempting to compensate with custom arguments.

## Step-By-Step Analysis

### Step 1: Parse Package Identity, Dependencies, And Signature

Use `Modules\PackageModule\Libraries\MSIX.psm1` to read package metadata without installing the package:

```powershell
Import-Module .\Modules\PackageModule\Libraries\MSIX.psm1 -Force

$KnownInstallerType = $null # Set to appx or msix when preserved from the source URL, appinstaller, or existing manifest.
$InfoParameters = @{ Path = $InstallerFile }
if ($KnownInstallerType) { $InfoParameters.InstallerTypeHint = $KnownInstallerType }
$Info = Get-MSIXInfo @InfoParameters

$InstallerType = $Info.InstallerType
$PackageKind = $Info.PackageKind
$PackageFamilyName = $Info.PackageFamilyName
$ProductVersion = $Info.Version
$Platform = $Info.Platform
$MinimumOSVersion = $Info.MinimumOSVersion
$Dependencies = $Info.Dependencies
$UnknownDependencies = $Info.UnknownPackageDependencies
$Warnings = $Info.Warnings
$Capabilities = $Info.Capabilities
$RestrictedCapabilities = $Info.RestrictedCapabilities
$SignatureSha256 = $Info.SignatureSha256
$SignatureStatus = Get-AuthenticodeSignature -LiteralPath $InstallerFile
if ($SignatureStatus.Status -ne 'Valid') { throw "Reject MSIX/AppX package: $($SignatureStatus.StatusMessage)" }
```

Use `Get-MSIXInfo` as the preferred single call; it returns installer type, package kind (`Package` or `Bundle`), type evidence and ambiguity, identity, architecture, platform, minimum OS version, package family name, filtered dependencies, unknown dependencies, warnings, capabilities, restricted capabilities, signature hash, and Apps & Features display evidence. For bundles, it reads nested package manifests when available.

`Get-MSIXPackageKind` identifies direct packages and bundles from `AppxManifest.xml` or `AppxMetadata/AppxBundleManifest.xml`, independent of the outer filename. `Get-MSIXPackageTypeInfo` prefers the original URL extension, an explicit installer-type hint, or HTTP content type. An extensionless bundle can also use payload filenames from its bundle manifest. A direct AppX package and direct MSIX package cannot be distinguished reliably from package structures alone; in that case the helper returns the WinGet-compatible `msix` fallback with `IsAmbiguous: true` and a warning. Preserve a known `appx` type from the original URL, `.appinstaller`, or existing manifest by passing `-InstallerTypeHint appx`.

`Read-DependenciesFromMSIX` returns only allowlisted dependency packages suitable for WinGet manifests. `Get-MSIXInfo.UnknownPackageDependencies` returns other XML `PackageDependency` entries found in the package, and `Get-MSIXInfo.Warnings` includes messages such as unknown dependency packages being omitted from manifest dependencies.

Dependency filtering helpers:

```powershell
Test-MSIXAllowedDependencyPackage -PackageIdentifier 'Microsoft.WindowsAppRuntime.1.7'
$DependencyInfo = ConvertTo-MSIXManifestDependencyInfo -PackageDependencies $RawPackageDependencies
```

If `$Info.UnknownPackageDependencies` is not empty, warn in the analysis result and inspect whether the dependency is a true external framework, a packaged optional component, or metadata that should not be represented in winget-pkgs.

Use `Get-WinGetInstallerAnalysis -Path $InstallerFile` when PackageModule is loaded and check `BlockingIssues` before authoring. The analyzer treats missing signatures and signatures that are not trusted by the system as blocking issues.

For `.appinstaller` metadata:

```powershell
Import-Module .\Modules\PackageModule\Libraries\MSIX.psm1 -Force

$AppInstallerInfo = Get-AppInstallerInfo -Uri 'https://bim.dalux.com/Desktop/Dalux.appinstaller'
$InstallerUrl = $AppInstallerInfo.InstallerUrl
$InstallerType = $AppInstallerInfo.InstallerType
```

Download the resolved `$InstallerUrl`, then run `Get-MSIXInfo` on the actual package to fill manifest fields. Do not put the `.appinstaller` URL in `InstallerUrl`.

### Step 2: Record Packaged-App Identity And Display Evidence

MSIX/AppX packages use package identity metadata rather than MSI-style uninstall registry keys. Use `PackageFamilyName`, identity version, publisher identity, and signature metadata from `Get-MSIXInfo` instead of MSI `ProductCode`/`UpgradeCode` fields.

For dynamic validation in a VM, use installed package identity rather than ARP-only scanning:

```powershell
$InstalledPackages = Get-WinGetInstalledAppXEntry
$InstalledPackages | Where-Object PackageFamilyName -eq $PackageFamilyName
```

Use `Find-WinGetManifestInstalledEntryMatch` when comparing a manifest against installed AppX/MSIX entries; it checks `PackageFamilyName` exact matches.

## VM Validation

Follow [VM-Only Dynamic Validation Workflow](vm-validation-workflow.md) only when package registration, runtime dependency availability, first-run associations, or upgrade behavior cannot be established from the signed package manifests.

## Implementation Sources

- [MSIX Packaging](https://github.com/microsoft/msix-packaging)
