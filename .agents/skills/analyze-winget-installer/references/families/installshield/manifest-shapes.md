# InstallShield manifest shapes

[Back to the InstallShield workflow](workflow.md)

## Direct installer

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

The shown split `/V` arguments are one verified launcher form. Some Basic MSI wrappers instead require one compact forwarded string such as `/s /v"/qn /norestart"` or `/s /v"/passive /norestart"`. Treat these as alternatives to test, not interchangeable defaults. The nested install-location property is commonly `INSTALLDIR`; preserve quotes around `<INSTALLPATH>` with `/v"INSTALLDIR=""<INSTALLPATH>"""`, and use a less conventional quoting form only when VM evidence proves the wrapper rejects normal path quoting.

Keep `AppsAndFeaturesEntries.InstallerType: msi` only when the visible uninstall entry has `WindowsInstaller=1` while WinGet invokes the outer EXE. Omit the override when the wrapper creates a visible EXE-style ARP entry or when the manifest uses the direct MSI instead.

## InstallShield InstallScript package

Use this shape only when `Get-InstallShieldInfo` reports `HasMsi: false`, `HasInstallScript: true`, and `Variant: InstallScript`. The absence of an MSI means the InstallScript engine owns installation and ARP behavior; do not apply Basic MSI `/V...` forwarding switches or derive ProductCode/UpgradeCode from a nonexistent nested database.

Most InstallScript installers require recording and replaying a caller-supplied `setup.iss` response file for unattended installation. That additional package-specific input is not supported by winget-pkgs validation. A valid `setup.iss` already shipped beside `setup.inx` is different: InstallShield's default `/s` lookup can consume it without an additional manifest payload.

`Celsys.ClipStudioPaint` is self-contained rather than response-free: its installer embeds a valid `setup.iss` with the dialog order and responses, so `/s` needs no caller-supplied file.

```yaml
Installers:
- Architecture: x64
  InstallerType: exe # InstallShield InstallScript
  InstallerUrl: https://example.com/Product-1.2.3-x64.exe
  InstallerSha256: <SHA256>
  InstallModes:
  - interactive
  - silent
  InstallerSwitches:
    Silent: /s
  ProductCode: <VerifiedInstallScriptUninstallKey>
```

Known InstallShield InstallScript package:

- `Celsys.ClipStudioPaint`

The rejected `IndexEducation.PronoteClient` submission in [winget-pkgs#112792](https://github.com/microsoft/winget-pkgs/pull/112792) is a useful response-file-dependent example. Its x86 and x64 installers use different ProductGUID values and store a scrambled `setup.inx` inside `data1.hdr/data1.cab`; both require an external `setup.iss`.

## InstallShield Advanced UI package

Use this only for InstallShield Advanced UI packages that accept these switches:

```yaml
Installers:
- Architecture: x64
  InstallerType: exe # InstallShield Advanced UI
  Scope: machine
  InstallerUrl: https://example.com/Product-1.2.3-x64.exe
  InstallerSha256: <SHA256>
  InstallModes:
  - interactive
  - silent
  - silentWithProgress
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
- `Trimble.SketchUp.*`
- `Trimble.SketchUpViewer`.
