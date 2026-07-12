# Installer Analysis Workflow

Use this workflow to identify an installer family, select one focused family page, and decide whether static evidence is sufficient. Never execute an unknown installer on the host.

## 1. Resolve Existing Package Evidence

Use `winget search` before searching the winget-pkgs checkout:

```powershell
winget search --id Publisher.Package --exact
```

After resolving an identifier, navigate directly to its manifest path and the corresponding Dumplings task. Existing evidence is reusable only when the publisher, artifact family, and current installer layout match.

## 2. Run Static Analysis

Load PackageModule and analyze by file content rather than extension:

```powershell
. .\Modules\PackageModule\Index.ps1
$Analysis = Get-WinGetInstallerAnalysis -Path C:\Path\To\Installer.exe
$Analysis.DetectedFileType
$Analysis.ParserResults | Where-Object Success
$Analysis.FamilyCandidates
```

Use high-confidence structured parser results first. Treat marker candidates as routing evidence, not proof of scope, silent switches, visible ARP type, or installed architecture.

Optional diagnostics must not become CI dependencies:

```powershell
diec.exe -j C:\Path\To\Installer.exe
exeinfope.exe 'C:\Path\To\Installer.exe*' /s /log:C:\Path\To\exeinfo.log
```

`diec` prints help in a GUI when invoked incorrectly. Exeinfo PE writes its useful console-mode result to the requested log and may briefly show an empty countdown window. Do not use either tool to extract or execute an installer.

## 3. Route To One Focused Workflow

This is the only installer-family route table in the skill.

| Analyzer family or decisive evidence | Focused workflow |
| --- | --- |
| MSI, WiX, MSP, MST, Windows Installer CFB | [MSI and WiX](installer-type-msi-wix.md) |
| MSIX, AppX, bundle, `.appinstaller` indirection | [MSIX and AppX](installer-type-msix-appx.md) |
| ZIP, archive, portable binary, font | [Archive, portable, and font](installer-type-archive-portable-font.md) |
| NSIS, Nullsoft, electron-builder NSIS | [NSIS](installer-type-nsis.md) |
| Inno Setup | [Inno](installer-type-inno.md) |
| Burn, WiX bundle, `.wixburn` | [Burn](installer-type-burn.md) |
| Advanced Installer EXE | [Advanced Installer](installer-type-advanced-installer.md) |
| InstallShield EXE or Advanced UI | [InstallShield](installer-type-installshield.md) |
| Squirrel or Velopack | [Squirrel and Velopack](installer-type-squirrel.md) |
| Chromium Setup, Chromium Updater, Google Updater, Omaha | [Chromium Setup](installer-type-chromium-setup.md) |
| Wise wrapper | [Wise](installer-type-wise.md) |
| IExpress | [IExpress](installer-type-iexpress.md) |
| Qt Installer Framework | [Qt Installer Framework](installer-type-qt-installer-framework.md) |
| install4j | [install4j](installer-type-install4j.md) |
| Setup Factory | [Setup Factory](installer-type-setup-factory.md) |
| dotNetInstaller | [dotNetInstaller](installer-type-dotnetinstaller.md) |
| InstallAnywhere | [InstallAnywhere](installer-type-installanywhere.md) |
| InstallAware | [InstallAware](installer-type-installaware.md) |
| Actual Installer | [Actual Installer](installer-type-actual-installer.md) |
| DeployMaster | [DeployMaster](installer-type-deploymaster.md) |
| InstallMate | [InstallMate](installer-type-installmate.md) |
| QSetup | [QSetup](installer-type-qsetup.md) |
| Paquet Builder | [Paquet Builder](installer-type-paquet-builder.md) |
| InstallBuilder | [InstallBuilder](installer-type-installbuilder.md) |
| CreateInstall | [CreateInstall](installer-type-createinstall.md) |
| InstallForge | [InstallForge](installer-type-installforge.md) |
| 7z SFX | [7z SFX](installer-type-7z-sfx.md) |
| WinRAR GUI SFX | [WinRAR GUI SFX](installer-type-winrar-sfx.md) |
| Unknown or unsupported PE installer | [Generic EXE fallback](installer-type-generic-exe.md) |

Important magic and structured evidence:

- MSI uses CFB magic `D0 CF 11 E0 A1 B1 1A E1` and root CLSID `{000C1084-0000-0000-C000-000000000046}`; MSP uses `{000C1086-0000-0000-C000-000000000046}` and MST uses `{000C1082-0000-0000-C000-000000000046}`.
- NSIS uses a validated aligned `DEADBEEF` plus `NullsoftInst` first header; Inno uses resource `#11111`; Burn exposes `.wixburn`.
- MSIX/AppX is a ZIP/OPC package with AppX manifest/signature structures. A ZIP containing an EXE is not automatically MSIX.
- Wrapper markers must be followed to the configured nested command before selecting switches or Apps & Features metadata.

## 4. Resolve Wrappers And Visible ARP Ownership

For every SFX, bootstrapper, nested MSI, or download-and-execute installer:

1. Parse the outer configuration and identify the exact file or command invoked.
2. Extract only through bounded static parser functions.
3. Analyze the nested payload as an independent installer.
4. Compose outer forwarding syntax with nested silent and no-reboot arguments.
5. Model the visible ARP owner. `WindowsInstaller=1` means WinGet treats the entry as MSI; `SystemComponent=1` hides it.
6. Use `AppsAndFeaturesEntries` only for a meaningful mismatch from the manifest/default-locale identity.

Do not infer nested behavior from the outer stub architecture, extension, or family defaults.

## 5. Escalate Unresolved Facts

Read [Installed-State And Association Workflow](installed-state-workflow.md) for ARP matching and association evidence. Read [VM-Only Dynamic Validation Workflow](vm-validation-workflow.md) only when static parsing cannot prove visible ARP ownership, scope, architecture, silent behavior, exit codes, elevation, network payload selection, or first-run associations.

For manifest field placement, defaults, and sorting, use the authoring skill's `manifest-workflow.md`; do not duplicate those rules in installer-family pages.
