# Wise uninstaller and ARP

## Two ownership models

Wise packages can write a custom uninstall row through WiseScript registry actions or delegate registration to Windows Installer. The parser reports these models separately.

For `WiseSection/Msi` and structurally validated nested-MSI routes, MSI `ProductCode`, `UpgradeCode`, product properties, and Windows Installer ARP behavior are authoritative. The visible entry normally has `InstallerType: msi` even though WinGet downloads an EXE wrapper.

For pure WiseScript media, the script can write values below `Software\Microsoft\Windows\CurrentVersion\Uninstall`. The suffix of that literal key is a candidate EXE ProductCode. The parser returns such rows in `AppsAndFeaturesEvidence` but does not promote them to `ProductCode` or `AppsAndFeaturesEntries` until control-flow or VM evidence proves that the row is written.

## Registry root decoding

The low five bits of a projected Wise registry root field select the hive. Dumplings currently recognizes `1` as HKCU and `2` as HKLM for uninstall evidence. Records with the deletion flag `0x40` are excluded. Other roots are preserved in the general `RegistryWrites` evidence but cannot own a conventional WinGet ARP row.

The parser groups literal values by root and key. It projects `DisplayName`, `DisplayVersion`, `Publisher`, `InstallLocation`, `UninstallString`, `QuietUninstallString`, `DisplayIcon`, and `SystemComponent` without normalizing their text. Unknown values remain in the row's `Values` dictionary.

## Visibility

An uninstall key can be hidden by `SystemComponent=1`, omitted by a condition, overwritten by another state, or removed during rollback. Static presence of registry states does not establish a visible final row. MSI metadata is stronger because Windows Installer owns registration through the validated product database, although custom actions can still alter visibility and require VM validation.

## ProductCode rules

Use the MSI ProductCode for MSI-owned registration. Do not use a Wise temporary Run key, resume token, log filename, generated uninstaller path, or launcher identifier as ProductCode.

For custom WiseScript rows, use the exact literal uninstall-key suffix only after the active path is proven. If multiple literal keys exist, return all candidates and leave the scalar ProductCode unresolved. If exactly one exists but branch conditions are not interpreted, retain it as candidate evidence and emit `Wise.Metadata.ScriptArpConditionsRequireValidation`.

## VM comparison

Follow the shared installed-state workflow and compare at least HKLM 64-bit, HKLM 32-bit, and HKCU. Record `WindowsInstaller`, `SystemComponent`, uninstall commands, install location, display icon, and value kinds. Compare the observed row to the exact parser tuple rather than accepting a matching display name alone.
