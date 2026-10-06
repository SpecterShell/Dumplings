# NSIS scope and silent behavior

[Back to the NSIS workflow](workflow.md)

## Architecture

For electron-builder, reuse `$ElectronBuilderInfo`. The helper detects embedded app packages such as `app-32.7z`, `app-64.7z`, and `app-arm64.7z`. It reports every embedded architecture in `Architectures`. Its singular `Architecture` property applies the WinGet-compatible heuristic that x86 wins for a universal installer containing an x86 payload.

Pass the installer entry's architecture to `Get-NSISInfo -Architecture` or `Get-ElectronBuilderNSISInfo -Architecture`. Both return `NSIS.ElectronBuilder.ArchitectureMismatch` when compiled app-package evidence excludes that architecture. Manifest updates log it as a warning without changing the entry. `Get-NSISInfo` also returns `IsElectronBuilder`, `SupportedArchitectures`, and `ElectronBuilderEvidence`, so this check needs no second parser call. The comparison uses packaged application architectures, not the NSIS stub or Windows emulation support. No mismatch is reported when architecture is unspecified or package evidence is unavailable.

For ordinary NSIS, the PE stub architecture is not sufficient when it extracts a differently-architected application. Determine the manifest architecture from extracted payload names, nested installer metadata, and installed executable architecture. If static payload evidence is missing or contradictory, use the canonical [VM validation workflow](../../workflows/vm-validation.md). Exclude unsupported architectures rather than declaring an installer neutral.

When one installer URL serves more than one WinGet architecture, obtain one targeted result per effective installer entry and reuse it for that entry. `CometNetwork.BitComet`, for example, uses the source-backed `System::Call kernel32::IsWow64Process` branch to write `BitComet` on x86 Windows and `BitComet_x64` on x64 Windows. Do not copy one architecture's `ProductCode` across duplicate entries merely because their URL and hash are identical.

Known electron-builder evidence examples:

- `Aircall.AircallWorkspace`: x64 user-scope installer with embedded `app-64.7z`.
- `Obsidian.Obsidian`: universal installer with `app-32.7z`, `app-64.7z`, and `app-arm64.7z`; supports both `/currentuser` and `/allusers`.
- `GameSir.GameSirT4kApp`: x86 user-scope installer with embedded `app-32.7z`.
- `GameSir.GameSirConnect`: x86 dual-scope installer with embedded `app-32.7z`; supports both `/currentuser` and `/allusers`.
- `GDevelop.GDevelop`: x64 dual-scope installer with embedded `app-64.7z`.
- `GauzyTech.NeatReader`: x86 machine-scope installer with embedded `app-32.7z`; full initialization simulation reports `SupportedScopes: machine`.
- `JGraph.Draw`: x64 machine-scope manifest entry with embedded `app-64.7z`.

Continue to [silent behavior and scope](#silent-behavior-and-scope) for both electron-builder and ordinary NSIS.

## Silent behavior and scope

Run the separate switch and control-flow analysis once:

```powershell
$SwitchInfo = Get-NSISInstallerSwitchInfo -Path $InstallerFile
$SwitchInfo.AdditionalSwitches
$SwitchInfo.RejectedSwitchCandidates
```

This analysis looks for standalone switches and NSIS parsing evidence such as `TestParameter`, `GetParameters`, `GetOptions`, `IfSilent`, and related macros. It deliberately rejects switches belonging to nested commands, such as `taskkill /IM` inside `CCF.CCFLink`. Review `RejectedSwitchCandidates` rather than copying them into the manifest.

First determine silent behavior and compare it with the WinGet defaults:

- If `interactive`, `silent`, and `silentWithProgress` are all supported through the standard `/S` behavior, omit `InstallModes`, `Silent`, and `SilentWithProgress`.
- If an install mode is unsupported, write the complete supported `InstallModes` array explicitly.
- If a silent mode requires a command different from `/S`, write the complete replacement in `Silent` or `SilentWithProgress`. Do not append tokens while assuming WinGet retains `/S`.
- Add a proven non-default argument to `InstallerSwitches.Custom` when it augments every selected install mode.
- Remove `InstallLocation` when it is exactly `/D=<INSTALLPATH>`; explicitly override it when the installer uses a different location syntax or does not support the default.
- Inspect `IfSilent`, `SetSilent`, abort/quit paths, dialogs, license gates, and required parameters. Finding a switch string alone does not prove that silent installation succeeds.

Known non-default or rejected-silent examples:

- `AlphaTheta.rekordbox`: requires `/Lang=` as an additional silent argument.
- `Huawei.HuaweiBrowser`: requires `--SILENT=true` for silent installation.
- Fraps switches back to normal installation with `SetSilent` when silent mode is detected.
- Huorong Antivirus exits when `IfSilent` detects silent mode.
- `Insecure.Nmap` restricts silent installation in newer non-OEM builds; winget-pkgs no longer accepts normal silent updates for this case.
- [Livo](https://github.com/kaieye/Livo) does not implement silent installation.
- [小赛看看 DICOM Viewer](https://xiaosaiviewer.com/) blocks silent installation with an unskippable dialog.

Then determine scope:

- electron-builder: use `$ElectronBuilderInfo.SupportedScopes`, but verify the associated `/currentuser` and `/allusers` control-flow evidence before writing duplicate entries.
- ordinary NSIS: use explicit `/CurrentUser` and `/AllUsers` variants, compiled MultiUser scope setters, `SetShellVarContext`, and conditional HKCU/HKLM uninstall writes as evidence. Confirm `HasScopeRuntimeCheck`, inspect `SupportedScopes`, then call `Get-NSISInfo -Scope user` and `Get-NSISInfo -Scope machine` to obtain each branch's ARP identity. An untargeted `$Info.Scope` reports only the simulated/default scope and cannot prove dual-scope support by itself.
- user only or machine only: keep one installer entry and write `Scope` only when the evidence supports it.
- both scopes with usable switches: select the dual-scope manifest shape. Preserve the exact switch casing accepted by that installer.
- scope selected only by current privilege, UAC acceptance, or a response file: do not create normal dual-scope entries. `JetBrains.*` and `Mozilla.*` are known rare examples of this behavior.
- unresolved scope: use the canonical [VM validation workflow](../../workflows/vm-validation.md) and test non-elevated and elevated paths separately.

Known ordinary dual-scope examples include `BleachBit.BleachBit`, `KiCad.KiCad`, and most `KDE.*` installers. KDE CDN links expire frequently, so do not use them as durable automated fixtures.

### Electron-builder elevation

An assisted electron-builder installer (`oneClick: false`, `perMachine: false`) can disable its all-users radio button when started unelevated. Setting `allowElevation: false` omits `MULTIUSER_INSTALLMODE_ALLOW_ELEVATION`; the scope page then disables the control and appends `(must run as admin)`. This behavior exists in both the 19.0.0 and 26.15.3 templates. It is a build configuration, so do not classify it as an old-NSIS or old-electron-builder feature.

Check the silent route separately. The inspected 19.0.0, 20.0.0, and 22.14.8 templates lack the assisted install section's silent machine-scope elevation block. Release 22.14.9 added it: initialization sets the machine flag for `/allusers`, and the install section calls `UAC_RunElevated` when that flag is set, installation is silent, and the process is not elevated. That block is independent of `MULTIUSER_INSTALLMODE_ALLOW_ELEVATION`, so even a newer installer with a disabled GUI option may self-elevate for `/S /allusers`. Custom scripts can change either route.

Use [VM validation](../../workflows/vm-validation.md) to test the exact machine command from an unelevated process on a fresh system, then from an elevated process if necessary. Also test the upgrade route when previous HKLM installation state changes scope selection. Set `ElevationRequirement: elevationRequired` on the machine entry when that route works only with manual pre-elevation. Use `elevatesSelf` when the installer requests UAC and completes after consent. Keep this decision off the user entry and shared root of a dual-scope manifest. A recovered HKLM uninstall entry, `UAC.dll`, `elevate.exe`, or disabled-control label alone does not prove which route succeeds.

`try2love.CodexMobileBridge` 1.3.0 is a recent example of the disabled-option configuration: its release source pins electron-builder 26.15.3 with `oneClick: false`, `perMachine: false`, and `allowElevation: false`. The recent winget-pkgs branch sets `elevationRequired` on its `/allusers` entry. Treat that as an existing manifest choice to verify against silent-install evidence, not proof that the newer template lacks self-elevation. Static parsing of the release installer confirms dual scope, `asInvoker`, and the disabled-option text; targeted machine metadata parsing assumes a successful elevated route and does not test acquiring that token.

## Source references

- [electron-builder 19.0.0 scope page](https://github.com/electron-userland/electron-builder/blob/v19.0.0/packages/electron-builder/templates/nsis/multiUserUi.nsh) and [installer lifecycle](https://github.com/electron-userland/electron-builder/blob/v19.0.0/packages/electron-builder/templates/nsis/installer.nsi)
- [electron-builder 20.0.0 assisted scope initialization](https://github.com/electron-userland/electron-builder/blob/v20.0.0/packages/electron-builder-lib/templates/nsis/assistedInstaller.nsh)
- [electron-builder 22.14.9 changelog](https://github.com/electron-userland/electron-builder/blob/v22.14.9/packages/app-builder-lib/CHANGELOG.md) and [silent machine-elevation fix](https://github.com/electron-userland/electron-builder/commit/661a6522520e9ea59549cb7e18986fcfb58e873a)
- [electron-builder 26.15.3 scope page](https://github.com/electron-userland/electron-builder/blob/512a57ec9bcda593d3e0970bd2b9a33a63beeb57/packages/app-builder-lib/templates/nsis/multiUserUi.nsh), [assisted initialization](https://github.com/electron-userland/electron-builder/blob/512a57ec9bcda593d3e0970bd2b9a33a63beeb57/packages/app-builder-lib/templates/nsis/assistedInstaller.nsh), and [install section](https://github.com/electron-userland/electron-builder/blob/512a57ec9bcda593d3e0970bd2b9a33a63beeb57/packages/app-builder-lib/templates/nsis/installer.nsi)
- [Codex Mobile Bridge 1.3.0 build configuration](https://github.com/try2love/codex-mobile-bridge/blob/v1.3.0/package.json)
