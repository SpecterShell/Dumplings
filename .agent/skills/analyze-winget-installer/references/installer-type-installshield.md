# InstallShield Installer Type

Switch documentation: [InstallShield setup.exe command-line parameters](https://docs.revenera.com/installshield26helplib/helplibrary/IHelpSetup_EXECmdLine.htm).

## When To Use

Use `InstallerType: exe # InstallShield` when WinGet invokes an InstallShield EXE wrapper. Direct InstallShield-authored MSI packages are covered in `installer-type-msi-wix.md`.

InstallShield Advanced UI is a separate EXE family with different switches. Do not apply Basic MSI switches to Advanced UI unless package-specific evidence proves they work.

## Detection

Route here when `Get-InstallShieldInfo` succeeds, static strings contain `InstallShield`, `ISSetup.dll`, `InstallScript`, `setup.inx`, or package history strongly suggests InstallShield.

Classify the variant before writing manifest fields:

- Basic MSI: MSI can be extracted or identified.
- InstallScript MSI: MSI exists but InstallScript bootstrapper behavior may still matter.
- InstallScript-only: no MSI payload; often requires response-file replay.
- Advanced UI: not the same as Basic MSI/InstallScript MSI.

Block InstallScript-only installers when silent installation requires a response file, because response-file replay is not accepted by winget-pkgs validation.

## Manifest Shape

Use this only when MSI extraction/metadata and silent behavior are verified:

```yaml
Installers:
- Architecture: x64
  InstallerType: exe # InstallShield
  Scope: machine
  InstallerUrl: https://example.com/Product-1.2.3-x64.exe
  InstallerSha256: <SHA256>
  InstallModes:
  - interactive
  - silent
  - silentWithProgress
  InstallerSwitches:
    Silent: /S /V/quiet /V/norestart
    SilentWithProgress: /S /V/passive /V/norestart
    InstallLocation: /V"INSTALLDIR=""<INSTALLPATH>"""
    Log: /V"/log ""<LOGPATH>"""
  ProductCode: <ProductCode>
  AppsAndFeaturesEntries:
  - UpgradeCode: <UpgradeCode>
    InstallerType: msi
```

Known MSI-backed InstallShield examples:

- `Zultys.ZAC`
- `Robomatter.ROBOTC.LEGOMindstorms`
- `Robomatter.ROBOTC.VEXRobotics`
- `Robomatter.RobotVirtualWorlds.ChallengePack`
- `Robomatter.RobotVirtualWorlds.CurriculumCompanion`
- `Robomatter.RobotVirtualWorlds.FTCCascadeEffect`
- `Robomatter.RobotVirtualWorlds.LevelBuilder`
- `Robomatter.RobotVirtualWorlds.MiniUrbanChallenge`
- `Robomatter.RobotVirtualWorlds.OperationReset`
- `Robomatter.RobotVirtualWorlds.PalmIslandLuauEdition`
- `Robomatter.RobotVirtualWorlds.RuinsOfAtlantis`
- `Robomatter.RobotVirtualWorlds.VEXIQHighrise`
- `Robomatter.RobotVirtualWorlds.VEXIQNextLevel`
- `Robomatter.RobotVirtualWorlds.VRCTurningPoint`
- `Abbott.LibreViewDeviceDrivers`
- `Sonos.Controller`
- `Sonos.S1Controller`
- `LANCOM.LANconfig`
- `LANCOM.LANmonitor`
- `LANCOM.TrustedAccessClient`
- `LANCOM.WirelessePaperServer`
- `Thorlabs.APT.x64`
- `Thorlabs.APT.x86`
- `Thorlabs.ELLO`
- `Thorlabs.Kinesis.x64`
- `Thorlabs.Kinesis.x86`
- `Thorlabs.MC2000`
- `Thorlabs.MCLS2`
- `Thorlabs.PCD1K`
- `Thorlabs.SA201B`
- `Thorlabs.SC30`
- `Thorlabs.ThorAOControl`
- `Thorlabs.ThorlabsDeviceSDK`
- `Thorlabs.TSP01`
- `Thorlabs.XA`
- `Thorlabs.xPlatform`
- `BioSilico.IdeaMapper`
- `BioSilico.IdeaMapper.HigherEd`
- `BioSilico.IdeaMapper.K12`
- `BioSilico.IdeaMapper.Pro`
- `Mitel.MitelConnect`
- `MindGenius.MindGenius.20`
- `Pathloss.AntRad`
- `DYMO.DYMOConnect`
- `DYMO.DYMOID`
- `DYMO.DYMOLabel`
- `DYMO.PrintServerControlCenter`
- `NWEA.NWEASecureTestingBrowser`

## Manifest Shape: InstallShield InstallScript

Use this shape only when `Get-InstallShieldInfo` reports `HasMsi: false`, `HasInstallScript: true`, and `Variant: InstallScript`. The absence of an MSI means the InstallScript engine owns installation and ARP behavior; do not apply Basic MSI `/V...` forwarding switches or derive ProductCode/UpgradeCode from a nonexistent nested database.

Most InstallScript installers require recording and replaying a `setup.iss` response file for unattended installation. That package-specific response-file input is not supported by winget-pkgs validation, so block the package unless static documentation and VM validation prove a response-file-free silent path.

`Celsys.ClipStudioPaint` is the known exception: its InstallScript setup accepts `/s` without a response file.

```yaml
Installers:
- Architecture: x64
  InstallerType: exe # InstallShield InstallScript
  InstallerUrl: https://example.com/Product-1.2.3-x64.exe
  InstallerSha256: <SHA256>
  InstallerSwitches:
    Silent: /s
    SilentWithProgress: /s
  ProductCode: <VerifiedInstallScriptUninstallKey>
```

Known InstallShield InstallScript package:

- `Celsys.ClipStudioPaint`

## Manifest Shape: InstallShield Advanced UI

Use this only for InstallShield Advanced UI packages that accept these switches:

```yaml
Installers:
- Architecture: x64
  InstallerType: exe # InstallShield Advanced UI
  Scope: machine
  InstallerUrl: https://example.com/Product-1.2.3-x64.exe
  InstallerSha256: <SHA256>
  InstallerSwitches:
    Silent: /silent
    SilentWithProgress: /passive
    InstallLocation: /INSTALLDIR="<INSTALLPATH>"
  ExpectedReturnCodes:
  - InstallerReturnCode: 0x8004070b
    ReturnResponse: invalidParameter
  - InstallerReturnCode: 0x80040711
    ReturnResponse: installInProgress
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
  - InstallerReturnCode: 1641
    ReturnResponse: rebootInitiated
  - InstallerReturnCode: 1640
    ReturnResponse: blockedByPolicy
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

Known Advanced UI examples:
- `Trimble.SketchUp`
- `Trimble.SketchUpViewer`.

## WinGet Defaults And Overrides

WinGet supplies no InstallShield-specific defaults for outer `InstallerType: exe`. Treat each shown switch as a complete override for the proven InstallShield variant. Preserve no-reboot arguments in silent modes, and do not apply Basic MSI forwarding switches to InstallScript-only or Advanced UI packages.

## Step-By-Step Analysis

### Step 1: Classify And Parse The InstallShield Variant

Use `Modules\PackageModule\Libraries\InstallShield.psm1` to extract and classify InstallShield payloads without running the installer or shelling out to `ISx.exe`. The module contains an in-process parser based on the ISx container format; see the [ISx source repository](https://github.com/lifenjoiner/ISx).

```powershell
Import-Module .\Modules\PackageModule\Libraries\InstallShield.psm1 -Force

$Info = Get-InstallShieldInfo -Path $InstallerFile
$MsiInfo = Get-InstallShieldMsiInfo -Installer $Info

$ProductVersion = Read-ProductVersionFromInstallShield -Installer $Info
$ProductCode = Read-ProductCodeFromInstallShield -Installer $Info
$UpgradeCode = Read-UpgradeCodeFromInstallShield -Installer $Info
```

Use `Expand-InstallShieldInstaller` when file-level inspection is needed:

```powershell
$OutputDirectory = Join-Path $env:TEMP 'InstallShieldExtract'
Expand-InstallShieldInstaller -Path $InstallerFile -DestinationPath $OutputDirectory
```

`Get-InstallShieldInfo` returns `Variant`, `HasMsi`, `HasInstallScript`, extracted MSI paths, InstallScript `.inx`/`.ins` paths, CAB/HDR paths, and extracted `*_sfx.exe` launchers. Use `Get-InstallShieldMsiInfo` for MSI payloads.

For direct MSI databases, `Get-MsiInstallerInfo` can also classify InstallShield authoring markers. InstallShield-authored MSIs commonly use `INSTALLDIR="<INSTALLPATH>"`, but confirm with `$Info.InstallerBuilder -eq 'InstallShield'` because WiX and other builders can use the same public property.

### Step 2: Identify The Visible ARP Owner

For Basic MSI or InstallScript MSI, use the extracted MSI values for installer-level `ProductCode` and `AppsAndFeaturesEntries.UpgradeCode`. Set `AppsAndFeaturesEntries.InstallerType` to `msi` or `wix` only when the visible ARP entry comes from that MSI/WiX payload.

If the MSI hides its native ARP entry and writes a custom one, use `$Info.AppsAndFeaturesInstallerType` and `$Info.AppsAndFeaturesProductCode` from MSI parsing. Validate in a VM when the wrapper controls visibility.

### Step 3: Validate Silent Support And Nested Behavior

If no MSI can be extracted and the installer is InstallScript-only, do not submit it unless a WinGet-compatible silent path exists without response-file replay. If silent behavior or ARP visibility is ambiguous, use VM validation.

## VM Validation

Follow [VM-Only Dynamic Validation Workflow](vm-validation-workflow.md) to distinguish Basic MSI, InstallScript MSI, and InstallScript-only behavior, verify nested ARP ownership, and stop when silent installation requires a response file.

## Implementation Sources

- [ISx](https://github.com/lifenjoiner/ISx)
