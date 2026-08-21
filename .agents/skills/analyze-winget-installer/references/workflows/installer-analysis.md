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
$Analysis.Diagnostics
$Analysis.HasBlockingDiagnostics
$Analysis.SuggestedManifestFields
$Analysis.SuggestedManifestVariants
$Analysis.SuggestedNextSteps
```

Use `DetectedFamilies` for confirmed outer-family evidence. `RoutingHints` contains bounded text or incomplete structural clues used only to choose parsers; `RejectedCandidates` records hints whose parser rejected the surrounding layout. Neither collection proves an installer family, scope, silent switches, visible ARP type, or installed architecture. `FamilyCandidates` is retained as a compatibility projection of `DetectedFamilies` and no longer contains unvalidated hints.

`SuggestedManifestFields` contains only nonempty installer-level keys accepted by the WinGet 1.12 schema. `SuggestedManifestVariants` contains complete alternative partial shapes for scope, architecture, or subtype decisions; each item has `Name`, `ManifestFields`, and supporting `Evidence`. Scope-selecting arguments are written to `InstallerSwitches.Custom` inside each variant rather than placed in a non-schema `ScopeSwitches` property. `SuggestedNextSteps` contains review guidance and never appears inside manifest fields. A generic family keeps `Family` as its human-readable identity and uses schema value `InstallerType: exe`.

Exact structural parser evidence takes priority over the family template. For example, Qt IFW CLI media can expose all three modes while GUI-only media remains interactive-only, and InstallShield output depends on whether the parser proves Basic MSI, InstallScript MSI, InstallScript-only, or Advanced UI. ZIP analysis suggests only `InstallerType: zip` until one nested file is selected. Treat routing-hint suggestions as advisory because the family has not been confirmed.

Raw family `Get-*Info` functions and provider-neutral `Get-InstallerAnalysis` return facts and context-neutral `Diagnostics`; they do not return WinGet suggestions or write to host streams. `Get-WinGetInstallerAnalysis` resolves diagnostics for `FullAnalysis`, so inspect `Level`, `Kind`, `Areas`, `AffectedFields`, and `IsBlocking` rather than matching message text. A manifest suggestion resolves the same evidence for `ManifestAuthoring`, where missing identity, architecture, unattended support, conflicting confirmed families, and invalid artifacts can become blocking. `Get-WinGetInstallerManifestSuggestion` applies authoritative parser evidence and explicit overrides to installer entries, while family defaults and alternatives remain under `Suggestions`. Manifest updates use `ManifestUpdate` and normally keep diagnostics unrelated to fields being refreshed at `Verbose`.

Optional agent diagnostics must not become parser or CI dependencies:

```powershell
diec.exe -j C:\Path\To\Installer.exe
exeinfope.exe 'C:\Path\To\Installer.exe*' /s /log:C:\Path\To\exeinfo.log
```

7-Zip parser mode is another optional static diagnostic. Quote `'-t#'` in PowerShell. The `#` type asks 7-Zip's parser to scan the file for embedded supported streams instead of forcing one ordinary archive handler; numbered names such as `2.msi` are observations of the current binary layout, not stable product identities. List the current installer before selecting a stream:

```powershell
7z.exe l -ba -slt '-t#' C:\Path\To\Installer.exe | Out-Host
```

The existing `DuoSecurity.Duo2FAAuthenticationforWindows` task extracts three architecture-specific MSI streams, while `Foxit.FoxitReader` extracts an MSI and optional MSP:

```powershell
7z.exe e -aoa -ba -bd -y '-t#' -o"${OutputDirectory}" $InstallerFile '2.msi' '3.msi' '4.msi' | Out-Host
7z.exe e -aoa -ba -bd -y '-t#' -o"${OutputDirectory}" $InstallerFile '2.msi' '3.msp' | Out-Host
```

The Altova tasks first use parser mode to locate a CAB and then open that CAB normally. `Oracle.JavaRuntimeEnvironment` uses parser mode twice because the outer installer exposes `2.wrapper_jre_offline.exe`, which then exposes `2.msi`:

```powershell
7z.exe e -aoa -ba -bd -y '-t#' -o"${OuterDirectory}" $InstallerFile '*.cab' | Out-Host
7z.exe e -aoa -ba -bd -y -o"${CabDirectory}" $CabPath '*.msi' | Out-Host
7z.exe e -aoa -ba -bd -y '-t#' -o"${OuterDirectory}" $InstallerFile '2.wrapper_jre_offline.exe' | Out-Host
7z.exe e -aoa -ba -bd -y '-t#' -o"${InnerDirectory}" $NestedExePath '2.msi' | Out-Host
```

Check `$LASTEXITCODE`, verify every expected output with `Test-Path`, inspect nested MSI architecture and identity, and use a separate temporary directory for each layer. Do not assume that stream `2` remains the same across versions. These commands are agent diagnostics only; Dumplings parsers, analyzers, tests, and CI must continue to use in-process source-backed implementations.

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
| Kachina native PE with appended TLV records | [Kachina](../families/kachina/workflow.md) |
| MicaSetup CLR/WPF installer | [MicaSetup](../families/micasetup/workflow.md) |
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

## 5. Resolve external dependencies

Review the selected outer installer and effective payload for hard prerequisites. `Get-PEDependencyInfo` covers VC runtime imports and framework-dependent .NET applications. For MSIX/AppX, `Get-MSIXInfo` projects supported manifest-declared VCLibs, Windows App Runtime, and Microsoft UI XAML framework identities and reports unknown package dependencies separately. Neither helper infers Visual Studio Tools for Office Runtime or Microsoft Office. For VSTO and Office add-ins, inspect MSI launch conditions, AppSearch or registry searches, VSTO deployment metadata, InstallShield `.prq` definitions, Burn or suite package chains, and publisher requirements. Distinguish an external prerequisite from one already installed by the selected wrapper.

Map a proven Visual Studio Tools for Office Runtime requirement to `Microsoft.VSTOR`. Map a proven requirement for the installed Microsoft Office desktop suite or a host such as Outlook, Word, Excel, or PowerPoint to `Microsoft.Office`. Map a proven requirement for the Windows .NET Framework 3.5 optional component to `Dependencies.WindowsFeatures: [NetFx3]`; do not use this feature for .NET Framework 4.x or modern .NET runtimes. Follow the manifest-authoring [dependency workflow](../../../author-winget-manifest/references/manifest/dependencies.md) for the complete mapping set, evidence thresholds, `MinimumVersion`, field placement, and optional-integration exclusions.

## 6. Complete dynamic validation

Read [Installed state](installed-state.md) for ARP matching, PATH, command, and association evidence. Complete [VM validation](vm-validation.md) for every distinct installer route before submission. Use static evidence to target the test, then prove blocker-free silent behavior, logging, exit codes, installed state, scope, elevation, network payload selection, and first-run behavior in the VM.

Write full parser and VM output to [transient evidence](evidence.md). When this analysis supports an authored package, project each conclusive result into the existing working manifest and save it before continuing; do not wait until every static and dynamic question is resolved. For manifest creation, field placement, defaults, incremental serialization, and sorting, use the manifest-authoring skill rather than duplicating those rules in installer-family pages.
