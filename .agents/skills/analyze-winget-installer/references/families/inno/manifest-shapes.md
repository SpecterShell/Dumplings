# Inno manifest shapes

[Back to the Inno workflow](workflow.md)

## Direct installer

Use this shape when [visible ARP analysis](analysis.md#identify-the-visible-arp-owner) proves that the outer Inno installer writes the visible entry, [scope analysis](scope-and-silent.md#scope) finds one supported scope, and no Apps & Features override is required. `$Info.ProductCode` is the source-derived built-in uninstall key, including Inno's `_is1` suffix. `$Info.AppId` remains available as the distinct application identity.

```yaml
Installers:
- Architecture: x64
  InstallerType: inno
  InstallerUrl: https://example.com/Product-1.2.3-x64.exe
  InstallerSha256: <SHA256>
  ProductCode: <VisibleInnoUninstallKey>
```

Apply the WinGet defaults below. Do not copy default `InstallModes` or `InstallerSwitches` into this minimal shape.

## Dual scope

Use this shape only when `$Info.SupportsCommandLineScopeOverride` and `$Info.SupportsDualScope` are true. Inno enables `/CURRENTUSER` and `/ALLUSERS` only when `PrivilegesRequiredOverridesAllowed` includes `commandline`; `dialog` alone exposes an interactive wizard choice that WinGet cannot select reliably.

```yaml
Installers:
- Architecture: x64
  InstallerType: inno
  Scope: user
  InstallerUrl: https://example.com/Product-1.2.3-x64.exe
  InstallerSha256: <SHA256>
  InstallerSwitches:
    Custom: /CURRENTUSER
  ProductCode: <VisibleInnoUninstallKey>
- Architecture: x64
  InstallerType: inno
  Scope: machine
  InstallerUrl: https://example.com/Product-1.2.3-x64.exe
  InstallerSha256: <SHA256>
  InstallerSwitches:
    Custom: /ALLUSERS
  ProductCode: <VisibleInnoUninstallKey>
```

The scope switches are non-default and must remain on their respective installer entries. Preserve their supported casing. Do not use this shape for privilege-sensitive installers that change scope only according to elevation or UAC behavior.

## Nested MSI/WiX ARP owner

Use this shape when `$Info.WritesAppsAndFeaturesEntry` is false and [visible ARP analysis](analysis.md#identify-the-visible-arp-owner) proves that an extracted MSI/WiX payload owns the visible entry. Use `Expand-InnoInstaller` only to obtain the required payload, then parse that MSI once with `Get-MsiInstallerInfo`.

```yaml
Installers:
- Architecture: x64
  InstallerType: inno
  InstallerUrl: https://example.com/Product-1.2.3-x64.exe
  InstallerSha256: <SHA256>
  ProductCode: <VISIBLE-MSI-PRODUCT-CODE>
  AppsAndFeaturesEntries:
  - UpgradeCode: <VISIBLE-MSI-UPGRADE-CODE>
    InstallerType: wix
```

Use `InstallerType: msi` in the Apps & Features entry when the nested package is not WiX-authored. Do not use nested MSI metadata when that MSI entry is hidden and a custom EXE entry is visible.
