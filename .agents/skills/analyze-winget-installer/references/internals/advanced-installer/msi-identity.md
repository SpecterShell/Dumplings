# MSI identity and ARP

## Builder evidence

Advanced Installer-authored MSIs often retain `AI_*` tables, properties, or custom actions. These structures classify the builder. Summary Information can also record a precise value such as `Advanced Installer 10.3` in `CreatingApp`.

The parser reports `InstallerBuilderVersion` only for an explicit Advanced Installer version in `CreatingApp`. It does not use `ProductVersion`, package filenames, outer PE resources, or arbitrary string-table matches.

## Package identity

`ProductCode` identifies one MSI product package. `UpgradeCode` groups related products. `PackageCode` identifies a particular MSI database build and is not a WinGet ProductCode. Architecture variants can have different ProductCodes while sharing an UpgradeCode.

## Visible ARP ownership

The native MSI registration normally writes an entry keyed by ProductCode with `WindowsInstaller=1`. Advanced Installer projects can set `ARPSYSTEMCOMPONENT=1` and write another uninstall key through the Registry table. That custom key can have a non-GUID ProductCode and is classified as EXE-style when `WindowsInstaller` is absent or not `1`.

```text
MSI transaction
+-- native ProductCode entry
|   `-- possibly hidden by ARPSYSTEMCOMPONENT/SystemComponent
`-- optional custom Registry-table uninstall key
    +-- DisplayName
    +-- DisplayVersion
    +-- Publisher
    +-- UninstallString
    `-- WindowsInstaller, usually absent for EXE-style ARP
```

The outer EXE does not prove which entry is visible. Parse the selected MSI and compare registry rows. Use VM deltas when custom actions or downloaded packages can alter registration.

## Install location

Advanced Installer commonly uses `APPDIR`, but the parser resolves a public directory property only when MSI Directory and component evidence show that it is connected to installed files. Use the returned switch instead of assuming `APPDIR` for every package.
