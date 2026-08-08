# NSIS scope and silent behavior

[Back to the NSIS workflow](workflow.md)

## Architecture

For electron-builder, reuse `$ElectronBuilderInfo`. The helper detects embedded app packages such as `app-32.7z`, `app-64.7z`, and `app-arm64.7z`. It reports every embedded architecture in `Architectures`; its singular `Architecture` property applies the WinGet-compatible heuristic that x86 wins for a universal installer containing an x86 payload.

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

This analysis looks for standalone switches and NSIS parsing evidence such as `TestParameter`, `GetParameters`, `GetOptions`, `IfSilent`, and related macros. It deliberately rejects switches belonging to nested commands, such as `taskkill /IM` inside `CCF.CCFLink`; review `RejectedSwitchCandidates` rather than copying them into the manifest.

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
