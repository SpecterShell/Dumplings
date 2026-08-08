# MSI and WiX manifest shapes

[Back to the MSI and WiX workflow](workflow.md)

## Direct installer

Use this shape when [builder classification](analysis.md#classify-the-msi-builder) reports a non-WiX or unknown builder, [visible ARP analysis](analysis.md#identify-the-visible-arp-entry) proves that the native MSI entry is visible, and the manifest identity agrees with the MSI metadata. Obtain `ProductCode` from `Get-MsiInstallerInfo.ProductCode`. Do not add `AppsAndFeaturesEntries` merely to repeat the MSI identity.

```yaml
Installers:
- Architecture: x64
  InstallerType: msi
  InstallerUrl: https://example.com/Product-1.2.3-x64.msi
  InstallerSha256: <SHA256>
  ProductCode: <ProductCode>
```

Apply the WinGet defaults below. Add `Scope`, an install-location override, or Apps & Features metadata only when the later steps prove that it is required.

## WiX MSI package

Use this shape when `$Info.InstallerBuilder` is `WiX`. If only a Boolean classification is needed, `Test-WiXInstaller` can inspect WiX summary strings, table names, properties, and custom-action markers; do not call it after `$Info` already supplies the same classification. Use [install-location analysis](analysis.md#determine-install-location-switches-and-modes) to obtain the actual public install-directory property rather than assuming `INSTALLDIR`.

```yaml
Installers:
- Architecture: x64
  InstallerType: wix
  InstallerUrl: https://example.com/Product-1.2.3-x64.msi
  InstallerSha256: <SHA256>
  ProductCode: <ProductCode>
```

WiX MSIs use properties including `INSTALLDIR`, `INSTALLLOCATION`, `APPLICATIONROOTDIRECTORY`, `INSTALL_ROOT`, and package-specific all-uppercase names. If `WIXUI_INSTALLDIR` exists, use it only when the referenced directory is actually connected to installed components; the parser performs this table check because the property can remain in a package with no usable location UI.

## Advanced Installer MSI package

Use this shape when `$Info.InstallerBuilder` is `AdvancedInstaller` and `$Info.AppsAndFeaturesInstallerType` reports the native MSI entry. Advanced Installer commonly uses `APPDIR`, but retain the shown override only when `$Info.InstallLocationSwitch` returns it. The builder classification does not by itself prove the visible ARP type.

```yaml
Installers:
- Architecture: x64
  InstallerType: msi # Advanced Installer
  InstallerUrl: https://example.com/Product-1.2.3-x64.msi
  InstallerSha256: <SHA256>
  InstallerSwitches:
    InstallLocation: APPDIR="<INSTALLPATH>"
  ProductCode: <ProductCode>
```

Keep the comment only when it explains useful generator-specific behavior. Remove `InstallerSwitches.InstallLocation` if the package instead uses WinGet's default `TARGETDIR="<INSTALLPATH>"`, and omit `AppsAndFeaturesEntries` when the native MSI ARP identity agrees with the manifest.

## Advanced Installer MSI with EXE ARP

Use this shape when `$Info.InstallerBuilder` is `AdvancedInstaller`, `$Info.HidesMsiAppsAndFeaturesEntry` is true, and `$Info.AppsAndFeaturesInstallerType` is `exe`. Advanced Installer can hide the native MSI entry through `ARPSYSTEMCOMPONENT=1` or `SystemComponent=1` and author a separate non-GUID uninstall key such as `[ProductName] [ProductVersion]`. Use `$Info.AppsAndFeaturesProductCode` for the visible key rather than the hidden MSI `ProductCode`.

```yaml
Installers:
- Architecture: x64
  InstallerType: msi # Advanced Installer
  InstallerUrl: https://example.com/Product-1.2.3-x64.msi
  InstallerSha256: <SHA256>
  InstallerSwitches:
    InstallLocation: APPDIR="<INSTALLPATH>"
  ProductCode: <CustomARPProductCode>
  AppsAndFeaturesEntries:
  - InstallerType: exe
```

The Apps & Features entry exists because the visible ARP type differs from the outer MSI type. Don't include `UpgradeCode` because the installer type in the visible ARP is not MSI, and do not duplicate `ProductCode` inside the entry. Known example: `IPEVO.Vurbo-ai`.

## InstallShield MSI package

Use this shape when `$Info.InstallerBuilder` is `InstallShield`. InstallShield-authored MSIs commonly use `INSTALLDIR`, but WiX and other builders can use the same property, so require static `IS*` tables, `InstallShield*` properties, or `IS*` custom actions before applying this classification.

```yaml
Installers:
- Architecture: x64
  InstallerType: msi # InstallShield
  InstallerUrl: https://example.com/Product-1.2.3-x64.msi
  InstallerSha256: <SHA256>
  InstallerSwitches:
    InstallLocation: INSTALLDIR="<INSTALLPATH>"
  ProductCode: <ProductCode>
```

Retain the location override only when `$Info.InstallLocationSwitch` returns it. Omit `AppsAndFeaturesEntries` when the native MSI entry is visible and agrees with the manifest. `Housatonic.ProjectViewer365` is a current static-parser example. EXE-wrapped InstallShield packages route to the [InstallShield workflow](../installshield/workflow.md) first.

## Hidden MSI with `.msq` EXE ARP

Use this shape when `$Info.HasMsqAppsAndFeaturesEntry` and `$Info.HidesMsiAppsAndFeaturesEntry` are both true. These packages hide the native `{ProductCode}` entry and write a visible `{ProductCode}.msq` uninstall key. Use `$Info.AppsAndFeaturesProductCode`; do not append `.msq` manually. Inspect `$Info.AppsAndFeaturesEntries.MsqAppsAndFeaturesRegistryRows` and confirm that the visible entry does not set `WindowsInstaller=1` before classifying it as `exe`.

```yaml
Installers:
- Architecture: x64
  InstallerType: wix
  InstallerUrl: https://example.com/Product-1.2.3-x64.msi
  InstallerSha256: <SHA256>
  ProductCode: '{MSI-PRODUCT-CODE}.msq'
  AppsAndFeaturesEntries:
  - InstallerType: exe
```

Choose the outer `InstallerType` from the MSI builder; the example uses `wix` because Figma's machine installer is WiX-authored. The visible entry is EXE-style because WinGet classifies ARP entries by `WindowsInstaller`, not by the database that created the registry key. Don't include `UpgradeCode` because the installer type in the visible ARP is not MSI, and do not duplicate `ProductCode` inside the entry. Known `.msq` examples include `Figma.Figma`, `Dizzion.Frame`, `MuteMe.MuteMe`, and `Tulip.TulipPlayer`.

Velopack-generated MSIs use the same custom-entry pattern with a visible `MSI:<PackageId>` key. For example, the Tower MSI hides its GUID-based native entry with `ARPSYSTEMCOMPONENT=1` and explicitly writes `Software\Microsoft\Windows\CurrentVersion\Uninstall\MSI:Tower` without `WindowsInstaller=1`. The MSI artifact therefore has a native `{GUID}` product code, while the visible WinGet-matchable entry is EXE-style with installer-level `ProductCode: MSI:Tower`; do not strip the prefix or reuse the Velopack EXE key `Tower` for the MSI entry.
