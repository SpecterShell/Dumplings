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

## Binary Structure

InstallShield has several incompatible generations. Dumplings first separates the PE launcher from its overlay, then decodes only the supported stream/catalog variants. A nested MSI is selected from decoded metadata rather than from a recursive `*.msi` wildcard.

```text
PE setup launcher
`-- overlay
    +-- optional "NB10" debug prefix
    +-- encoded stream form
    |   +-- "InstallShield" or "ISSetupStream" header (46 bytes)
    |   +-- repeated old (0x138-byte) or stream attributes
    |   `-- transformed/zlib payload ranges
    `-- plain form
        +-- ANSI or UTF-16 record headers
        `-- adjacent bounded file ranges
```

```text
Decoded stream header (record-relative)
Offset  Size      Field
------  --------  ---------------------------------------------
0x00    14        NUL-padded ASCII "InstallShield"/"ISSetupStream"
0x0E    2         FileCount, uint16 LE
0x10    4         AttributeType, uint32 LE (supported: 0..4)
0x14    26        Reserved/observed header bytes

Legacy attribute (0x138 bytes)
0x00    260       NUL-terminated file name bytes
0x104   4         EncodedFlags, uint32 LE
0x10C   4         FileLength, uint32 LE
0x118   2         Unicode-launcher evidence, uint16 LE
0x138   FileLen   adjacent encoded file payload

ISSetupStream attribute
0x00    4         FileNameLength, uint32 LE
0x04    4         EncodedFlags, uint32 LE
0x0A    4         FileLength, uint32 LE
0x16    2         Unicode-launcher evidence, uint16 LE
0x18    24        optional extra record when AttributeType == 4
...     N         UTF-16LE file name
...     FileLen   adjacent encoded file payload
```

The payload transform is applied only to the declared file range; a valid decoded zlib prefix is checked before decompression. Header count, name length, file length, next-record position, safe output path, and decoded output are bounded. Basic MSI, InstallScript MSI, InstallScript-only, and Advanced UI classification depends on the decoded catalog and nested payload evidence, not on a shared marker alone.

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

Use `Modules\PackageModule\Libraries\InstallShield.psm1` to extract and classify InstallShield payloads without running the installer or shelling out to `ISx.exe`. The module contains an in-process parser based on the ISx container format; see the [ISx source repository](https://github.com/lifenjoiner/ISx). ISx is format attribution only: Dumplings neither distributes nor requires the ISx executable.

```powershell
Import-Module .\Modules\PackageModule\Libraries\InstallShield.psm1 -Force

$Info = Get-InstallShieldInfo -Path $InstallerFile
$MsiInfo = Get-InstallShieldMsiInfo -Installer $Info
$Info.MsiPayloadSelection
$MsiInfo.SelectedMsiPath

$ProductVersion = Read-ProductVersionFromInstallShield -Installer $Info
$ProductCode = Read-ProductCodeFromInstallShield -Installer $Info
$UpgradeCode = Read-UpgradeCodeFromInstallShield -Installer $Info
```

Use `Expand-InstallShieldInstaller` when file-level inspection is needed:

```powershell
$OutputDirectory = Join-Path $env:TEMP 'InstallShieldExtract'
Expand-InstallShieldInstaller -Path $InstallerFile -DestinationPath $OutputDirectory
```

`Get-InstallShieldInfo` returns `Variant`, `HasMsi`, `HasInstallScript`, extracted MSI paths, InstallScript `.inx`/`.ins` paths, CAB/HDR paths, and extracted `*_sfx.exe` launchers. For Basic MSI and InstallScript MSI wrappers, it parses the extracted `Setup.ini`, reads `[Startup] PackageName` and the matching package section's `Location`, and exposes the exact path as `MsiPayloadSelection.SelectedMsiPath`. `Get-InstallShieldMsiInfo` reads that selected MSI instead of taking the first `*.msi` match.

Do not pass `-Name` during normal analysis. Use it only as a reviewed manual constraint when `MsiPayloadSelection.SelectionMethod` is unresolved and static inspection proves which payload the bootstrapper launches. If multiple MSIs are extracted and `Setup.ini` does not select one, the parser stops rather than using MSI architecture or enumeration order as a selector. An unselected MSI may be a prerequisite or chained package.

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
- [Revenera SetupIni.exe and embedded Setup.ini](https://docs.revenera.com/installshield26helplib/helplibrary/SetupIniExe.htm)
