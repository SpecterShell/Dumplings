# Actual Installer workflow

## When to use

Use `InstallerType: exe` for a structurally confirmed Actual Installer package. A comment such as `InstallerType: exe # Actual Installer` records the family for reviewers without changing the WinGet enum.

## Detection

Run `Get-WinGetInstallerAnalysis` first. Confirm the family with `Test-ActualInstaller` or `Get-ActualInstallerInfo`; product strings and `aisetup.ini` text found by a broad binary scan are only routing hints.

Strong structural evidence is a valid PE followed by one of the supported container sequences: a metadata-first cabinet sequence with `setup.ini` or `aisetup.ini`, a metadata-last cabinet sequence with `aisetup.ini`, or independently valid ZIP ranges where one archive contains `aisetup.ini` and another contains numbered payload entries. The parser rejects marker-only files and malformed archive ranges.

## Binary structure

Actual Installer 3.x and 4.x place the metadata cabinet before one-file payload cabinets. Version 5.x reverses that order. Version 6.x and later use numbered ZIP payload entries and a final metadata ZIP. Setup EXE + Data media keeps the source-directory tree in a separately distributed 7z/LZMA file; real builder output can still embed generated uninstaller payloads before the metadata ZIP, while a metadata-only executable remains a supported structural route.

```text
3.x/4.x: PE -> metadata CAB -> payload CAB 0 -> payload CAB 1 -> ...
5.x:     PE -> payload CAB 0 -> payload CAB 1 -> ... -> metadata CAB
6.x+:    PE -> numbered payload ZIP(s) -> metadata ZIP
EXE+Data: PE -> metadata ZIP  +  companion 7z -> <InstallDir> tree
```

See [Actual Installer internals](../../internals/actual-installer/overview.md) for the CFHEADER, CFFILE, ZIP, INI table, and payload-index layouts.

## Static parsing

### 1. Parse once

Call `Get-ActualInstallerInfo` once and reuse the result. Do not follow it with individual `Read-*FromActualInstaller` calls.

```powershell
$Info = Get-ActualInstallerInfo -Path C:\Path\To\Installer.exe
$Info = Get-ActualInstallerInfo -Path C:\Path\To\Installer.exe -CompanionFile C:\Path\To\Payload.7z
$Info | Select-Object FormatGeneration, BuilderVersion, DisplayName, DisplayVersion, Publisher, ProductCode, Scope, SupportedScopes, DefaultInstallLocation, AppsAndFeaturesEntries, InstallerSwitches, InstallModes, Diagnostics
```

The result includes the parsed configuration, physical containers, installed-file catalog, registry operations and statically projectable writes, custom ARP groups, typed extensions and shortcuts, commands and bounded condition results, setup policy, requirements, external archive plans, bounded payload architecture/dependency evidence, generated-output evidence, and structured diagnostics. For Setup EXE + Data media, `-CompanionFile` adds the companion catalog to `InstalledPayloadCatalog` and lets the configured main executable contribute architecture and dependency evidence. A value such as `AppVersion=<V>` is a runtime expression and remains unresolved.

### 2. Inspect scope and elevation

Use the compiled `InstallLevel` value when present: `0` means current user only, `1` means all users only, `2` supports both with all users as the default, and `3` supports both with current user as the default. Do not assume every Actual Installer accepts both scope overrides. Older media without `InstallLevel` is classified from the compiled administrator setting and PE execution level.

For a dual-scope package, `/CU` selects current user and `/RUNAS /ALL` selects all users. Keep each scope-specific switch in `InstallerSwitches.Custom` on its corresponding installer entry.

### 3. Review Apps & Features evidence

The Product GUID is the uninstall-key identity only when uninstallation and the Programs and Features entry are both enabled. Cabinet4 instead uses literal `AppName` as the uninstall-key identity and `AppName AppVersion` as its visible display name, as verified against the 4.8 runtime. Cabinet3 can enable a visible entry without exposing a Product GUID, but its key identity remains unresolved.

The parser returns `DisplayName`, `DisplayVersion`, `Publisher`, install location, display icon, uninstall command, registry hive/view, and `AppsAndFeaturesEntries` from compiled configuration. `UninstallerCommandEvidence` distinguishes the literal ARP `UninstallString` from the valid quoted `/S` invocation; it does not claim that a `QuietUninstallString` value is registered when the runtime does not write one. A complete literal custom uninstall key can supply ARP evidence when built-in registration is disabled; multiple custom keys remain ambiguous. Compare these values with a VM registry delta for a new route or package.

### 4. Extract installed payloads

Omitting `-Name` extracts every directly stored installed file. The extractor maps `[Files]` indexes to numbered ZIP entries or one-file cabinets and strips `<InstallDir>` from output paths. Other destination roots are kept under `_destinations`. For Setup EXE + Data media, pass the compiled local 7z file through `-CompanionFile`; the source-directory tree is extracted below the destination without fetching anything from the network.

```powershell
Expand-ActualInstallerInstaller -Path C:\Path\To\Installer.exe -DestinationPath C:\Path\To\Output -CollisionAction Rename
Expand-ActualInstallerInstaller -Path C:\Path\To\Installer.exe -DestinationPath C:\Path\To\Raw -RawEntries -CollisionAction Rename
Expand-ActualInstallerInstaller -Path C:\Path\To\Installer.exe -CompanionFile C:\Path\To\Payload.7z -DestinationPath C:\Path\To\Output -CollisionAction Rename
Expand-ActualInstallerInstaller -Path C:\Path\To\Installer.exe -DestinationPath C:\Path\To\Metadata -MetadataEntries -Name '*Uninstall.exe' -CollisionAction Rename
```

`-MetadataEntries` exports language, image, and helper entries under `_actual\metadata`; these are not represented as installed files. `GeneratedOutputs` distinguishes duplicate logical rows, helper-backed generated uninstallers/updaters, and unresolved records. Cabinet5 and numbered-ZIP media can install a generated uninstaller as an exact helper copy, as verified by installed-file hashes for builder 5.2, 8.0, and 8.4; normal extraction includes that uninstaller. Generated updater helpers and older routes remain evidence-only until their final bytes are verified.

### 5. Compose switches and modes

Actual Installer is a generic EXE family, so WinGet provides no family defaults. `/S` is the silent switch and `/D "<INSTALLPATH>"` overrides the destination. Use `InstallModes: [interactive, silent]` only when `SetupParameterInfo.AllowsSilent` is true; compiled `-nosilent` policy and a User Information dialog without `-silentinstalluserinfo` remove the silent route. There is no separate source-backed `silentWithProgress` behavior.

The `/L` switch writes `%TEMP%\AISETUPLOG.TXT` to a fixed location. It neither accepts WinGet's `<LOGPATH>` token nor selects an installation mode, so do not add it as `Interactive`, `Silent`, `SilentWithProgress`, or `Log`.

Exit code `0` is success. `ExitCodeEvidence` contains the complete documented runtime table, including elevation handoff, cancellation, prerequisite, architecture, silent-policy, external-data, and initialization failures. Map nonzero results under `ExpectedReturnCodes` only when the package and tested builder generation exhibit the same behavior; do not add them to `InstallerSuccessCodes`.

## Manifest shape

For one machine-only artifact:

```yaml
InstallerType: exe # Actual Installer
Scope: machine
ElevationRequirement: elevatesSelf
InstallModes:
- interactive
- silent
InstallerSwitches:
  Silent: /S
  InstallLocation: /D "<INSTALLPATH>"
ProductCode: '{PRODUCT-GUID}'
```

For one compiled dual-scope artifact, use two installer entries with the same URL and hash. Add `Custom: /CU` to the user entry and `Custom: /RUNAS /ALL` to the machine entry. Do not create dual-scope entries when `SupportedScopes` contains only one scope.

## Apps & Features

Use `AppsAndFeaturesEntries` only when its parsed display identity differs from the default locale identity after WinGet normalization. Keep the installer-level ProductCode when the Product GUID is proven. The 5.2 builder installer was validated at `HKLM\Software\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall\{318020E9-4E14-DAB0-1CE4-2EE91C6FF5D0}` with `DisplayName=Actual Installer`, `DisplayVersion=5.2`, `Publisher=Softeza Development`, `%ProgramFiles(x86)%\Actual Installer`, and `Uninstall.exe`.

## Scope and architecture

`x64`/x64-compliance configuration controls the Program Files variant and registry view. `SystemType=0` means the 32-bit layout on both supported OS architectures, `SystemType=1` means 64-bit-only layout, and `SystemType=2` means 32-bit-only layout; unknown numeric enum values remain unresolved. Actual Installer through 9.8 can emit an x86 setup stub for the 64-bit-only route and disable WOW64 redirection at runtime, so the outer PE machine is not layout evidence. Analyze `PayloadArchitectures` and `PayloadDependencyInfo` when installed architecture is needed.

## VM validation

Follow [VM validation](../../workflows/vm-validation.md). Test the exact compiled scope route, `/S`, any `/D` override, exit code, visible ARP row, registry view, installed files, and first launch. Machine-only 8.0 media remained machine scope when invoked with `/CU`, which confirms that a documented switch is not proof that a particular artifact supports that alternative. The archived 3.8 builder setup did not progress past initialization on the Windows 11 validation VM, so do not treat its documented `/S` capability or static ARP intent as a successful modern-Windows validation.

## Known examples

- `Softeza.ActualInstaller`
- Actual Updater Free 5.0 is a separate product built with the same `Zip6Plus` route; the parser recovers `ProductCode={FCB1CDDE-F768-4D43-B1A1-BC019502DBC5}` from its own configuration rather than hardcoding the builder product.

## Source references

- [Actual Installer command-line parameters](https://www.actualinstaller.com/help/command-line.html)
- [Actual Installer variables](https://www.actualinstaller.com/help/installer-variables.html)
- [Actual Installer setup parameters](https://www.actualinstaller.com/help/setup-parameters.html)
- [Actual Installer commands](https://www.actualinstaller.com/help/commands.html)
- [Actual Installer 64-bit installations](https://www.actualinstaller.com/help/64-bit-installation.html)
- [Files and folders](https://www.actualinstaller.com/help/files-and-folders.html)
- [Registry](https://www.actualinstaller.com/help/registry.html)
- [Creating update installers and Product GUID behavior](https://www.actualinstaller.com/articles/how-to-create-update-installer.html)
- [Internet Archive captures of aisetup.exe](https://web.archive.org/web/*/http://www.actualinstaller.com/download/aisetup.exe)
