# MSI and WiX static analysis

[Back to the MSI and WiX workflow](workflow.md)

## Parse MSI metadata once

Load PackageModule and call the detailed parser with the installer path:

```powershell
. .\Modules\PackageModule\Index.ps1

$Info = Get-MsiInstallerInfo -Path $InstallerFile

$Info.DisplayVersion
$Info.DisplayName
$Info.ProductCode
$Info.UpgradeCode
$Info.AllUsers
$Info.InstallerBuilder
$Info.InstallLocationSwitch
$Info.AppsAndFeaturesInstallerType
$Info.AppsAndFeaturesProductCode
$Info.SupportedArchitectures
$Info.UnsupportedArchitectures
$Info.ElevationRequirement
$Info.ElevationRequirementEvidence
$Info.ChromiumEnterpriseMsiInfo
$Info.Protocols
$Info.FileExtensions
```

Do not follow this call with `Read-ProductCodeFromMsi`, `Read-UpgradeCodeFromMsi`, `Read-InstallerBuilderFromMsi`, location readers, ARP readers, or association readers for fields already present in `$Info`; those convenience functions reopen and parse the database.

Use a single-field `Read-*FromMsi` helper only when one isolated value is needed and no detailed result exists. Pass `TransformPath` or `PatchPath` to the same `Get-MsiInstallerInfo` call when transforms or patches materially change the effective MSI tables.

## Classify the MSI builder

Route from `$Info.InstallerBuilder`:

- `WiX`: use `InstallerType: wix` and the WiX manifest shape.
- `AdvancedInstaller`: retain `InstallerType: msi`, then use [visible ARP analysis](#identify-the-visible-arp-entry) to select the native-MSI or custom-EXE ARP shape.
- `InstallShield`: retain `InstallerType: msi` and use the InstallShield MSI shape. Do not confuse it with an InstallShield EXE wrapper.
- `Unknown`: use the generic MSI shape unless another structured table or summary marker proves the builder.

`Get-MsiInstallerInfo` currently returns `WiX`, `AdvancedInstaller`, `InstallShield`, or `Unknown`. Treat builder classification as authoring evidence, not as proof of visible ARP behavior or silent-install success. Use `Test-WiXInstaller` only when the Boolean is needed without the detailed result; do not parse the same file with both functions.

## Identify the visible ARP entry

WinGet considers an ARP entry MSI-backed when its `WindowsInstaller` registry value is `1`; otherwise it treats the entry as EXE-style. The fact that an MSI database wrote a key does not make that key MSI-style.

Route using the combined `$Info` evidence:

- Native MSI visible: `HidesMsiAppsAndFeaturesEntry` is false and `AppsAndFeaturesProductCode` equals `ProductCode`. Keep `$Info.ProductCode` and omit Apps & Features overrides unless another parsed value differs.
- Custom EXE visible: `HidesMsiAppsAndFeaturesEntry` and `HasCustomAppsAndFeaturesEntry` are true, and `AppsAndFeaturesInstallerType` is `exe`. Use `$Info.AppsAndFeaturesProductCode` and the custom EXE ARP shape.
- `.msq` visible: `HidesMsiAppsAndFeaturesEntry` and `HasMsqAppsAndFeaturesEntry` are true. Use `$Info.AppsAndFeaturesProductCode`, inspect the `.msq` registry rows for `WindowsInstaller`, and use the `.msq` shape when the visible entry is EXE-style.
- Native and custom evidence conflict, or the custom key is conditional: compare ARP entries through the canonical [VM validation workflow](../../workflows/vm-validation.md).

Do not model a hidden native entry. Exclude entries with `SystemComponent=1`, and use the product code of the visible entry at installer level. Existing manifests are supporting evidence only; re-evaluate the current MSI because authoring settings can change between versions.

## Determine install location, switches, and modes

Use `$Info.InstallLocationProperty`, `$Info.InstallLocationSwitch`, and `$Info.InstallLocationSource`. The parser validates candidate public directory properties against the `Directory`, `Component`, and file-installation structure instead of selecting any all-uppercase property.

Route the result:

- `TARGETDIR="<INSTALLPATH>"`: omit `InstallerSwitches.InstallLocation` because it equals the WinGet default.
- Another verified public property such as `INSTALLDIR`, `INSTALLLOCATION`, `APPLICATIONROOTDIRECTORY`, `INSTALL_ROOT`, or `APPDIR`: write the complete returned `InstallLocationSwitch` override.
- No verified property: omit the field. Do not invent `INSTALLDIR` from builder convention.
- `WIXUI_INSTALLDIR` present but not connected to installed components: ignore it.

Then compare silent behavior with the WinGet defaults:

- Standard MSI quiet/passive behavior: omit `InstallModes`, `Silent`, `SilentWithProgress`, and `Log`.
- An MSI that turns `/passive` into interactive UI: explicitly omit `silentWithProgress` from `InstallModes`; if a defensive `SilentWithProgress` override is retained, map it to the verified quiet command rather than `/passive`.
- Package-specific complete replacements: write only the differing child fields and retain no-reboot behavior.
- License acceptance or another public property needed in all modes: put it in `Custom`; add `Agreements` only when the authoring skill's locale workflow also requires it.
- Custom actions that reject quiet/passive mode or return nonstandard codes: use the canonical [VM validation workflow](../../workflows/vm-validation.md).

## Record associations and build manifest fields

Reuse `$Info.Protocols`, `$Info.FileExtensions`, and `$Info.RegistryAssociationInfo`. They are derived from the MSI `Registry`, `Extension`, `ProgId`, `Verb`, and `MIME` tables. Do not call `Read-ProtocolsFromMsi` or `Read-FileExtensionsFromMsi` after `$Info` already exists.

Choose the manifest shape using the earlier results, then apply these rules:

- Use `ProductVersion`, `ProductName`, `ProductCode`, and `UpgradeCode` from structured MSI properties, not filename strings.
- Use `$Info.AppsAndFeaturesProductCode` instead of `$Info.ProductCode` when [visible ARP analysis](#identify-the-visible-arp-entry) proves a different uninstall key.
- Add `AppsAndFeaturesEntries` only for a meaningful visible mismatch in installer type, name, publisher, or version.
- Whenever an Apps & Features item is required and either the outer type or item type is `msi`, `wix`, or `burn`, include `$Info.UpgradeCode`.
- Do not duplicate installer-level `ProductCode` inside `AppsAndFeaturesEntries`.
- Recheck `InstallModes` and every `InstallerSwitches` child against the WinGet defaults. Remove equal values and retain complete non-default replacements.
- Preserve association fields even though they are not currently included in the public WinGet index; route first-run-only associations to the canonical [VM validation workflow](../../workflows/vm-validation.md).

## Escalate unresolved behavior to VM validation

Do not execute the installer on the host. Use the Hyper-V workflow when any required fact remains unresolved, especially:

- native and custom ARP entries conflict or depend on conditions;
- `.msq` or another custom entry's `WindowsInstaller` value is unclear;
- scope cannot be established from `ALLUSERS` and Windows Installer product registration;
- immediate launch conditions or custom actions may reject a quiet non-elevated invocation;
- component conditions or installed payloads conflict with summary-template architecture;
- custom actions may reject quiet/passive installation, reboot, or alter process exit codes;
- the install-location property is present but may not affect the installed payload;
- associations may be created only by a custom action or application first run.

Before finishing, verify that every manifest decision traces to `$Info`, structured MSI tables, or recorded VM evidence.
