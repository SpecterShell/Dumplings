# install4j workflow

## When to use

Use `InstallerType: exe # install4j` when static evidence identifies an install4j launcher. WinGet does not have a dedicated install4j type.

Switch documentation: [install4j installer options](https://www.ej-technologies.com/resources/install4j/help/doc/installers/options.html).

## Detection

Start with `Get-Install4jFormatInfo`. It validates the launcher structure, selects the catalog route, and reports unsupported media without guessing metadata:

```powershell
$Format = Get-Install4jFormatInfo -Path $InstallerFile
$Format | Select-Object IsInstall4j, IsSupported, FormatGeneration, BuilderVersion, BuilderBuild, MediaType, Architecture, Marker, LauncherRoute, StartupFileRoute, ContentTableRoute, PayloadRoute, ConfigRoute, IsFallback, Diagnostics
```

Use `Test-Install4jInstaller` only when a Boolean family check is sufficient. Supporting evidence includes:

- `install4j` and `ej-technologies` launcher strings.
- Embedded or listed `i4jparams.conf` and `i4jruntime.jar`.
- `allinstdirs<dddd-dddd-dddd-dddd>`, where the numeric value is the application ID.
- An install4j unextracted-file table or LZMA-compressed `0.dat`.

Parameter `2000` is not mandatory in generated application media. When it is absent, a CRC-valid modern launcher with complete startup-file boundaries can be routed from the explicit builder version in its decoded `i4jparams.conf`. A present marker must agree with that configuration; the parser does not let configuration override a contradictory marker.

## Static analysis

Read [install4j Installers Parser Internals](../../internals/install4j/overview.md) before changing detection, extraction, binary decoding, or parser limits.

### Parse metadata and extract payload evidence

```powershell
$Info = Get-Install4jInfo -Path $InstallerFile
$Info.FormatGeneration
$Info.BuilderVersion
$Info.Marker
$Info.LauncherRoute
$Info.PayloadRoute
$Info.ConfigRoute
$Info.ProductCode
$Info.DisplayVersion
$Info.DisplayName
$Info.Publisher
$Info.WritesAppsAndFeaturesEntry
$Info.Scope
$Info.SupportedScopes
$Info.ScopeEvidence
$Info.Diagnostics
$Info.LauncherConfiguration.Entries
$Info.Config.Source

$ConfigPath = Expand-Install4jInstaller -Path $InstallerFile -Name 'i4jparams.conf' -CollisionAction Rename
$ExpandedPath = Expand-Install4jInstaller -Path $InstallerFile -Name '*.exe' -CollisionAction Rename
Get-ChildItem -Path $ExpandedPath -Recurse -File
```

`Get-Install4jInfo` creates one analysis context, selects a descriptor from `Install4jFormatCatalog.psd1`, reads the launcher maps and ContentCollector catalog, validates modern CRC32 evidence, decodes startup files, and parses `i4jparams.conf`. Read the returned object once instead of reparsing the installer with individual `Read-*FromInstall4j` helpers. Those helpers remain conveniences for callers that need only one field.

`Expand-Install4jInstaller` extracts transformed launcher startup files and ContentCollector entries. Generation 3 reads inline `content.zip`; generation 4 decodes the split `.000` LZMA archive; later generations decode the routed `0.dat` archive. It enforces CRC, dictionary, range, entry-count, and output limits and rejects links and traversal paths without invoking `7z.exe`.

### Determine whether install4j writes ARP

install4j `RegisterAddRemoveAction` creates:

```text
Software\Microsoft\Windows\CurrentVersion\Uninstall\<ApplicationId>
```

Use the application ID as top-level `ProductCode` when deterministic. Confirm `WritesAppsAndFeaturesEntry` from the parsed `RegisterAddRemoveAction` or the catalogued generation-3 built-in uninstaller evidence. Unsupported launchers and conditional registration still require VM ARP validation.

### Determine privilege-dependent scope and payload architecture

`RegisterAddRemoveAction` writes HKLM if writable and otherwise falls back to HKCU. Scope can depend on `RequestPrivilegesAction`, UAC availability, and whether install4j changes to a user-specific installation directory. Use parser evidence, but do not duplicate user/machine entries unless command-line scope selection is proven for that installer.

Read the launcher/config bitness and inspect installed native binaries. Do not infer application architecture from the uninstall registry path.

### Validate missing configuration and runtime fallbacks

Require VM validation when config XML is unavailable, scope depends on privilege fallback, ARP action presence is unknown, external/downloadable payloads affect the result, or package-specific unattended behavior differs from the documented defaults. A future-generation fallback is static evidence only until its install behavior is validated.

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

## Source references

- [install4j editions](https://www.ej-technologies.com/install4j/editions)
- [install4j change log](https://www.ej-technologies.com/install4j/changelog)
- [install4j media files](https://www.ej-technologies.com/resources/install4j/help/doc/concepts/mediaFiles.html)
- [install4j launcher concepts](https://www.ej-technologies.com/resources/install4j/help/doc/concepts/launchers.html)
- [install4j installer options](https://www.ej-technologies.com/resources/install4j/help/doc/installers/options.html)
