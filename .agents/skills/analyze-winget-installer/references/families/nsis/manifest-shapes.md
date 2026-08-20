# NSIS manifest shapes

[Back to the NSIS workflow](workflow.md)

## Direct installer

Use this shape when [visible ARP analysis](analysis.md#identify-the-visible-arp-owner) proves that the outer NSIS installer writes the visible entry, the installer has only one WinGet-selectable scope, and no Apps & Features override is required. Obtain `ProductCode` from `Get-NSISInfo.ProductCode`; it is the uninstall registry key name. Remove `ProductCode` if the parser cannot prove a stable key rather than deriving one from filenames or arbitrary strings. Use `Get-NSISInstallerSwitchInfo` and, for electron-builder packages, `Get-ElectronBuilderNSISInfo` before deciding that no additional fields are needed.

```yaml
Installers:
- Architecture: x64
  InstallerType: nullsoft
  InstallerUrl: https://example.com/Product-1.2.3-x64.exe
  InstallerSha256: <SHA256>
  ProductCode: <ProductCode>
```

Apply the WinGet defaults below. Do not copy default `InstallModes` or `InstallerSwitches` into this minimal shape.

## Localized ARP identities

Use this shape when `Get-NSISInfo.AppsAndFeaturesEntries` contains more than one distinct visible identity for the same uninstall key because `DisplayName` or `Publisher` is compiled from NSIS language strings. Keep the installer-level `ProductCode` once. Map each evidenced identity to `PackageName` and `Publisher` in its corresponding locale manifest, because WinGet indexes those localized values for ARP lookup. Do not select only the parser's scalar `DisplayName` and `Publisher`; those scalar properties intentionally remain the primary-language compatibility values.

```yaml
PackageIdentifier: Publisher.Product
PackageVersion: 1.2.3
PackageLocale: zh-CN
Publisher: 本地化发布者名称
PackageName: 本地化产品名称
ManifestType: locale
ManifestVersion: 1.12.0
```

Review `AppsAndFeaturesEntryEvidence` to correlate each value with its `LanguageId`, `Locale`, registry hive/key, scope, and visibility. `Diagnostics` explains when distinct localized identities were found. Confirm runtime language selection in the VM if the installed locale cannot be inferred statically. Retain a localized `DisplayName` or `Publisher` in `AppsAndFeaturesEntries` only when no corresponding locale manifest exists; `Optimize-WinGetManifest` otherwise removes values matched by any authored localization.

## Dual scope

Use this shape only when one installer binary has independently selectable user and machine modes through WinGet-usable command-line switches. Select this route through [silent behavior and scope](scope-and-silent.md#silent-behavior-and-scope) when `Get-ElectronBuilderNSISInfo.SupportedScopes` reports both scopes and the corresponding switches are present, or when ordinary NSIS control-flow and registry evidence proves explicit `/CurrentUser` and `/AllUsers` support. For compiled MultiUser scope setters, call `Get-NSISInfo -Scope user` and `Get-NSISInfo -Scope machine`; use each result's `ProductCode`, `DisplayName`, `Scope`, and `DefaultInstallLocation` only for the matching installer entry. `HasScopeRuntimeCheck` and `SupportedScopes` report the source-backed branch evidence. An untargeted `Get-NSISInfo.Scope` describes only the simulated default path and is not sufficient evidence for this shape.

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

## Nested MSI/WiX ARP owner

Use this shape when the invoked file is NSIS but [visible ARP analysis](analysis.md#identify-the-visible-arp-owner) proves that a nested MSI/WiX payload writes the visible Apps & Features entry. `Get-NSISInfo` supplies the wrapper evidence through `WritesAppsAndFeaturesEntry`, `ExtractedFiles`, and `ExecutedPayloads`. Parse an extracted MSI once with `Get-MsiInstallerInfo`; use its `ProductCode`, `UpgradeCode`, `AppsAndFeaturesInstallerType`, and `HidesMsiAppsAndFeaturesEntry` properties to establish the visible identity. If static ownership remains ambiguous, use before/after ARP collection in the VM instead of assuming this shape.

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
