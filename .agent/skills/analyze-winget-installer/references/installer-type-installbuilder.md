# InstallBuilder

## When To Use

Use `InstallerType: exe` for BitRock/VMware InstallBuilder installers.

## Detection

Strong evidence includes `InstallBuilder`, `BitRock InstallBuilder`, `BitRock`, `unattendedmodeui`, or `--mode unattended` strings.

## Manifest Shape

```yaml
Installers:
- Architecture: x64
  InstallerType: exe # InstallBuilder
  InstallerUrl: https://example.com/Product-1.2.3-x64.exe
  InstallerSha256: <SHA256>
  InstallModes:
  - interactive
  - silent
  - silentWithProgress
  InstallerSwitches:
    Silent: --mode unattended
    SilentWithProgress: --mode unattended --unattendedmodeui minimal
    InstallLocation: --prefix "<INSTALLPATH>"
    Log: --debugtrace "<LOGPATH>"
```

## WinGet Defaults And Overrides

WinGet supplies no InstallBuilder defaults for generic `InstallerType: exe`. Treat mode, prefix/location, logging, and license switches as complete overrides and explicitly state supported modes. The GUI help window is evidence only; static parser and VM behavior must confirm accepted values.

## Step-By-Step Analysis

### Step 1: Parse Project Metadata And Expand Payloads

InstallBuilder installers commonly show a GUI help window when invoked with `--help`; that window may disappear after a few seconds. Do not call `--help` from automation.

Use the parser to recover the zlib-compressed `project.xml` and unencrypted CookFS payload files from the embedded Metakit VFS without loading TclKit, mounting CookFS, or executing project Tcl code:

```powershell
$Info = Get-InstallBuilderInfo -Path C:\Path\To\Installer.exe
Expand-InstallBuilderInstaller -Path C:\Path\To\Installer.exe -Name project.xml
Expand-InstallBuilderInstaller -Path C:\Path\To\Installer.exe -Name 'payload/setup.msi'
```

The parser reads `shortName`, `fullName`, `version`, `vendor`, `requireInstallationByRootUser`, built-in uninstaller actions, literal `registrySet` actions, and the CookFS `CFS0002` file index. `PayloadFiles` lists logical payload paths; `___bitrockBigFileN` segments are reassembled under their base file name during extraction. Supported unencrypted page encodings are raw, Deflate, BZip2, and the InstallBuilder `lzmadec` LZMA-alone form.

It uses `<shortName> <version>` only as candidate ProductCode evidence, because that is the common InstallBuilder uninstaller-key convention, not proof of the visible ARP key. Unknown custom compression and encrypted payload markers such as `tcltwofish` or `installbuilder.payloadinfo` require the project password and must be treated as unsupported. Use VM ARP deltas to confirm the visible entry and scope when the project XML cannot prove them.

### Step 2: Resolve Uninstaller And ARP Identity

`requireInstallationByRootUser=1` proves machine scope. Projects that branch on `${installer_is_root_install}` and contain both HKCU/HKLM uninstall paths are reported as dual-scope evidence, with user as the non-elevated default. Decide the visible ARP key, `WindowsInstaller` value, and exact `AppsAndFeaturesEntries` values from literal `registrySet` evidence or VM ARP deltas.

### Step 3: Validate GUI Help And Runtime Conditions

Verify whether the package supports user or machine scope before setting `Scope`.

## VM Validation

Follow [VM-Only Dynamic Validation Workflow](vm-validation-workflow.md) when scope, unattended UI mode, required `--prefix`, overwrite behavior, or visible ARP registration remains conditional.

## Known InstallBuilder Packages

- `Phrase.Phrase`
- `Lansweeper.LsAgent`
- `JinweiZhiguang.Lanhu.Photoshop`
- `Hex-Rays.IDA.Free`
- `LiteratureAndLatte.Scrivener`
- `OpenSourcePhysics.Tracker`
- `PawelSalawa.SQLiteStudio`
- `ApacheFriends.Xampp.8`
- `PostgreSQL.PostgreSQL.9`
- `PostgreSQL.PostgreSQL.10`
- `PostgreSQL.PostgreSQL.11`
- `PostgreSQL.PostgreSQL.12`
- `PostgreSQL.PostgreSQL.13`
- `PostgreSQL.PostgreSQL.14`
- `PostgreSQL.PostgreSQL.15`
- `PostgreSQL.PostgreSQL.16`
- `PostgreSQL.PostgreSQL.17`
- `PostgreSQL.PostgreSQL.18`
- `Autodesk.LicensingService`
- `Graphisoft.BIMxDesktopViewer`

## Implementation Sources

- [InstallBuilder loader research](https://gist.github.com/mickael9/0b902da7c13207d1b86e)
