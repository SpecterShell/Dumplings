# TigerSetup

## Detection

TigerSetup is a native x64 installer with a generation-specific footer and Protobuf metadata. `Test-TigerSetupInstaller` requires a valid PE, footer CRC/layout, hashed metadata and a consistent ZIP catalog or solid-payload index. Product strings alone do not identify this family. Generated uninstallers use role 2 and no application payload; the detector excludes them.

## Binary Structure

```text
PE loader
+-- engine: Zstandard executable
+-- solid payload: Zstandard indexed file regions
+-- metadata: Zstandard(Protobuf schema 2)
+-- footer[320]: TIGERSTP ... CRC32 ... PTSREGIT
`-- optional PE certificate table
```

The diagram shows format 3. Historical 0.5.2-0.7.1 source uses a PE engine followed by raw metadata, ZIP and a 128-byte footer. Version 0.8.0 splits loader/engine and uses solid Zstd with raw metadata and a 256-byte footer. Version 0.9.0 onward uses compressed metadata, schema 2 and a 320-byte footer. See [TigerSetup internals](../../internals/tiger-setup/overview.md) for exact layouts. Published 0.12.0-0.14.0 fixtures use format 3; earlier routes are source-backed prototypes with synthetic coverage, not claimed production/VM fixtures.

## Step 1: Parse And Select A Scope

```powershell
$Info = Get-TigerSetupInfo -Path $InstallerPath
$Info.Metadata.package
$Info.ARPEntries
$Info.Diagnostics
$Info.DependencyInfo
$Analysis = Get-WinGetInstallerAnalysis -Path $InstallerPath
$Analysis.SuggestedManifestFields
$Analysis.SuggestedManifestVariants
```

Reuse `$Info` rather than reparsing with individual `Read-*FromTigerSetup` helpers. `-Scope user|machine` selects a supported route; omitted on dual-scope media it returns no single scope or location. `-Option @{ name = 'off' }` selects compiled Boolean/choice predicates. Raw parser evidence is provider-neutral; WinGet suggestions belong to the analyzer projection. An upgrade can preserve installed option choices and scope instead of fresh-install defaults.

`-CommandLine 'install --quiet --scope user --install-root "C:\Apps\Product"'` models an absolute fresh-install override, including ARP location, icon and `%INSTALLROOT%` registry data. This switch is present from the earliest checked-in 0.5.2 CLI. Both separated and `--install-root=...` forms are accepted; relative roots are rejected. Existing installations need separate validation: same-version no-op runs retain the recorded root even with a conflicting override, while reconciliation can refuse a conflict. Inspect `FormatProfile` and `MetadataSchema` rather than inferring the format from the application version. Known invalid resource declarations are rejected before ARP projection, including inactive predicates and hive/scope conflicts.

## Step 2: Inspect Payloads And Effects

```powershell
Expand-TigerSetupInstaller -Path $InstallerPath -DestinationPath $ExtractedPath -Name '*.exe' -CollisionAction Rename
Expand-TigerSetupInstaller -Path $InstallerPath -DestinationPath $RawPath -RawEntries -CollisionAction Rename
Expand-TigerSetupInstaller -Path $InstallerPath -DestinationPath $UninstallerPath -IncludeUninstaller -Scope user -CollisionAction Rename
```

Omitted `-Name` extracts all packaged application files, including conditional files, zero-byte files and declared empty directories; catalog extraction does not simulate installation. `-RawEntries` adds prerequisites/action programs, engine and metadata under `_tigersetup`, plus the separate loader when present in formats 2/3. Narrow metadata-only selectors do not decode unrelated engine/payload blocks. `-IncludeUninstaller` exports a reconstructed state-directory uninstaller under `_tigersetup/state/<scope>/uninstall.exe` using the source generation; choose a scope for dual-scope media. Default collision handling prompts only on a collision; automated callers specify a policy. Content verification and collision decisions precede atomic per-file publication, preserving existing files on decoding/integrity failures. Budget disk for the solid decoded stream plus staged selected files. No extracted executable is run.

Metadata preserves shortcuts, PATH/environment changes, registry values, file/URL associations, App Paths, Explorer verbs, firewall rules, dependencies, actions, quiescence and completion-page launch settings. Dependencies remain evidence rather than automatic manifest mutations. Programs invoked by actions can add effects the declarative metadata does not describe.

## Step 3: Choose The Manifest Shape

```yaml
InstallerType: exe # TigerSetup
Architecture: x64
Scope: machine
ElevationRequirement: elevatesSelf
InstallModes:
- interactive
- silent
- silentWithProgress
InstallerSwitches:
  Silent: install --quiet
  SilentWithProgress: install --quiet
  Custom: --scope machine
  Log: --log "<LOGPATH>"
  InstallLocation: --install-root "<INSTALLPATH>"
UpgradeBehavior: install
```

WinGet supplies no TigerSetup defaults. Both unattended fields use the same windowless command; `silentWithProgress` does not imply a progress UI. User scope uses `--scope user` and a writable private root; a protected custom root can trigger elevation. Dual-scope variants retain separate install locations. The engine accepts an absolute fresh-install root override; existing-state no-op and reconciliation paths handle conflicts differently. Upstream's manifest writer omits this switch for authored nondefault roots; review application path expectations before exposing it.

The projection follows upstream return mappings: 2 invalid parameter, 3 missing dependency, 5 cancelled, 6 application in use, 8 unsupported system, 3010 reboot required, and 1/4/7 custom failures. Exit 0 is ordinary success. Runtime `InstallerType` is `exe`; the family comment belongs only in YAML examples.

## Step 4: Check ARP

The built-in key is `registration.key_name`, falling back to `package.id`. Name/version overrides come from registration and publisher from the package. User scope uses HKCU and machine scope HKLM, both native 64-bit view. The uninstaller is `%LOCALAPPDATA%\TigerSetup\<id>\uninstall.exe` or `%PROGRAMDATA%\TigerSetup\<id>\uninstall.exe`. Both commands quote the entire path; only the quiet command appends `uninstall --quiet`. Custom uninstall rows and visibility flags remain separate evidence. Do not change an existing manifest's scope based on the fresh-install default.

## Step 5: Validate In The VM

Follow [VM validation](../../workflows/vm-validation.md). Check the explicit scope command, registry view, application launch, state-directory uninstaller, quoting and exit codes. Compare associations with the same selected options. Validate dependencies/actions only where they affect the manifest. Never use runtime fault-injection switches for ordinary validation.

Version 0.14.0 passed user and machine install/uninstall checks, and a controlled rich fixture matched all four visible/hidden/custom ARP rows, association commands and PATH/environment values. Reconstructed uninstallers worked for both scopes and a limited-token user; captured state returned to baseline. Embedded prerequisite and no-op action execution was logged. Two installed scopes without explicit selection returned 2, while an unchanged same-version install retained its original root and returned 0. Interactive machine UAC consent, Inno migration, network dependencies and opaque custom effects still need artifact-specific validation. Historical formats 1/2 have synthetic coverage rather than executable VM fixtures. The shared VM was neither restarted nor restored.
