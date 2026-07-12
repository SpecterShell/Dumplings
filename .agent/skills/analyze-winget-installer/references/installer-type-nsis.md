# NSIS/Nullsoft Installer Type

Switch documentation: [NSIS command line usage](https://nsis.sourceforge.io/Docs/Chapter3.html).

## When To Use

Use `InstallerType: nullsoft` when WinGet invokes an NSIS/Nullsoft installer directly. If the NSIS installer only wraps another installer, keep `InstallerType: nullsoft` for the invoked EXE but model Apps & Features metadata from the payload that writes the visible ARP entry.

## Detection

Route here when `Get-NSISInfo` succeeds, the NSIS archive first header is found at a 512-byte aligned PE overlay start with `DEADBEEF` followed by `NullsoftInst`, or the analyzer returns high-confidence NSIS evidence.

For NSIS, the simplest wrapper test is whether the outer installer writes uninstall registry values. `Get-NSISInfo` reports only explicit uninstall registry writes recovered from the compiled script, not arbitrary version-string probing. If `WritesAppsAndFeaturesEntry` is false or nested installer payloads exist, inspect the payload or use VM ARP deltas.

## Manifest Shape

Use this shape when [Step 2](#step-2-identify-the-visible-arp-owner) proves that the outer NSIS installer writes the visible ARP entry, the installer has only one WinGet-selectable scope, and no Apps & Features override is required. Obtain `ProductCode` from `Get-NSISInfo.ProductCode`; it is the uninstall registry key name. Remove `ProductCode` if the parser cannot prove a stable key rather than deriving one from filenames or arbitrary strings. Use `Get-NSISInstallerSwitchInfo` and, for electron-builder packages, `Get-ElectronBuilderNSISInfo` before deciding that no additional fields are needed.

```yaml
Installers:
- Architecture: x64
  InstallerType: nullsoft
  InstallerUrl: https://example.com/Product-1.2.3-x64.exe
  InstallerSha256: <SHA256>
  ProductCode: <ProductCode>
```

Apply the WinGet defaults below. Do not copy default `InstallModes` or `InstallerSwitches` into this minimal shape.

## Manifest Shape: Dual Scope

Use this shape only when one installer binary has independently selectable user and machine modes through WinGet-usable command-line switches. Select this route in [Step 5](#step-5-determine-silent-behavior-and-scope) when `Get-ElectronBuilderNSISInfo.SupportedScopes` reports both scopes and the corresponding switches are present, or when ordinary NSIS control-flow and registry evidence proves explicit `/CurrentUser` and `/AllUsers` support. `Get-NSISInfo.Scope` alone describes only the simulated default path and is not sufficient evidence for this shape.

```yaml
Installers:
- Architecture: x64
  InstallerType: nullsoft
  Scope: user
  InstallerUrl: https://example.com/Product-1.2.3-x64.exe
  InstallerSha256: <SHA256>
  InstallerSwitches:
    Custom: /CurrentUser
  ProductCode: <ProductCode>
- Architecture: x64
  InstallerType: nullsoft
  Scope: machine
  InstallerUrl: https://example.com/Product-1.2.3-x64.exe
  InstallerSha256: <SHA256>
  InstallerSwitches:
    Custom: /AllUsers
  ProductCode: <ProductCode>
```

The scope-specific `Custom` values are not WinGet defaults and must remain on their respective installer entries. Do not use this shape when scope changes only according to current privilege, UAC acceptance, or an unsupported response file. In those cases WinGet cannot reliably select the scope, so follow the single-entry route and document the behavior for VM validation.

## Manifest Shape: Nested MSI/WiX Owns Visible ARP

Use this shape when the invoked file is NSIS but [Step 2](#step-2-identify-the-visible-arp-owner) proves that a nested MSI/WiX payload writes the visible Apps & Features entry. `Get-NSISInfo` supplies the wrapper evidence through `WritesAppsAndFeaturesEntry`, `ExtractedFiles`, and `ExecutedPayloads`. Parse an extracted MSI once with `Get-MsiInstallerInfo`; use its `ProductCode`, `UpgradeCode`, `AppsAndFeaturesInstallerType`, and `HidesMsiAppsAndFeaturesEntry` properties to establish the visible identity. If static ownership remains ambiguous, use before/after ARP collection in the VM instead of assuming this shape.

```yaml
Installers:
- Architecture: x64
  InstallerType: nullsoft
  InstallerUrl: https://example.com/Product-1.2.3-x64.exe
  InstallerSha256: <SHA256>
  ProductCode: '{NESTED-MSI-PRODUCT-CODE}'
  AppsAndFeaturesEntries:
  - InstallerType: wix
    UpgradeCode: '{NESTED-MSI-UPGRADE-CODE}'
```

Use `InstallerType: msi` in the Apps & Features entry when the visible nested entry should not be classified as WiX. Add `DisplayName`, `Publisher`, or `DisplayVersion` only when the visible ARP values require an override. Do not duplicate the installer-level `ProductCode` inside `AppsAndFeaturesEntries`, and do not use this shape when the nested MSI is hidden and an EXE entry is visible.

## WinGet Defaults And Overrides

WinGet populates missing switch fields independently for `InstallerType: nullsoft`:

| Field | WinGet default |
| --- | --- |
| `InstallerSwitches.Silent` | `/S` |
| `InstallerSwitches.SilentWithProgress` | `/S` |
| `InstallerSwitches.InstallLocation` | `/D=<INSTALLPATH>` |
| `InstallerSwitches.Log` | No default |

With the standard behavior, the effective install modes are `interactive`, `silent`, and `silentWithProgress`. Both silent modes use `/S`, so `silentWithProgress` does not imply that an NSIS installer displays progress.

Apply these omission and override rules:

- Omit `InstallModes` when the installer supports the standard three modes. If it supports a different set, write the complete supported array explicitly.
- Remove each `InstallerSwitches` child whose complete value is identical to the WinGet default. Missing children are populated independently, so retaining one custom child does not require copying the default children.
- If the installer needs a different value, explicitly write the complete replacement for that child. WinGet replaces that field; it does not merge command-line tokens with the default value.
- Keep additional mode-independent arguments in `InstallerSwitches.Custom`, including scope selection and post-install launch suppression.
- Add `Log` only when the installer implements a verified logging switch. Nullsoft has no WinGet default for it.
- Do not add `Silent: /S`, `SilentWithProgress: /S`, or `InstallLocation: /D=<INSTALLPATH>` merely to document NSIS defaults.

These defaults come from winget-cli [`GetDefaultKnownSwitches`](https://github.com/microsoft/winget-cli/blob/master/src/AppInstallerCommonCore/Manifest/ManifestCommon.cpp).

## Step-By-Step Analysis

Follow the steps in order. A step may route to a later branch, but do not skip ARP ownership, feed safety, scope, silent-install, or architecture checks merely because basic metadata was recovered.

### Step 1: Parse The NSIS Metadata Once

Load PackageModule and perform the complete metadata parse without running the installer:

```powershell
. .\Modules\PackageModule\Index.ps1

$Info = Get-NSISInfo -Path $InstallerFile
$ProductVersion = $Info.DisplayVersion
$ProductName = $Info.DisplayName
$Publisher = $Info.Publisher
$ProductCode = $Info.ProductCode
$Info.WritesAppsAndFeaturesEntry
$Info.RegistryWrites
$Info.ExtractedFiles
$Info.ExecutedPayloads
$Info.Protocols
$Info.FileExtensions
$Info.Warnings
$Info.ParserVersionInfo
```

`Get-NSISInfo` performs the complete NSIS metadata parse. Reuse its properties throughout the analysis. Do not call `Read-ProductVersionFromNSIS`, `Read-ProductNameFromNSIS`, `Read-PublisherFromNSIS`, `Read-ProductCodeFromNSIS`, `Read-ProtocolsFromNSIS`, or `Read-FileExtensionsFromNSIS` after obtaining `$Info`; each convenience reader invokes the parser again. Use a `Read-*FromNSIS` function only when one isolated field is needed and no `Get-NSISInfo` result already exists.

Treat explicit uninstall registry writes as authoritative. Use `DisplayVersion`, `DisplayName`, `Publisher`, `DefaultInstallLocation`, `UninstallString`, `QuietUninstallString`, `DisplayIcon`, `SystemComponent`, and the uninstall key represented by `ProductCode`. Do not infer a version from arbitrary strings when `DisplayVersion` is absent. Review every parser warning before continuing; unresolved values must remain unresolved until another static source or VM evidence supplies them.

Always continue to Step 2. Do not call the switch or electron-builder helpers yet unless their later route requires them.

### Step 2: Identify The Visible ARP Owner

Some NSIS installers are only wrappers around another installer. In those cases, the outer NSIS executable may not write the visible Apps & Features entry; the nested MSI/WiX/custom EXE does.

Inspect these `$Info` properties together:

- `ExtractedFiles` for embedded `.msi`, `.msp`, `.msu`, or setup `.exe` payloads.
- `ExecutedPayloads` for `Exec`, `ExecWait`, or `ShellExec` commands that launch extracted setup files.
- `WritesAppsAndFeaturesEntry` to determine whether the simulated outer NSIS path writes a visible uninstall entry. A `SystemComponent=1` write is hidden and does not count as visible ARP ownership.
- `RegistryWrites` to confirm the uninstall root, key, and values rather than relying only on filenames.

Route according to the combined evidence:

- Outer NSIS writes the visible entry and no nested payload supersedes it: retain the first manifest shape and continue to Step 3.
- Outer NSIS writes an entry and also launches a nested installer: inspect both entries. Model the entry that remains visible and matches the installed application; escalate to Step 8 if ownership cannot be proven statically.
- Outer NSIS does not write a visible entry and launches a nested MSI/WiX: extract or otherwise obtain that payload, call `$MsiInfo = Get-MsiInstallerInfo -Path $NestedMsi`, and use the nested MSI/WiX manifest shape only when `$MsiInfo.AppsAndFeaturesInstallerType` and `$MsiInfo.HidesMsiAppsAndFeaturesEntry` prove its visible ARP behavior.
- Outer NSIS does not write a visible entry and launches a custom EXE: route the payload to its focused installer parser. Do not label the ARP entry as MSI/WiX without MSI evidence.
- No component can be proven to write a visible entry: route to Step 8 for VM ARP-delta validation.

Existing manifests with `InstallerType: nullsoft` and `AppsAndFeaturesEntries.InstallerType: msi` or `wix` are useful leads, but are not evidence for a new installer version by themselves.

Known wrapper examples:

- `Blueberry.FlashbackExpress.6`: NSIS wrapper with nested WiX/MSI ARP behavior.
- `Apache.OpenOffice`: NSIS wrapper with nested MSI behavior.
- `Mozilla.*`: wrapper installers can differ from MSI packages distributed by Mozilla; model the manifest installer and verify the visible ARP entry.

### Step 3: Detect Electron-Builder And Validate Its Update Feed

Many modern desktop NSIS installers, especially Electron applications, are electron-builder NSIS. Because architecture and scope are required for manifest authoring, call the detailed helper directly and reuse its predicate and evidence properties:

```powershell
$ElectronBuilderInfo = Get-ElectronBuilderNSISInfo -Path $InstallerFile
$IsElectronBuilder = $ElectronBuilderInfo.IsElectronBuilder
$ElectronBuilderInfo.Architectures
$ElectronBuilderInfo.Architecture
$ElectronBuilderInfo.SupportedScopes
$ElectronBuilderInfo.Evidence
```

Use `Test-ElectronBuilder` instead only when a Boolean result is the sole required output and no architecture or scope decision will follow. Do not call `Test-ElectronBuilder` immediately before `Get-ElectronBuilderNSISInfo`, because that parses the installer twice.

If `$IsElectronBuilder` is false, skip the remainder of this step and continue to Step 4. If it is true, inspect update-source evidence before accepting a feed asset as `InstallerUrl`:

1. Try replacing the original installer filename in its official URL with `latest.yml`.
2. If that fails, inspect the embedded `app-*.7z` application's `resources\app-update.yml`, `resources\latest.yml`, or equivalent updater configuration.
3. Fetch the selected feed in the task with any package-specific headers, query parameters, cookies, or fallback handling. Pass only the returned YAML string to the converter.
4. Resolve relative asset paths against the feed URL and verify the feed version, size, SHA512, downloaded SHA256, and official domain.

```powershell
$LatestYaml = Invoke-RestMethod -Uri $LatestYamlUri -Headers $Headers
$UpdateFeed = $LatestYaml | ConvertFrom-ElectronBuilderUpdateFeed
$UpdateFeed.Version
$UpdateFeed.Files
```

`ConvertFrom-ElectronBuilderUpdateFeed` and `ConvertFrom-ElectronBuilderLatestYaml` do not access the network. They only parse the provided `latest.yml` content string.

Do not assume `app-update.yml` is authoritative. Some applications leave an invalid or placeholder URL there and call electron-updater's `setFeedURL()` at runtime. When static configuration is invalid:

- If extracted application source is available under `app\`, search its JavaScript for `setFeedURL(` and trace the URL expression and environment/configuration inputs.
- If the application is packaged as `app.asar`, extract or inspect the archive, then search the contained source for `setFeedURL(`. Do not execute the application to discover the URL on the host.
- Accept the recovered URL only when its construction is deterministic and resolves to an official publisher-controlled endpoint.
- If the runtime URL cannot be recovered safely, skip feed-based source automation and continue to Step 4 with the original official installer source. Record a warning rather than using the invalid configuration URL.

Also distinguish initial-install installers from update-only installers. Some publishers distribute different binaries for first installation and self-update:

- Compare the original installer and feed-selected asset at the same version by URL, size, and SHA256.
- If the feed URL introduces terms such as `update`, `upgrade`, or similar updater-only markers that are absent from the original installer URL, and the hashes differ for the same version, treat the feed asset as an update installer.
- Keep the original initial-install installer as `InstallerUrl`, warn the user that the feed publishes a different updater binary, and do not substitute the feed asset merely because it is versioned.
- The feed may still provide version or release-date evidence when trustworthy, but its update-only asset is not the manifest installer.

See [Electron-Builder Update Feeds](../../author-winget-manifest/references/package-discovery-workflow.md#electron-builder-update-feeds) for the general URL-selection routine.

### Step 4: Determine Architecture

For electron-builder, reuse `$ElectronBuilderInfo`. The helper detects embedded app packages such as `app-32.7z`, `app-64.7z`, and `app-arm64.7z`. It reports every embedded architecture in `Architectures`; its singular `Architecture` property applies the WinGet-compatible heuristic that x86 wins for a universal installer containing an x86 payload.

For ordinary NSIS, the PE stub architecture is not sufficient when it extracts a differently-architected application. Determine the manifest architecture from extracted payload names, nested installer metadata, and installed executable architecture. If static payload evidence is missing or contradictory, route architecture validation to Step 8. Exclude unsupported architectures rather than declaring an installer neutral.

Known electron-builder evidence examples:

- `Aircall.AircallWorkspace`: x64 user-scope installer with embedded `app-64.7z`.
- `Obsidian.Obsidian`: universal installer with `app-32.7z`, `app-64.7z`, and `app-arm64.7z`; supports both `/currentuser` and `/allusers`.
- `GameSir.GameSirT4kApp`: x86 user-scope installer with embedded `app-32.7z`.
- `GameSir.GameSirConnect`: x86 dual-scope installer with embedded `app-32.7z`; supports both `/currentuser` and `/allusers`.
- `GDevelop.GDevelop`: x64 dual-scope installer with embedded `app-64.7z`.
- `GauzyTech.NeatReader`: x86 machine-scope installer with embedded `app-32.7z`; full initialization simulation reports `SupportedScopes: machine`.
- `JGraph.Draw`: x64 machine-scope manifest entry with embedded `app-64.7z`.

Continue to Step 5 for both electron-builder and ordinary NSIS.

### Step 5: Determine Silent Behavior And Scope

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
- ordinary NSIS: use explicit `/CurrentUser` and `/AllUsers` variants, scope macros, `SetShellVarContext`, and conditional HKCU/HKLM uninstall writes as evidence. `$Info.Scope` reports only the simulated/default scope and cannot prove dual-scope support by itself.
- user only or machine only: keep one installer entry and write `Scope` only when the evidence supports it.
- both scopes with usable switches: select the dual-scope manifest shape. Preserve the exact switch casing accepted by that installer.
- scope selected only by current privilege, UAC acceptance, or a response file: do not create normal dual-scope entries. `JetBrains.*` and `Mozilla.*` are known rare examples of this behavior.
- unresolved scope: route to Step 8 and test non-elevated and elevated paths separately.

Known ordinary dual-scope examples include `BleachBit.BleachBit`, `KiCad.KiCad`, and most `KDE.*` installers. KDE CDN links expire frequently, so do not use them as durable automated fixtures.

### Step 6: Record Metadata And Registry Associations

Build the manifest evidence from the retained `$Info` object:

- `DisplayVersion` supplies the installed version only when explicitly written to the uninstall registry.
- `DisplayName` and `Publisher` supply visible ARP identity.
- `ProductCode` is the NSIS uninstall registry key name, not an MSI product code unless Step 2 proved that a nested MSI owns the visible entry.
- `DefaultInstallLocation`, `UninstallString`, `QuietUninstallString`, and `DisplayIcon` are supporting ARP evidence.
- `RegistryAssociationInfo`, `Protocols`, and `FileExtensions` contain literal protocol and extension writes recovered during the same parse. Do not call `Read-ProtocolsFromNSIS` or `Read-FileExtensionsFromNSIS` after `$Info` already exists.

Some applications register protocols or extensions only on first run. An empty static result means the installer did not prove the association; it does not prove that the installed application never creates one. Route first-run association capture to Step 8 when those fields matter.

### Step 7: Build Apps & Features And Installer Fields

Choose the manifest shape using the earlier route results:

- Direct visible NSIS ARP, one scope: use the first manifest shape.
- Direct visible NSIS ARP, two explicitly selectable scopes: use the dual-scope shape.
- Nested visible MSI/WiX ARP: use the nested MSI/WiX shape and include `UpgradeCode`.
- Nested custom EXE ARP: keep outer `InstallerType: nullsoft`, but add only the visible ARP overrides proved for the nested EXE.

Apply these field rules:

- Recheck `InstallModes` and every `InstallerSwitches` child against the WinGet defaults. Remove equal values; explicitly retain complete non-default overrides.
- Keep `ProductCode` at installer level; do not duplicate it in `AppsAndFeaturesEntries.ProductCode`.
- Add `AppsAndFeaturesEntries` only for a meaningful visible-ARP mismatch, including nested installer type, publisher, package name, or display version.
- Add `InstallerType: msi` or `wix` inside the entry only when the visible ARP entry has that effective type.
- Include `UpgradeCode` whenever the outer or Apps & Features installer type is `msi`, `wix`, or `burn`.
- Do not retain a version-bearing `DisplayName` override when WinGet normalization removes only the version and the remaining name matches `PackageName`.
- Preserve separate installer entries for scope-specific switches; do not move a scope-specific `Custom` switch to manifest root.

### Step 8: Escalate Unresolved Behavior To VM Validation

Do not execute the installer on the host. Use the Hyper-V workflow when any required fact remains unresolved, especially:

- the outer NSIS and nested payload ARP ownership conflict or cannot be determined;
- electron-builder configuration contains an invalid feed and no deterministic `setFeedURL()` source can be recovered;
- the feed appears to publish an update-only installer distinct from the original installer;
- scope depends on elevation, UAC, or runtime conditions;
- silent mode may show UI, abort, require a license action, or ignore `/S`;
- application architecture cannot be determined from payload evidence;
- protocols or file extensions may be registered only on first run;
- parser warnings identify unsupported or conditional control flow.

Before finishing, verify that every decision can be traced to `$Info`, `$SwitchInfo`, `$ElectronBuilderInfo`, feed and hash evidence, a nested parser result, or recorded VM evidence. Do not infer missing metadata from filenames or arbitrary strings.

## VM Validation

Follow [VM-Only Dynamic Validation Workflow](vm-validation-workflow.md) for dual-scope control flow, custom or rejected silent mode, electron-builder scope behavior, nested payload ARP ownership, and associations registered only on first run.

## Implementation Sources

- [NSIS](https://github.com/NSIS-Dev/nsis)
- [7-Zip](https://github.com/ip7z/7zip)
- [Komac](https://github.com/russellbanks/Komac)
- [electron-builder](https://github.com/electron-userland/electron-builder)
