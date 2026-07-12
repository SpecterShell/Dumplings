# Actual Installer

## When To Use

Use `InstallerType: exe` for installers built with Actual Installer. Add a comment such as `InstallerType: exe # Actual Installer` when the existing manifest style accepts comments and the family evidence is strong.

## Detection

Strong evidence includes `Actual Installer`, `actualinstaller`, `aisetup.ini`, or Actual Installer language resources such as `Englishai.lng`. Some packages embed more than one ZIP archive; validate each ZIP range by its own end-of-central-directory record before opening it.

The tested `Softeza.ActualInstaller` installer `ActualInstallerFree10-online.exe` contains two valid embedded ZIP archives. The final archive contains `aisetup.ini`, language files, `ailogo.bmp`, and `7za.exe`. The earlier archive contains numbered payload entries.

## Manifest Shape

Actual Installer documents `/CU` for current-user installation and `/RUNAS /ALL` for elevated all-users installation. Keep scope-specific switches on each installer entry.

```yaml
Installers:
- Architecture: x86
  InstallerType: exe # Actual Installer
  Scope: user
  InstallerUrl: https://example.com/Product-1.2.3-x86.exe
  InstallerSha256: <SHA256>
  InstallModes:
  - interactive
  - silent
  - silentWithProgress
  InstallerSwitches:
    Silent: /S /L
    SilentWithProgress: /S /L
    Interactive: /L
    InstallLocation: /D "<INSTALLPATH>"
    Custom: /CU
- Architecture: x86
  InstallerType: exe # Actual Installer
  Scope: machine
  InstallerUrl: https://example.com/Product-1.2.3-x86.exe
  InstallerSha256: <SHA256>
  ElevationRequirement: elevatesSelf
  InstallModes:
  - interactive
  - silent
  - silentWithProgress
  InstallerSwitches:
    Silent: /S /L
    SilentWithProgress: /S /L
    Interactive: /L
    InstallLocation: /D "<INSTALLPATH>"
    Custom: /RUNAS /ALL
```

Add documented return-code mappings after checking the package version. Existing `Softeza.ActualInstaller` manifests map Actual Installer return codes such as `5`, `6`, `7`, `8`, `11`, `14`, `17`, `19`, `21` through `27`, and `100`.

## WinGet Defaults And Overrides

WinGet supplies no Actual Installer defaults for generic `InstallerType: exe`. Treat every switch in the shape as a complete family-specific override, explicitly state supported modes, and retain only values proved by parsed project metadata or VM behavior.

## Step-By-Step Analysis

### Step 1: Parse Embedded Archives And Installer Metadata

Prefer structured `aisetup.ini` metadata over arbitrary string probing. In the tested sample:

```powershell
$Info = Get-ActualInstallerInfo -Path C:\Path\To\Installer.exe
Expand-ActualInstallerInstaller -Path C:\Path\To\Installer.exe -Name aisetup.ini
```

The PackageModule parser validates each embedded ZIP range independently, selects the archive containing `aisetup.ini`, and returns its range, files, setup values, user/machine scope capability, and registry-action evidence. It returns build-time placeholders such as `AppVersion=<V>` as null with a warning rather than treating them as product versions.

- `[Setup] AppName=Actual Installer Free`
- `[Setup] CompanyName=Softeza Development`
- `[Setup] GUID={318020E9-4E14-DAB0-1CE4-2EE91C6FF5D0}`
- `[Setup] InstallDir=<AppData>\Actual Installer`
- `[Setup] AltInstallDir=<ProgramFiles>\Actual Installer`
- `[Setup] ShowAddRemove=1`
- `[Registry]` contains explicit registry writes for application settings.

Do not treat the `GUID` as WinGet `ProductCode` without confirming the visible Apps & Features entry. Actual Installer can write user or machine ARP entries depending on scope switches and elevation.

### Step 2: Resolve The Visible Uninstall Entry

Use `ShowAddRemove=1` as evidence that the installer intends to write an ARP entry. Use VM ARP delta validation when the exact uninstall key, display name, or scope matters for a new package.

### Step 3: Validate Online Payload And Conditional Behavior

When static metadata identifies multiple possible install roots or scope modes, validate in a VM with separate user and elevated machine runs.

## VM Validation

Follow [VM-Only Dynamic Validation Workflow](vm-validation-workflow.md) for online payload selection, user/machine scope switches, visible ARP identity, and conditional install roots.

## Known Actual Installer Package

- `Softeza.ActualInstaller`
