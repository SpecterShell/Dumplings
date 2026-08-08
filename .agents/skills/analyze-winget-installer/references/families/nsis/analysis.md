# NSIS static analysis

[Back to the NSIS workflow](workflow.md)

## Parse NSIS metadata once

Load PackageModule and perform the complete metadata parse without running the installer:

```powershell
. .\Modules\PackageModule\Index.ps1

$Info = Get-NSISInfo -Path $InstallerFile -Architecture $TargetArchitecture -Scope $TargetScope
$ProductVersion = $Info.DisplayVersion
$ProductName = $Info.DisplayName
$Publisher = $Info.Publisher
$ProductCode = $Info.ProductCode
$Info.WritesAppsAndFeaturesEntry
$Info.RegistryWrites
$Info.AppsAndFeaturesEntries
$Info.AppsAndFeaturesEntryEvidence
$Info.Notices
$Info.HasLocalizedAppsAndFeaturesEntries
$Info.ExtractedFiles
$Info.ExecutedPayloads
$Info.IsPortable
$Info.PortableEvidence
$Info.IsTauri
$Info.TauriInstallerMode
$Info.RequestedExecutionLevel
$Info.TauriEvidence
$Info.Protocols
$Info.FileExtensions
$Info.Warnings
$Info.ParserVersionInfo
```

`Get-NSISInfo` performs the complete NSIS metadata parse. Pass the effective WinGet installer architecture when it is already known, because an x86 NSIS stub can select different ARP keys, names, and install roots on x86, x64, or ARM64 Windows. Pass the effective authored scope when it is known; compiled MultiUser installers such as `DBeaver.DBeaver.*` can write different HKCU/HKLM uninstall keys, display names, and install roots from the same binary. When a manifest has multiple effective architecture/scope combinations, parse once per distinct combination and reuse each result for the corresponding entry. Omit `-Scope` on the discovery pass when scope support is not yet known, then inspect `HasScopeRuntimeCheck` and `SupportedScopes` before requesting targeted results. Do not call `Read-ProductVersionFromNSIS`, `Read-ProductNameFromNSIS`, `Read-PublisherFromNSIS`, `Read-ProductCodeFromNSIS`, `Read-ProtocolsFromNSIS`, or `Read-FileExtensionsFromNSIS` after obtaining the applicable `$Info`; each convenience reader invokes the parser again. Use a `Read-*FromNSIS` function only when one isolated field is needed and no `Get-NSISInfo` result already exists.

Treat explicit uninstall registry writes as authoritative. Use `DisplayVersion`, `DisplayName`, `Publisher`, `DefaultInstallLocation`, `UninstallString`, `QuietUninstallString`, `DisplayIcon`, `SystemComponent`, and the uninstall key represented by `ProductCode`. When `AppsAndFeaturesEntries` contains multiple identities, route through the localized ARP manifest shape and author the corresponding locale values instead of discarding non-primary languages or copying every identity into the installer manifest. Do not infer a version from arbitrary strings when `DisplayVersion` is absent. Review every parser warning before continuing; unresolved values must remain unresolved until another static source or VM evidence supplies them.

For the standard Tauri NSIS template, `IsTauri` requires the compiled `nsis_tauri_utils.dll`, `MainBinaryName`, and placeholder-install-directory markers together. `TauriInstallerMode` distinguishes `currentUser`, `perMachine`, and `both` from the compiled ARP scope, MultiUser setters, and PE requested execution level. In `both` mode, pass `-Scope user` and `-Scope machine`; NSIS 3 `GetKnownFolderPath` resolves the per-user root to `%LocalAppData%\Programs\<Product>`. A custom Tauri template may not retain this evidence and must be analyzed as ordinary NSIS rather than inferred from its product name.

Continue to [visible ARP ownership](#identify-the-visible-arp-owner). Do not call the switch or electron-builder helpers unless the later analysis requires them.

## Identify the visible ARP owner

Some NSIS installers are only wrappers around another installer. In those cases, the outer NSIS executable may not write the visible Apps & Features entry; the nested MSI/WiX/custom EXE does.

Inspect these `$Info` properties together:

- `ExtractedFiles` for embedded `.msi`, `.msp`, `.msu`, or setup `.exe` payloads.
- `ExecutedPayloads` for `Exec`, `ExecWait`, or `ShellExec` commands that launch extracted setup files.
- `WritesAppsAndFeaturesEntry` to determine whether the simulated outer NSIS path writes a visible uninstall entry. A `SystemComponent=1` write is hidden and does not count as visible ARP ownership.
- `RegistryWrites` to confirm the uninstall root, key, and values rather than relying only on filenames.
- `AppsAndFeaturesEntries` and `AppsAndFeaturesEntryEvidence` to map distinct localized `DisplayName`/`Publisher` values from every compiled NSIS language table to locale manifests.

Route according to the combined evidence:

- `IsPortable` is true: the compiled electron-builder portable template sets all three `PORTABLE_EXECUTABLE_*` environment variables, executes the unpacked application from a temporary directory, and writes no visible ARP entry. Do not author it as `InstallerType: nullsoft`; route it to the portable manifest workflow and retain the parser warning as evidence. `DefaultInstallLocation` is intentionally null because the observed directory is transient.
- Outer NSIS writes the visible entry and no nested payload supersedes it: retain the direct-installer manifest shape and continue to [metadata and association projection](#record-metadata-and-registry-associations).
- Outer NSIS writes an entry and also launches a nested installer: inspect both entries. Model the entry that remains visible and matches the installed application; use the canonical [VM validation workflow](../../workflows/vm-validation.md) if ownership cannot be proven statically.
- Outer NSIS does not write a visible entry and launches a nested MSI/WiX: extract or otherwise obtain that payload, call `$MsiInfo = Get-MsiInstallerInfo -Path $NestedMsi`, and use the nested MSI/WiX manifest shape only when `$MsiInfo.AppsAndFeaturesInstallerType` and `$MsiInfo.HidesMsiAppsAndFeaturesEntry` prove its visible ARP behavior.
- Outer NSIS does not write a visible entry and launches a custom EXE: route the payload to its focused installer parser. Do not label the ARP entry as MSI/WiX without MSI evidence.
- No component can be proven to write a visible entry: use the canonical [VM validation workflow](../../workflows/vm-validation.md) for ARP-delta validation.

Use `Expand-NSISInstaller` when the payload is embedded in a compiled `File` command. Select the narrowest useful wildcard instead of expanding the complete application:

```powershell
$NestedMsi = Expand-NSISInstaller -Path $InstallerFile -Name '*.msi' -MaximumExpandedBytes 1GB -CollisionAction Rename
$MsiInfo = Get-MsiInstallerInfo -Path $NestedMsi[0]
```

Omit `-Name` only when a complete bounded payload expansion is required. `-CollisionAction Prompt|Error|Skip|Overwrite|Rename` controls duplicate or existing outputs. Interactive calls default to `Prompt`; functions and unattended automation must pass `Rename` for deterministic suffix renaming.

The GPL parser reads the source-backed data offset from `EW_EXTRACTFILE`, seeks directly to non-solid records, and advances one bounded decoder through solid records. It supports stored, LZMA/LZMA2, BZip2, zlib, raw DEFLATE, x86-BCJ-filtered LZMA, and NSISBI MTW payload streams without `7z.exe`. Output paths follow the compiled `SetOutPath` sequence similarly to 7-Zip/NanaZip: the virtual `$INSTDIR\` root is removed, while roots such as `$PLUGINSDIR`, `$SYSDIR`, `$R1`, and compiler-private `$_17_` variables remain as literal directories. This preserves architecture- and branch-specific layouts without resolving paths against the host. The extractor includes compiled `File` payloads only; it does not generate `[NSIS].nsi`, license artifacts, or patched uninstallers.

Every reconstructed path is projected below the selected destination. Unsafe absolute paths and traversal components cannot escape that directory, aliases count toward `MaximumExpandedBytes`, and partial files are removed on failure. `CollisionAction` retains Dumplings' normal behavior when distinct records still resolve to the same reconstructed path. An NSISBI archive that declares an external payload sidecar is rejected because an embedded-only result would be incomplete; obtain and analyze the sidecar explicitly.

Existing manifests with `InstallerType: nullsoft` and `AppsAndFeaturesEntries.InstallerType: msi` or `wix` are useful leads, but are not evidence for a new installer version by themselves.

Known wrapper examples:

- `Blueberry.FlashbackExpress.6`: NSIS wrapper with nested WiX/MSI ARP behavior.
- `Apache.OpenOffice`: NSIS wrapper with nested MSI behavior.
- `Mozilla.*`: wrapper installers can differ from MSI packages distributed by Mozilla; model the manifest installer and verify the visible ARP entry.

## Record metadata and registry associations

Build the manifest evidence from the retained `$Info` object:

- `DisplayVersion` supplies the installed version only when explicitly written to the uninstall registry.
- `DisplayName` and `Publisher` supply visible ARP identity.
- `ProductCode` is the NSIS uninstall registry key name, not an MSI product code unless [visible ARP analysis](#identify-the-visible-arp-owner) proved that a nested MSI owns the entry.
- `DefaultInstallLocation`, `UninstallString`, `QuietUninstallString`, and `DisplayIcon` are supporting ARP evidence.
- `RegistryAssociationInfo`, `Protocols`, and `FileExtensions` contain literal protocol and extension writes recovered during the same parse. Do not call `Read-ProtocolsFromNSIS` or `Read-FileExtensionsFromNSIS` after `$Info` already exists.

Some applications register protocols or extensions only on first run. An empty static result means the installer did not prove the association; it does not prove that the installed application never creates one. Use the canonical [VM validation workflow](../../workflows/vm-validation.md) when first-run association evidence matters.

## Build Apps & Features and installer fields

Choose the manifest shape using the earlier route results:

- Direct visible NSIS ARP, one scope: use the first manifest shape.
- Direct visible NSIS ARP, two explicitly selectable scopes: use the dual-scope shape.
- Nested visible MSI/WiX ARP: use the nested MSI/WiX shape and include `UpgradeCode`.
- Nested custom EXE ARP: keep outer `InstallerType: nullsoft`, but add only the visible ARP overrides proved for the nested EXE.

Apply these field rules:

- Recheck `InstallModes` and every `InstallerSwitches` child against the WinGet defaults. Remove equal values; explicitly retain complete non-default overrides.
- Keep `ProductCode` at installer level; do not duplicate it in `AppsAndFeaturesEntries.ProductCode`.
- Put localized ARP names and publishers in their corresponding locale manifests. Keep them in `AppsAndFeaturesEntries` only when that locale manifest does not exist.
- Add `AppsAndFeaturesEntries` only for a meaningful visible-ARP mismatch, including nested installer type, publisher, package name, or display version.
- Add `InstallerType: msi` or `wix` inside the entry only when the visible ARP entry has that effective type.
- Include `UpgradeCode` whenever the outer or Apps & Features installer type is `msi`, `wix`, or `burn`.
- Do not retain a version-bearing `DisplayName` override when WinGet normalization removes only the version and the remaining name matches `PackageName`.
- Preserve separate installer entries for scope-specific switches; do not move a scope-specific `Custom` switch to manifest root.

## Escalate unresolved behavior to VM validation

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
