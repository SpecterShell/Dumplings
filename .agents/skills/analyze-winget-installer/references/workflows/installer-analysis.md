# Installer analysis workflow

Use this workflow to identify an installer family, select one focused family page, and decide whether static evidence is sufficient. Never execute an unknown installer on the host.

## 1. Resolve existing package evidence

Use `winget search` before searching the winget-pkgs checkout:

```powershell
winget search --id Publisher.Package --exact
```

After resolving an identifier, navigate directly to its manifest path and the corresponding Dumplings task. Existing evidence is reusable only when the publisher, artifact family, and current installer layout match.

## 2. Run static analysis

Load PackageModule and analyze by file content rather than extension:

```powershell
. .\Modules\PackageModule\Index.ps1
$Analysis = Get-WinGetInstallerAnalysis -Path C:\Path\To\Installer.exe
$Analysis.DetectedFileType
$Analysis.ParserResults | Where-Object Success
$Analysis.DetectedFamilies
$Analysis.RoutingHints
$Analysis.RejectedCandidates
```

Use `DetectedFamilies` for confirmed outer-family evidence. `RoutingHints` contains bounded text or incomplete structural clues used only to choose parsers; `RejectedCandidates` records hints whose parser rejected the surrounding layout. Neither collection proves an installer family, scope, silent switches, visible ARP type, or installed architecture. `FamilyCandidates` is retained as a compatibility projection of `DetectedFamilies` and no longer contains unvalidated hints.

Optional agent diagnostics must not become parser or CI dependencies:

```powershell
diec.exe -j C:\Path\To\Installer.exe
exeinfope.exe 'C:\Path\To\Installer.exe*' /s /log:C:\Path\To\exeinfo.log
```

`diec` prints help in a GUI when invoked incorrectly. Exeinfo PE writes its useful console-mode result to the requested log and may briefly show an empty countdown window. Agents may also use 7-Zip, NanaZip, or another static extractor to cross-check archive boundaries and nested files. Keep all such invocations outside Dumplings parser modules, bridges, analyzers, tests, and CI paths. Treat their output as supporting evidence and confirm it against source-backed structures or stable fixtures. Never execute the installer or an extracted payload on the host.

## 3. Route to one focused workflow

This is the only installer-family route table in the skill.

| Analyzer family or decisive evidence | Focused workflow |
| --- | --- |
| MSI, WiX, MSP, MST, Windows Installer CFB | [MSI and WiX](../families/msi-wix/workflow.md) |
| MSIX, AppX, bundle, `.appinstaller` indirection | [MSIX and AppX](../families/msix-appx/workflow.md) |
| ZIP or another archive with nested installers | [Archive](../families/archive/workflow.md) |
| Loose or archive-contained portable binary | [Portable](../families/portable/workflow.md) |
| Font file | [Font](../families/font/workflow.md) |
| NSIS, Nullsoft, electron-builder NSIS | [NSIS](../families/nsis/workflow.md) |
| Inno Setup | [Inno](../families/inno/workflow.md) |
| Burn, WiX bundle, `.wixburn` | [Burn](../families/burn/workflow.md) |
| Advanced Installer EXE | [Advanced Installer](../families/advanced-installer/workflow.md) |
| InstallShield EXE or Advanced UI | [InstallShield](../families/installshield/workflow.md) |
| Squirrel or Velopack | [Squirrel and Velopack](../families/squirrel/workflow.md) |
| Zero Install bootstrapper | [Zero Install](../families/zero-install/workflow.md) |
| Chromium Setup, Chromium Updater, Google Updater, Omaha | [Chromium Setup](../families/chromium-setup/workflow.md) |
| Wise wrapper | [Wise](../families/wise/workflow.md) |
| IExpress | [IExpress](../families/iexpress/workflow.md) |
| Qt Installer Framework | [Qt Installer Framework](../families/qt-installer-framework/workflow.md) |
| install4j | [install4j](../families/install4j/workflow.md) |
| Setup Factory | [Setup Factory](../families/setup-factory/workflow.md) |
| dotNetInstaller | [dotNetInstaller](../families/dotnetinstaller/workflow.md) |
| InstallAnywhere | [InstallAnywhere](../families/installanywhere/workflow.md) |
| InstallAware | [InstallAware](../families/installaware/workflow.md) |
| Actual Installer | [Actual Installer](../families/actual-installer/workflow.md) |
| DeployMaster | [DeployMaster](../families/deploymaster/workflow.md) |
| InstallMate | [InstallMate](../families/installmate/workflow.md) |
| QSetup | [QSetup](../families/qsetup/workflow.md) |
| Paquet Builder | [Paquet Builder](../families/paquet-builder/workflow.md) |
| InstallBuilder | [InstallBuilder](../families/installbuilder/workflow.md) |
| CreateInstall | [CreateInstall](../families/createinstall/workflow.md) |
| InstallForge | [InstallForge](../families/installforge/workflow.md) |
| 7z SFX | [7z SFX](../families/7z-sfx/workflow.md) |
| WinRAR GUI SFX | [WinRAR GUI SFX](../families/winrar-sfx/workflow.md) |
| Unknown or unsupported PE installer | [Generic EXE fallback](../families/generic-exe/workflow.md) |

Important magic and structured evidence:

- MSI uses CFB magic `D0 CF 11 E0 A1 B1 1A E1` and root CLSID `{000C1084-0000-0000-C000-000000000046}`; MSP uses `{000C1086-0000-0000-C000-000000000046}` and MST uses `{000C1082-0000-0000-C000-000000000046}`.
- NSIS uses a validated aligned `DEADBEEF` plus `NullsoftInst` first header; Inno uses resource `#11111`; Burn exposes `.wixburn`.
- MSIX/AppX is a ZIP/OPC package with AppX manifest/signature structures. A ZIP containing an EXE is not automatically MSIX.
- Wrapper markers must be followed to the configured nested command before selecting switches or Apps & Features metadata.

## 4. Resolve wrappers and visible ARP ownership

Follow [Wrapper installers](wrapper-installers.md) for SFX, bootstrapper, nested MSI, and download-and-execute layouts. Do not infer nested behavior from the outer stub architecture, extension, or family defaults.

## 5. Escalate unresolved facts

Read [Installed state](installed-state.md) for ARP matching and association evidence. Read [VM validation](vm-validation.md) only when static parsing cannot prove visible ARP ownership, scope, architecture, silent behavior, exit codes, elevation, network payload selection, or first-run associations.

Write full parser and VM output to [transient evidence](evidence.md). For manifest field placement, defaults, and sorting, use the manifest-authoring skill rather than duplicating those rules in installer-family pages.
