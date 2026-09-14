# Wise workflow

## When to use

Use this workflow when `Test-WiseInstaller` succeeds or structural analysis identifies a WiseScript overlay, a Wise `.WISE` MSI record, or a vendor launcher containing a complete WiseScript setup. WinGet invokes these routes as `InstallerType: exe`; the embedded format determines metadata authority and supported switches.

Read [Wise installer internals](../../internals/wise/overview.md) before changing detection, binary decoding, extraction, or parser limits.

## Detection

Run the parser instead of relying on a `Wise` product string or a Detect It Easy label:

```powershell
if (Test-WiseInstaller -Path $InstallerFile) {
  $Info = Get-WiseInfo -Path $InstallerFile
}
```

The parser requires one of these validated structures:

- a PE `.WISE` section containing an MSI CFB record with the MSI root CLSID and a matching Wise CRC32;
- a PE or NE host with a bounded WiseScript overlay whose required state member decompresses and passes CRC32 validation; or
- a bounded nested PE in an outer launcher's resource range that contains the preceding WiseScript structure.

Marker strings, a section name without a valid record, CFB magic without the MSI root CLSID, and an arbitrary nested MZ sequence are not enough.

## Binary structure

```text
distributed EXE
+-- MZ + NE host
|   `-- WiseScript overlay
+-- MZ + PE host
|   +-- WiseScript overlay
|   `-- .WISE section -> exact MSI CFB -> CRC32
`-- vendor PE launcher
    `-- .rsrc bounded nested PE -> WiseScript -> InstallFile -> .WISE MSI launcher
```

The WiseScript overlay contains a versioned header, raw-Deflate members with CRC trailers, a compiled state machine, optional WSE source metadata, and file-record payloads. See [binary format](../../internals/wise/binary-format.md) for offsets, field sizes, profiles, and nested-range rules.

## Step 1: Parse once

```powershell
$Info = Get-WiseInfo -Path $InstallerFile

$Info.ContainerRoute
$Info.FormatProfile
$Info.WiseVariant
$Info.BuilderVersion
$Info.ProductCode
$Info.UpgradeCode
$Info.Scope
$Info.InstallModes
$Info.InstallerSwitches
$Info.AppsAndFeaturesEntries
$Info.Diagnostics
$Info.UnresolvedFields
```

Reuse this result. Do not call multiple `Read-*FromWise` helpers after `Get-WiseInfo`.

## Step 2: Follow the route

### Direct Wise MSI wrapper

`ContainerRoute: WiseSection/Msi` means the outer PE contains an exact MSI database in `.WISE`. Use the MSI ProductCode, UpgradeCode, architecture, associations, explicit scope, install-location property, and Windows Installer ARP evidence.

The wrapper's MSI-style switches must be authored explicitly because WinGet has no Wise defaults for generic EXE media. Keep `/norestart` in the silent mode switches. Omit the install-location field if the nested MSI does not identify a property.

```yaml
InstallerType: exe
InstallModes:
- interactive
- silent
- silentWithProgress
InstallerSwitches:
  Silent: /quiet /norestart
  SilentWithProgress: /passive /norestart
  InstallLocation: INSTALLDIR="<INSTALLPATH>"
  Log: /log "<LOGPATH>"
ProductCode: <NestedMsiProductCode>
AppsAndFeaturesEntries:
- InstallerType: msi
  UpgradeCode: <NestedMsiUpgradeCode>
```

Replace `INSTALLDIR` with the returned `InstallLocationProperty`. The manifest optimizer removes ProductCode or InstallerType from the Apps & Features entry when they are redundant in the complete manifest context.

### WiseScript MSI prerequisite wrapper

`WiseVariant: WiseScript MSI prerequisite wrapper` means a WiseScript file action contains another Wise launcher whose `.WISE` section owns a validated MSI. Use the nested MSI for installed-product identity, but use the outer script for installability and elevation decisions.

Do not assume `/S`, `/quiet`, or `/passive` reaches the nested MSI. The two NavigatorPlus 1.42 installers are proven interactive-only wrappers and return no installer switches:

```yaml
InstallerType: exe
InstallModes:
- interactive
ElevationRequirement: elevationRequired
ProductCode: <NestedMsiProductCode>
AppsAndFeaturesEntries:
- InstallerType: msi
  UpgradeCode: <NestedMsiUpgradeCode>
```

### Pure WiseScript

`WiseVariant: WiseScript` means no authoritative nested MSI was found. The parser can return variables, payload records, registry writes, execution records, custom ARP candidates, and opaque external-call evidence.

Classic compatible WiseScript runtimes use `/S` for silent installation and do not provide a distinct progress mode. Because `exe` has no WinGet default, write the proven override explicitly:

```yaml
InstallerType: exe
InstallModes:
- interactive
- silent
InstallerSwitches:
  Silent: /S
```

Do not use this shape when `Wise.Metadata.ScriptModelUnsupported`, package-specific interactive behavior, or an opaque bootstrapper prevents proof of unattended installation.

### Historical NE WiseScript

Wise 5, 6, and early 7 can use a 16-bit NE host. Wise 7.01 state records are decoded. Wise 5 and 6 currently stop after structural header, Deflate, size, and CRC validation because their state dialect is unsupported. Preserve existing manifest metadata for those partial routes and use VM evidence; do not recover identity from arbitrary strings.

## Step 3: Establish ARP ownership

For a validated MSI route, use the nested MSI's ProductCode and UpgradeCode. Set `AppsAndFeaturesEntries.InstallerType: msi` when the visible row is Windows Installer-owned and that differs from the outer `InstallerType: exe`.

For pure WiseScript, inspect `AppsAndFeaturesEvidence`. A row proves only a compiled literal registry action until its active condition is known. Multiple candidates leave ProductCode and scope unresolved. A single candidate accompanied by `Wise.Metadata.ScriptArpConditionsRequireValidation` still requires VM comparison before authoring it.

Never use a temporary Run key, resume token, log path, generated uninstaller filename, launcher identity, or PE version string as ProductCode.

## Step 4: Resolve scope and architecture

Use explicit nested MSI scope evidence when available. `ALLUSERS=1` supports machine scope. If the MSI does not prove a single scope, omit or preserve `Scope` until VM validation confirms the real ARP hive.

`Requested Execution Level=requireAdministrator` supports `ElevationRequirement: elevationRequired`; it does not by itself establish machine scope.

Determine architecture from the nested MSI template and installed application binaries. The outer NE or PE machine type describes the bootstrapper and can differ from the payload architecture.

## Step 5: Inspect files and system effects

```powershell
$Info.PayloadCatalog
$Info.RegistryWrites
$Info.ExecutedPrograms
$Info.OperationCounts
$Info.Protocols
$Info.FileExtensions
```

`PayloadCatalog` contains every projected file record, including conditional and language-specific duplicates. `RegistryWrites` and `ExecutedPrograms` are static operation evidence, not proof that every record runs. External DLL calls require static inspection or VM validation.

`Expand-WiseInstaller` currently exports the exact authoritative MSI selected by the supported MSI routes:

```powershell
$Msi = Expand-WiseInstaller -Path $InstallerFile -DestinationPath (Join-Path $Scratch 'embedded.msi') -CollisionAction Rename
```

General pure-WiseScript extraction is not yet a public contract. Do not describe `PayloadCatalog` paths as installed files without condition and destination-variable resolution.

## Step 6: Apply WinGet suggestions conservatively

```powershell
$Analysis = Get-WinGetInstallerAnalysis -Path $InstallerFile
$WiseResult = $Analysis.ParserResults | Where-Object { $_.Name -eq 'Wise' -and $_.Success } | Select-Object -First 1
$WiseResult.Result.SuggestedManifestFields
```

Suggestions contain only WinGet 1.12 installer fields. Exact route evidence overrides the generic family template. For example, NavigatorPlus receives `interactive` only and no switch object, while TI Connect receives its MSI install-location property and MSI-owned ARP type.

## Step 7: Validate dynamically when required

Follow [VM validation workflow](../../workflows/vm-validation.md). Wise-specific checks are:

- capture the process exit code for interactive, silent, cancellation, and nested failure paths;
- compare HKLM 64-bit, HKLM 32-bit, and HKCU ARP rows, including `WindowsInstaller` and `SystemComponent`;
- verify whether the outer wrapper forwards or consumes `/S`, `/quiet`, `/passive`, properties, and log arguments;
- compare the observed ARP tuple to the parser's exact ProductCode, DisplayName, Publisher, install location, uninstall commands, and registry view;
- check which condition-dependent payload and registry records actually run; and
- inspect external DLL effects and application first-run associations separately.

## Known examples

- `TexasInstruments.TIConnect` uses `WiseSection/Msi`; the nested Wise-authored MSI supplies ProductCode, UpgradeCode, machine scope, `INSTALLDIR`, and the visible MSI ARP entry.
- [`FrancotypPostalia.NavigatorPlus` 1.42 x86 and x64](https://www.fpmailing.co.uk/support/navigatorplus-support) use an outer resource launcher, a Wise 9.02 WiseScript prerequisite package, and distinct nested MSI payloads. Both supplied wrappers are interactive-only and request administrator elevation.
