# Wise

## When To Use

Use `InstallerType: exe` when WinGet invokes a Wise Installation System EXE wrapper. The implemented parser currently supports the **Wise for Windows Installer** variant that embeds an MSI database; it does not claim support for every historical Wise generation.

## Detection

Route here when `Test-WiseInstaller` succeeds. The parser requires both Wise engine markers such as `WiseForWindowsInstaller`, `Wise for Windows Installer`, `.WISE`, or `WISE_SETUP_EXE_PATH` and a Compound File Binary whose root-storage CLSID is the MSI CLSID `{000C1084-0000-0000-C000-000000000046}`. A `Wise` string alone is not sufficient.

Detect It Easy may report `Installer: Wise Installer`. Treat that label as supporting evidence; use the Dumplings parser to prove the embedded MSI.

## Manifest Shape

This installer-entry shape matches the supported Wise MSI wrapper. Replace `INSTALLDIR` if the nested MSI reports a different install-location property.

```yaml
Installers:
- Architecture: x86
  InstallerType: exe # Wise MSI
  Scope: machine
  InstallerUrl: https://example.com/Product-1.2.3.exe
  InstallerSha256: <SHA256>
  InstallModes:
  - interactive
  - silent
  - silentWithProgress
  InstallerSwitches:
    Silent: /quiet /norestart
    SilentWithProgress: /passive /norestart
    InstallLocation: INSTALLDIR="<INSTALLPATH>"
    Log: /log "<LOGPATH>"
  ProductCode: <NestedMsiProductCode>
  AppsAndFeaturesEntries:
  - InstallerType: msi
```

Do not add `AppsAndFeaturesEntries.ProductCode` when it would only duplicate the installer-level `ProductCode`.

## WinGet Defaults And Overrides

WinGet supplies no Wise-wrapper defaults for generic `InstallerType: exe`. The supported Wise variant forwards MSI-style behavior, but every outer switch remains an explicit wrapper override. Keep no-reboot arguments, specify the supported modes, and use the nested MSI's verified install-location property rather than assuming `INSTALLDIR`.

## Step-By-Step Analysis

### Step 1: Parse And Extract The Embedded MSI

```powershell
$Info = Get-WiseInfo -Path $InstallerFile
$Msi = Expand-WiseInstaller -Path $InstallerFile

$Info.ProductCode
$Info.UpgradeCode
$Info.InstallLocationProperty
$Info.AppsAndFeaturesInstallerType
$Info.Protocols
$Info.FileExtensions
```

`Expand-WiseInstaller` validates the embedded CFB root CLSID before carving the MSI and never starts the setup. `Get-WiseInfo` then uses MSI tables for product identity, builder, scope, architecture, associations, install-location property, and visible ARP type.

### Step 2: Use The Nested MSI's Visible ARP Identity

Wise is the outer wrapper, not the authoritative ARP writer for this variant. Use the nested MSI evidence:

- Keep `ProductCode` and `UpgradeCode` from the MSI.
- Use `AppsAndFeaturesEntries.InstallerType: msi` when the visible entry has `WindowsInstaller=1`.
- Use `AppsAndFeaturesEntries.InstallerType: exe` only if the MSI parser proves a custom visible EXE-style ARP entry.
- Do not call an InstallShield-authored nested MSI a Wise-authored MSI. The wrapper and MSI builder are separate facts.

### Step 3: Determine Scope And Architecture From The MSI

Add `Scope: machine` when the nested MSI explicitly has `ALLUSERS=1`. Otherwise omit `Scope` unless VM validation proves it. Determine architecture from nested MSI template and installed binaries rather than the outer bootstrapper architecture.

### Step 4: Reject Or Validate Other Wise Generations

For another Wise generation, stop after detection and use bounded static extraction or VM validation. Do not assume this variant's MSI switches or ARP behavior apply to WiseScript, Wise Package Studio, or other Wise formats.

## VM Validation

Follow [VM-Only Dynamic Validation Workflow](vm-validation-workflow.md) for unsupported Wise generations or when the nested MSI's visible ARP type, scope, architecture, and wrapper exit-code propagation remain unresolved.

## Known Wise Packages

- `TexasInstruments.TIConnect`: Wise for Windows Installer wrapper containing an InstallShield-authored MSI. The nested MSI uses `INSTALLDIR`, writes a visible MSI ARP entry, and provides the package ProductCode and UpgradeCode.

## Implementation Sources

No external source-code repository is recorded in the parser module header.
