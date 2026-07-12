# Advanced Installer EXE Installer Type

Switch documentation: [Advanced Installer EXE setup file](https://www.advancedinstaller.com/user-guide/exe-setup-file.html).

## When To Use

Use `InstallerType: exe # Advanced Installer` when WinGet invokes an Advanced Installer bootstrapper EXE. Direct Advanced Installer MSI packages are covered in `installer-type-msi-wix.md`.

## Detection

Route here when `Get-AdvancedInstallerInfo` succeeds or static evidence contains Advanced Installer markers such as `Advanced Installer`, `aicustact`, or `AI_SETUPEXEPATH`.

Do not decide the visible Apps & Features type from the presence of an embedded MSI. Advanced Installer EXE packages can expose either MSI ARP entries or EXE-style ARP entries.

## Manifest Shape

Common Advanced Installer EXE fields:

```yaml
Installers:
- Architecture: x64
  InstallerType: exe # Advanced Installer
  Scope: machine
  InstallerUrl: https://example.com/Product-1.2.3-x64.exe
  InstallerSha256: <SHA256>
  InstallModes:
  - interactive
  - silent
  - silentWithProgress
  InstallerSwitches:
    Silent: /exenoui /quiet /norestart
    SilentWithProgress: /exenoui /passive /norestart
    InstallLocation: APPDIR="<INSTALLPATH>"
    Log: /log "<LOGPATH>"
  ExpectedReturnCodes:
  - InstallerReturnCode: -1
    ReturnResponse: cancelledByUser
  - InstallerReturnCode: 1
    ReturnResponse: invalidParameter
  - InstallerReturnCode: 87
    ReturnResponse: invalidParameter
  - InstallerReturnCode: 1601
    ReturnResponse: contactSupport
  - InstallerReturnCode: 1602
    ReturnResponse: cancelledByUser
  - InstallerReturnCode: 1618
    ReturnResponse: installInProgress
  - InstallerReturnCode: 1623
    ReturnResponse: systemNotSupported
  - InstallerReturnCode: 1625
    ReturnResponse: blockedByPolicy
  - InstallerReturnCode: 1628
    ReturnResponse: invalidParameter
  - InstallerReturnCode: 1633
    ReturnResponse: systemNotSupported
  - InstallerReturnCode: 1638
    ReturnResponse: alreadyInstalled
  - InstallerReturnCode: 1639
    ReturnResponse: invalidParameter
  - InstallerReturnCode: 1640
    ReturnResponse: blockedByPolicy
  - InstallerReturnCode: 1641
    ReturnResponse: rebootInitiated
  - InstallerReturnCode: 1643
    ReturnResponse: blockedByPolicy
  - InstallerReturnCode: 1644
    ReturnResponse: blockedByPolicy
  - InstallerReturnCode: 1649
    ReturnResponse: blockedByPolicy
  - InstallerReturnCode: 1650
    ReturnResponse: invalidParameter
  - InstallerReturnCode: 1654
    ReturnResponse: systemNotSupported
  - InstallerReturnCode: 3010
    ReturnResponse: rebootRequiredToFinish
  ProductCode: <ProductCode>
```
## Manifest Shape: MSI ARP Entry

Use this variant when static extraction and VM evidence show the visible ARP entry is MSI-based:

```yaml
Installers:
- Architecture: x64
  AppsAndFeaturesEntries:
  - UpgradeCode: <UpgradeCode>
    InstallerType: msi
```

Use the embedded MSI `ProductCode`/`UpgradeCode` values for correlation. Add `AppsAndFeaturesEntries[0].InstallerType: msi` only when the package manifest needs to distinguish the visible MSI ARP entry from the outer EXE installer type.

## Manifest Shape: EXE ARP Entry

Use this variant when the embedded MSI ARP entry is hidden with `SystemComponent` or is not the visible primary ARP entry:

```yaml
Installers:
- Architecture: x64
  ProductCode: <CustomARPProductCode>
  AppsAndFeaturesEntries:
  - InstallerType: exe
```

Do not assume the embedded MSI `ProductCode` is visible in Apps & Features. Use the custom ARP key/value returned by static parsing or VM ARP deltas.

## WinGet Defaults And Overrides

WinGet supplies no family-specific switches for `InstallerType: exe`. Treat the Advanced Installer values in the selected manifest shape as complete overrides. Specify the complete `InstallModes` array, remove fields not supported by the current bootstrapper, and retain `/norestart` in both silent variants. Do not copy MSI defaults merely because the EXE embeds an MSI.

## Step-By-Step Analysis

### Step 1: Parse The Bootstrapper And Embedded MSI

Use `Modules\PackageModule\Libraries\AdvancedInstaller.psm1` without running the installer:

```powershell
Import-Module .\Modules\PackageModule\Libraries\AdvancedInstaller.psm1 -Force

$Info = Get-AdvancedInstallerInfo -Path $InstallerFile
$MsiInfo = Get-AdvancedInstallerMsiInfo -Path $InstallerFile
$MsiInfo.AppsAndFeaturesInstallerType
$MsiInfo.AppsAndFeaturesProductCode
$MsiInfo.InstallLocationSwitch
```

`Get-AdvancedInstallerMsiInfo` should decide the embedded MSI builder metadata, install-location property, visible ARP type, and Apps & Features product code. Prefer its `InstallLocationSwitch` over hard-coding `APPDIR` when present.

### Step 2: Resolve The Visible Apps & Features Entry

Advanced Installer can hide the native MSI ARP entry and write a custom uninstall key, for both MSI and EXE packages. Use `AppsAndFeaturesInstallerType` to decide whether `AppsAndFeaturesEntries[0].InstallerType` should be `msi` or `exe`.

If static extraction fails or the ARP visibility remains ambiguous, use VM validation and compare uninstall-key deltas excluding `SystemComponent=1`.

### Step 3: Validate Unresolved Payload And Runtime Behavior

Do not extract large non-MSI payloads unless needed for evidence. For download-and-execute bootstrappers, capture network traffic in a VM if the embedded payload cannot be resolved statically.

## VM Validation

Follow [VM-Only Dynamic Validation Workflow](vm-validation-workflow.md) to distinguish visible MSI and custom EXE ARP entries, including hidden `SystemComponent=1` entries, and to verify wrapper exit-code forwarding.

## Implementation Sources

- [HydraDragonAntivirus](https://github.com/HydraDragonAntivirus/HydraDragonAntivirus)
- [Komac](https://github.com/russellbanks/Komac)
