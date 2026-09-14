# Paquet Builder uninstaller and ARP behavior

## ProductCode meaning

For a generic EXE package, `ProductCode` is the visible uninstall-key suffix. It is not the PE product name, a runtime DLL name, or an arbitrary GUID found in payload data. When an MSI owns installation, ProductCode is the MSI ProductCode and `AppsAndFeaturesInstallerType` is `msi`.

## Evidence routes

| Route | Accepted ARP identity |
| --- | --- |
| Classic 2.6 | One explicit uninstall registry record; none exists in the verified builder package |
| Cabinet 2.7 | Sole nested MSI for the verified wrapper route, or explicit script registry evidence |
| Legacy 2.8 | Sole nested MSI for the verified wrapper route, or explicit script registry evidence |
| Resource 2.9 | Script-selected MSI, one literal uninstall row, or one literal `UNINSTKEY` with `UNINSTALLINFO` |
| Split3 | One literal full uninstall-key path plus packaged uninstaller support |

The 2.9.1 fixture calls `PBExecMSI` for `Setup1.msi`; its ProductCode and UpgradeCode come from that MSI. The 2.9.5 and 2.9.6 fixtures write HKLM `Software\Microsoft\Windows\CurrentVersion\Uninstall\PaquetBuilderSetup89` and return `PaquetBuilderSetup89`.

## ARP values

When the selected uninstall row contains literal writes, the parser prefers its `DisplayName`, `DisplayVersion`, and `Publisher` over launcher version resources. `DisplayIcon` and `UninstallString` are resolved through deterministic variables such as `%DESTPATH%` and `%UNINSTFNAME%`. Unresolved dynamic values remain empty rather than being copied as invalid manifest paths.

`AppsAndFeaturesEntries` is emitted only when one source-backed ProductCode exists. A nested MSI entry carries MSI-owned display fields. A generic EXE entry carries the literal ARP tuple. The common WinGet optimizer may later remove redundant ProductCode, DisplayName, Publisher, or InstallerType values; the parser should still return the complete evidence.

## Visibility and registry view

HKCU and HKLM establish scope. The current parser does not assign a 32-bit or 64-bit registry view to GINFOS root code `4`, because the script record does not encode a proven view and the launcher architecture alone is insufficient. VM comparison is required when a manifest depends on WOW6432Node placement.

`pbremove.dat` or `UNINSTALLINFO` proves uninstaller support. It does not by itself prove that the ARP row is visible. A future fixture with `SystemComponent`, disabled ARP, or conditional registry writes must preserve that distinction.

## Unresolved cases

The complete Classic fixture has no uninstall row in its decoded registry catalog. The 2.7 non-MSI wrapper delegates to `setup.exe` and does not expose the child's ARP identity statically. The cached 3.0 and 3.2 launchers resolve `GDGSoftPB300` after their UPX/LZMA image is reconstructed and scanned through the ordinary native route. Dynamic or conditional uninstall-key construction still requires VM evidence.
