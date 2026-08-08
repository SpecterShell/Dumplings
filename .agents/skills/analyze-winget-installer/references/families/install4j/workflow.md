# install4j workflow

## When to use

Use `InstallerType: exe # install4j` when static evidence identifies an install4j launcher. WinGet does not have a dedicated install4j type.

Switch documentation: [install4j installer options](https://www.ej-technologies.com/resources/install4j/help/doc/installers/options.html).

## Detection

Prefer `Test-Install4jInstaller` and `Get-Install4jInfo`. Supporting markers include:

- `install4j` and `ej-technologies` launcher strings.
- Embedded or listed `i4jparams.conf` and `i4jruntime.jar`.
- `allinstdirs<dddd-dddd-dddd-dddd>`, where the numeric value is the application ID.
- An install4j unextracted-file table or LZMA-compressed `0.dat`.

## Static analysis

Read [install4j Installers Parser Internals](../../internals/install4j/overview.md) before changing detection, extraction, binary decoding, or parser limits.

### Parse metadata and extract payload evidence

```powershell
$Info = Get-Install4jInfo -Path $InstallerFile
$Info.ProductCode
$Info.DisplayVersion
$Info.DisplayName
$Info.Publisher
$Info.WritesAppsAndFeaturesEntry
$Info.Scope
$Info.SupportedScopes
$Info.ScopeEvidence
$Info.Warnings
$Info.LauncherConfiguration.Entries
$Info.Config.Source

$ConfigPath = Expand-Install4jInstaller -Path $InstallerFile -Name 'i4jparams.conf' -CollisionAction Rename
$ExpandedPath = Expand-Install4jInstaller -Path $InstallerFile -Name '*.exe' -CollisionAction Rename
Get-ChildItem -Path $ExpandedPath -Recurse -File
```

`Get-Install4jInfo` reads the launcher configuration block at the PE overlay, validates its declared range and CRC32, decodes the startup-file transform, and parses `i4jparams.conf`. Read the returned object once instead of reparsing the same installer with individual `Read-*FromInstall4j` helpers. Those helpers are compatibility conveniences for callers that need only one field.

`Expand-Install4jInstaller` extracts transformed launcher startup files and the separate embedded-file table. It validates and decodes standard LZMA-alone `0.dat` streams, then extracts selected files from the resulting ZIP without using `7z.exe`. It enforces CRC, dictionary, range, and output limits and rejects links and traversal paths.

### Determine whether install4j writes ARP

install4j `RegisterAddRemoveAction` creates:

```text
Software\Microsoft\Windows\CurrentVersion\Uninstall\<ApplicationId>
```

Use the application ID as top-level `ProductCode` when deterministic. Confirm `WritesAppsAndFeaturesEntry` from the parsed `RegisterAddRemoveAction`; older or unsupported launcher revisions may still require VM ARP validation.

### Determine privilege-dependent scope and payload architecture

`RegisterAddRemoveAction` writes HKLM if writable and otherwise falls back to HKCU. Scope can depend on `RequestPrivilegesAction`, UAC availability, and whether install4j changes to a user-specific installation directory. Use parser evidence, but do not duplicate user/machine entries unless command-line scope selection is proven for that installer.

Read the launcher/config bitness and inspect installed native binaries. Do not infer application architecture from the uninstall registry path.

### Validate missing configuration and runtime fallbacks

Require VM validation when config XML is unavailable, scope depends on privilege fallback, ARP action presence is unknown, or package-specific unattended behavior differs from the documented defaults.

## Manifest shape

```yaml
Installers:
- Architecture: x64
  InstallerType: exe # install4j
  InstallerUrl: https://example.com/Product-1.2.3-x64.exe
  InstallerSha256: <SHA256>
  InstallModes:
  - interactive
  - silent
  - silentWithProgress
  InstallerSwitches:
    Silent: -q -Dinstall4j.suppressUnattendedReboot=true
    SilentWithProgress: -q -splash "" -Dinstall4j.suppressUnattendedReboot=true
    InstallLocation: -dir "<INSTALLPATH>"
    Log: -Dinstall4j.log="<LOGPATH>"
  ProductCode: <ApplicationId>
```

Confirm package-specific unattended behavior before retaining these family defaults.

## WinGet defaults and overrides

WinGet supplies no family-specific switches for generic `InstallerType: exe`. Treat the install4j snippet as a complete family-specific override and verify it against the current launcher. Explicitly specify the supported `InstallModes`; keep reboot suppression in both silent values and omit any switch field the launcher does not support.

## Apps & Features

Use structured parser evidence to identify the visible Apps & Features owner. Do not substitute metadata from a hidden or nested payload unless that payload writes the visible uninstall entry.

## Scope and architecture

Use explicit parser evidence for scope and installed payload architecture. Preserve existing manifest intent and use VM validation when either value is conditional or unresolved.

## VM validation

Follow [VM validation workflow](../../workflows/vm-validation.md) for privilege fallback, unattended behavior, installed native architecture, and conditional ARP actions.

## Known examples

- `ZAP.ZAP`
- `Qoppa.PDFStudio`
- `CMU.Alice.3`
- `AsciidocFX.AsciidocFX`
- `PortSwigger.BurpSuite`
- `ej-technologies.exe4j`
- `ej-technologies.install4j`
- `ej-technologies.JProfiler`
- `ej-technologies.perfino`
- `PBH-BTN.PeerBanHelper`
- `Liquibase.Liquibase`
- `SmartBear.ReadyAPI`
- `SmartBear.ReadyAPILoadUIAgent`
- `SmartBear.ReadyAPITestEngine`
- `SmartBear.ReadyAPIVirtServer`
- `SmartBear.SoapUI`
- `QIAGEN.CLCGenomicsWorkbench`
- `QIAGEN.CLCMainWorkbench`
- `QIAGEN.CLCNetworkLicenseManager`
- `QIAGEN.CLCServerCommandLineTools`
- `Ringler.SnapformViewer`
- `OpenAudible.OpenAudible`
- `Ringler.SnapTaxForm685`
- `Fortra.GoAnywhereOpenPGPStudio`
- `SyncROSoft.OxygenJSONEditor`
- `SyncROSoft.OxygenPDFChemistry`
- `SyncROSoft.OxygenXMLAuthor`
- `SyncROSoft.OxygenXMLDeveloper`
- `SyncROSoft.OxygenXMLEditor`
- `3TSoftwareLabs.Studio3T`
- `VisualParadigm.VisualParadigm`.
