# InstallForge workflow

## When to use

Use this workflow when structural analysis identifies an InstallForge setup. Current InstallForge builders are published through the [InstallForge release repository](https://github.com/soner-boztas/installforge/releases); older builders are available only from archived InstallForge download endpoints.

## Detection

Do not classify a file from `InstallForge`, `InstallForge Setup`, or `installforge.net` strings alone. `Test-InstallForge` requires a valid PE and structured compiled configuration: a legacy configuration CAB or a named `SETUPCONFIGURATION` resource archive. Payload routing then validates legacy ZIP, InstallForge 1.4.x GZip/TAR, or InstallForge 1.5+ 7z media.

`Get-InstallForgeInfo` parses the selected route once and returns metadata, ARP evidence, operation tables, associations, requirements, and the payload catalog. InstallForge 1.4 introduced the current native setup engine and its resource/7z layout. InstallForge 1.5 changed builder project files to XML and added a CLI builder, but did not create a new setup container generation.

## Binary structure

Read [InstallForge internals](../../internals/installforge/overview.md) before changing route detection, record decoding, extraction, or parser limits.

```text
InstallForge 1.2.x-1.3.x
PE image
`-- overlay
    +-- optional prefix
    +-- MSCF cabinet -> SC.dat and operation tables
    `-- ZIP payload

InstallForge 1.4.x
PE image
+-- RCDATA/SETUPCONFIGURATION -> 7z -> SC.dat and operation tables
`-- overlay -> JGTFUVQ`TUBSU + observed header -> GZip -> TAR payload

InstallForge 1.5+
PE image
+-- RCDATA/SETUPCONFIGURATION -> 7z -> SC.dat and operation tables
`-- overlay -> JGTFUVQ`TUBSU + observed header -> 7z payload with Base64 UTF-16LE path segments
```

## Manifest shape

The standard InstallForge runtime is interactive-only. Its builder CLI builds setup files; its `-i`, `-o`, `--quiet`, and related options are not generated-setup switches.

```yaml
Installers:
- Architecture: x86
  InstallerType: exe # InstallForge
  InstallerUrl: https://example.com/Product-1.2.3.exe
  InstallerSha256: <SHA256>
  InstallModes:
  - interactive
```

WinGet has no InstallForge defaults for generic `InstallerType: exe`. Do not add `/S`, `/silent`, or builder CLI options. Controlled InstallForge 1.6.1 media remained interactive with `/S` and `/silent` and wrote no installed state while the wizard was left open.

## Static parsing

### 1. Parse once and confirm the route

```powershell
. .\Modules\PackageModule\Index.ps1
$Info = Get-InstallForgeInfo -Path $InstallerPath
$Info | Select-Object FormatGeneration, ContainerRoute, DisplayName, DisplayVersion, Publisher, ProductCode, Scope, DefaultInstallLocation, RegistryView, Architecture, Diagnostics
```

Require `ContainerRoute` to be `CabinetZip` or `Resource7z`. A marker-only result is not sufficient.

### 2. Review Apps & Features evidence

```powershell
$Info.AppsAndFeaturesEntries
$Info.AppsAndFeaturesEvidence
$Info.RegistryWrites | Where-Object Key -Match '\\Uninstall\\'
```

For verified modern media, the built-in uninstaller writes an HKLM entry whose key name and ProductCode equal `Appname`. `AppsAndFeaturesEntries` contains only WinGet schema fields; `AppsAndFeaturesEvidence` retains uninstall commands, icon, install location, registry view, and other raw values. Legacy 1.2.2 media packages an uninstaller but writes no ARP row. Verified 1.2.6.2 and 1.3.2 runtimes use `Appname` as ProductCode in HKLM's 32-bit view; inspect `LegacyArpRuntimeSupport` because dispatch follows runtime code evidence rather than a version-string assumption.

### 3. Review compiled system effects

```powershell
$Info.RegistryWrites
$Info.RegistryAssociationInfo
$Info.Protocols
$Info.FileExtensions
$Info.Shortcuts
$Info.Variables
$Info.Commands
$Info.Requirements
$Info.GeneratedUninstallerEntry
```

The parser resolves predefined constants and literal custom-variable defaults. It excludes registry values that still contain runtime-only or unknown expressions from ARP and association projection. Command records expose `WaitForExit`, `Hidden`, and unknown option tokens. Shortcut records expose their compiled per-user or all-users scope. InstallForge 1.4+ stores the generated uninstaller as a normal payload entry identified by `GeneratedUninstallerEntry`; legacy 1.2.x-1.3.x runtimes generate the uninstaller during installation instead.

### 4. Extract files only when needed

```powershell
$Files = Expand-InstallForgeInstaller -Path $InstallerPath -DestinationPath $DestinationPath -CollisionAction Rename
$Files | Select-Object FullName, Length
```

Omitting `-Name` extracts every installed payload file. Use `-Name` for a decoded path or wildcard when only one executable or sidecar is needed. GZip/TAR media from 1.4.x and 7z media from 1.5+ expose the same decoded installed paths. Analyze nested executables separately and do not execute extracted content on the host.

### 5. Apply the installability decision

Treat `InstallForge.Installability.InteractiveOnly` as blocking during manifest authoring unless the publisher supplies a separate wrapper or artifact with independently verified unattended behavior. Do not infer support from a task script, filename, or builder command line.

## Apps & Features

InstallForge 1.6.1 controlled media wrote `DisplayName`, `DisplayVersion`, `Publisher`, `UninstallString`, `DisplayIcon`, `InstallLocation`, `HelpLink`, `EstimatedSize`, `NoModify`, and `NoRepair` below the machine uninstall key. `UninstallString` and the default `DisplayIcon` use the configured uninstaller name exactly; when the project name omits `.exe`, the ARP strings omit it even though the installed file has that extension.

The `Uninstaller_VW` compiled field selects the 32-bit or 64-bit built-in uninstall registry view. A configured custom registry table may add separate uninstall entries. The observed table writes strings only, so a custom `SystemComponent="1"` remains visible; controlled `winget list` validation confirms this behavior. Custom HKLM rows from the x86 runtime use the 32-bit view, while HKCU rows are view-shared. Inspect `AppsAndFeaturesEvidence` when more than one row is present.

## Scope and architecture

Do not infer scope from `InstallDir`. The verified native runtime writes its built-in uninstall row to HKLM and requests elevation even when the installation directory uses `<LocalAppData>`. The parser therefore uses compiled ARP and PE elevation evidence before destination paths.

`Architecture` uses the configured main payload executable when it resolves uniquely. Otherwise the parser analyzes the complete bounded payload EXE set, excluding the generated uninstaller. A single common architecture remains authoritative; mixed architectures are returned in `PayloadArchitectures` while scalar `Architecture` stays empty. The outer setup PE is used only when there is no payload executable evidence. Review `PayloadAnalysisRoute`, `PayloadArchitectureComplete`, `PayloadArchitectureInfo`, `PayloadDependencyInfo`, `PayloadCandidateEvidence`, and `PayloadInspectedFiles` before authoring architecture or dependencies.

## Known examples

The official InstallForge 1.5.0, 1.6.0, and 1.6.1 release installers use the modern resource/7z route. Archived 1.4.2 and 1.4.4 builder installers use the resource-configuration plus GZip/TAR transition route. Archived InstallForge 1.2.2, 1.2.6.2, 1.2.7, 1.2.9.2, and 1.3.2 builder installers use the legacy CAB/ZIP route.

## Validation notes

Use the [VM validation workflow](../../workflows/vm-validation.md) when runtime variable values, failure codes, or a claimed nonstandard silent wrapper matters. Capture exit codes and installed state separately. Controlled 1.3.2 and 1.6.1 runs returned `0` after cancellation from the welcome page, so process status alone cannot distinguish cancellation from success. Controlled installations also confirmed the 1.2.2 no-ARP route, the 1.2.6.2 and 1.3.2 legacy ARP route, modern built-in and custom ARP behavior, shortcut scope, and successful exit code `0`.

## Source references

- [InstallForge release repository](https://github.com/soner-boztas/installforge/releases)
- [InstallForge documentation](https://installforge.net/docs/)
- [InstallForge release notes](https://installforge.net/docs/release-notes/)
- [InstallForge CLI builder](https://installforge.net/docs/using-installforge/command-line-interface/)
- [InstallForge predefined constants](https://installforge.net/docs/getting-started/predefined-constants/)
- [InstallForge custom variables](https://installforge.net/docs/how-tos/using-custom-variables/)
- [Archived ForgeSoft InstallForge setup captures](https://web.archive.org/web/*/http://download.forgesoft.net:80/?i=IFSetup)
- [Archived InstallForge setup captures](https://web.archive.org/web/*/https://installforge.net/downloads/?i=IFSetup)
