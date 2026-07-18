# InstallAware

## When To Use

Use `InstallerType: exe` for InstallAware setup EXEs.

## Detection

Strong evidence includes `InstallAware` or `MimarSinan` strings.

### Parser API

```powershell
$Info = Get-InstallAwareInfo -Path $InstallerPath
Expand-InstallAwareInstaller -Path $InstallerPath -DestinationPath $DestinationPath
```

The parser requires a validated embedded 7z archive with InstallAware project
evidence; a string match alone is insufficient. It reports PE identity,
requested elevation, nested setup files, protocols, and file extensions.
Current project metadata does not prove a visible uninstall key, so keep
`ProductCode` unset until explicit payload or VM evidence is available.

## Binary Structure

The supported InstallAware parser recognizes standard 7z archives embedded in a PE launcher and requires InstallAware-specific project entries inside the archive.

```text
PE setup launcher
`-- one or more embedded 7z ranges
    +-- 37 7A BC AF 27 1C          7z signature
    +-- 7z catalog
    +-- mia.lib / *.mia            project evidence
    +-- _setup.exe / resources     nested setup logic
    `-- data/ and payload entries
```

Each 7z candidate is opened as a bounded archive and ranked by structured entry evidence. The parser does not claim an undocumented InstallAware header around the standard archive. PE requested-execution-level and version resources are separate supporting layers; nested MSI/EXE files must be routed independently.

## Manifest Shape

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

## WinGet Defaults And Overrides

WinGet supplies no InstallAware defaults for generic `InstallerType: exe`. Treat the family switches as complete overrides, explicitly state supported modes, and preserve no-reboot behavior in silent variants. Do not infer MSI forwarding unless the parser proves a nested MSI command.

## Step-By-Step Analysis

### Step 1: Parse InstallAware Metadata And Payloads

Load PackageModule, parse once, and inspect the validated embedded archive:

```powershell
. .\Modules\PackageModule\Index.ps1

$Info = Get-InstallAwareInfo -Path $InstallerPath
$Info | Select-Object DisplayName, DisplayVersion, Publisher, Scope, SupportedScopes,
  RequestedExecutionLevel, WritesAppsAndFeaturesEntry, NestedInstallerFiles, MsiPayloads, Warnings
```

### Step 2: Extract And Analyze Nested Installers

```powershell
$Files = Expand-InstallAwareInstaller -Path $InstallerPath -DestinationPath $DestinationPath
$Files | Where-Object Extension -In '.exe', '.msi', '.msp', '.msix', '.appx' | ForEach-Object {
  Get-WinGetInstallerAnalysis -Path $_.FullName
}
```

Use `-Name` to extract a specific entry when full extraction is unnecessary. A nested MSI/MSP must be analyzed as a Windows Installer database; the outer InstallAware family does not prove that the MSI owns the visible ARP entry.

### Step 3: Resolve Outer Or Nested ARP Ownership

```powershell
$Info.RegistryWrites | Where-Object Key -Match '\\Uninstall\\'
$Info.RegistryAssociationInfo
$Info.Protocols
$Info.FileExtensions
```

Current InstallAware project parsing does not prove a visible uninstall key, so `ProductCode` and `WritesAppsAndFeaturesEntry` remain null. Some packages are MSI-backed and may forward MSI properties. Decide visible ARP type from nested database evidence or VM ARP deltas, not from the outer EXE family.

### Step 4: Validate Conditional Scripts And Exit Codes

Confirm exact switches and restart behavior per package.

## VM Validation

Follow [VM-Only Dynamic Validation Workflow](vm-validation-workflow.md) for MSI-backed property forwarding, custom scripts, restart behavior, exit codes, and visible ARP type.

## Known InstallAware Packages

- `OpenSight.FlashFXP`
- `MaestroSoft.MaestroAarsoppgjoer`
