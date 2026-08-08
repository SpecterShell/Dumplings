# MSI ARP and scope internals

[Back to MSI and WiX parser internals](overview.md).

## Binary structure

ARP behavior is authored through MSI database properties, registry rows, and standard Windows Installer registration. Installed scope evidence also appears in Windows Installer UserData keys outside the MSI file.

## Parsing behavior

Inspect `ProductCode`, `UpgradeCode`, `ALLUSERS`, `MSIINSTALLPERUSER`, elevation properties, registry rows, and relevant launch conditions. Identify custom ARP rows that set `SystemComponent=1` on the native MSI entry and expose another uninstall key.

## Metadata projection

WinGet treats an ARP entry as MSI only when its `WindowsInstaller` value is `1`. Keep native MSI and custom EXE-style entries separate. Determine user versus machine installation from authored properties, conditions, and UserData ownership rather than the ARP hive alone.

## Limits and gaps

Static MSI properties can be conditional or overridden at runtime. Preserve unresolved scope and visibility evidence for VM validation. Read [scope and elevation](../../families/msi-wix/scope-and-elevation.md) for manifest decisions.
