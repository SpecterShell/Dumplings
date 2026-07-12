# install4j Installers

## When To Use

Use `InstallerType: exe # install4j` when static evidence identifies an install4j launcher. WinGet does not have a dedicated install4j type.

Switch documentation: [install4j installer options](https://www.ej-technologies.com/resources/install4j/help/doc/installers/options.html).

## Detection

Prefer `Test-Install4jInstaller` and `Get-Install4jInfo`. Supporting markers include:

- `install4j` and `ej-technologies` launcher strings.
- Embedded or listed `i4jparams.conf` and `i4jruntime.jar`.
- `allinstdirs<dddd-dddd-dddd-dddd>`, where the numeric value is the application ID.
- An install4j unextracted-file table or LZMA-compressed `0.dat`.

## Manifest Shape

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

## WinGet Defaults And Overrides

WinGet supplies no family-specific switches for generic `InstallerType: exe`. Treat the install4j snippet as a complete family-specific override and verify it against the current launcher. Explicitly specify the supported `InstallModes`; keep reboot suppression in both silent values and omit any switch field the launcher does not support.

## Step-By-Step Analysis

### Step 1: Parse Metadata And Extract Payload Evidence

```powershell
$Info = Get-Install4jInfo -Path $InstallerFile
$Info.ProductCode
$Info.DisplayVersion
$Info.ProductName
$Info.Publisher
$Info.WritesAppsAndFeaturesEntry
$Info.Scope
$Info.SupportedScopes
$Info.ScopeEvidence
$Info.Warnings

Read-ProductCodeFromInstall4j -Path $InstallerFile
Read-ProductVersionFromInstall4j -Path $InstallerFile
Read-ProductNameFromInstall4j -Path $InstallerFile
Read-PublisherFromInstall4j -Path $InstallerFile
Read-ScopeFromInstall4j -Path $InstallerFile
Read-SupportedScopesFromInstall4j -Path $InstallerFile

$ExpandedPath = Expand-Install4jInstaller -Path $InstallerFile -Name '*.exe'
Get-ChildItem -Path $ExpandedPath -Recurse -File
```

`Get-Install4jInfo` parses extracted or directly embedded `i4jparams.conf` XML when available. For launchers that pack application content into `0.dat`, it can still recover `ProductCode` from `allinstdirs<ApplicationId>` and use PE version resources for name, version, and publisher.

`Expand-Install4jInstaller` reads the embedded-file table. It validates and decodes standard LZMA-alone `0.dat` streams, then extracts selected files from the resulting ZIP without using `7z.exe`. It enforces dictionary/output limits and rejects links and traversal paths. The decoded application ZIP normally does not contain `i4jparams.conf`; payload extraction and installer-config parsing remain separate operations.

### Step 2: Determine Whether install4j Writes ARP

install4j `RegisterAddRemoveAction` creates:

```text
Software\Microsoft\Windows\CurrentVersion\Uninstall\<ApplicationId>
```

Use the application ID as top-level `ProductCode` when deterministic. Do not assume the action exists when config XML was not recovered; use VM ARP validation when `WritesAppsAndFeaturesEntry` is unknown.

### Step 3: Determine Privilege-Dependent Scope And Payload Architecture

`RegisterAddRemoveAction` writes HKLM if writable and otherwise falls back to HKCU. Scope can depend on `RequestPrivilegesAction`, UAC availability, and whether install4j changes to a user-specific installation directory. Use parser evidence, but do not duplicate user/machine entries unless command-line scope selection is proven for that installer.

Read the launcher/config bitness and inspect installed native binaries. Do not infer application architecture from the uninstall registry path.

### Step 4: Validate Missing Configuration And Runtime Fallbacks

Require VM validation when config XML is unavailable, scope depends on privilege fallback, ARP action presence is unknown, or package-specific unattended behavior differs from the documented defaults.

## VM Validation

Follow [VM-Only Dynamic Validation Workflow](vm-validation-workflow.md) for privilege fallback, unattended behavior, installed native architecture, and conditional ARP actions.

## Known install4j Packages

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
