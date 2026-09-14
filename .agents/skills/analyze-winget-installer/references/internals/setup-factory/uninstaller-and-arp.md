# Setup Factory uninstaller and ARP

## Setup Factory 3.1

The verified 3.1 media targets Windows 3.1 Program Manager. `IRDATA.DAT` identifies `IRUNIN31.EXE` as the uninstall runtime and records a program group, but it predates the Windows Add/Remove Programs registry contract. The parser returns no ProductCode, AppsAndFeaturesEntries, registry hive, or scope. It does not manufacture an ARP key from the product name or uninstaller filename.

## Setup Factory 4

Version 4 starts `irsetup.dat` with embedded `CGeneralData`, `CConclusionData`, and `CUninInfo` members. An enabled built-in uninstall route requires `IncludeUninstall`, a non-empty Control Panel description, and a non-empty unique registry key. That key is ProductCode evidence. A disabled object preserves authored text as configuration evidence but proves no ARP write.

The version 4 project format does not expose the later product version, company, or application-folder variables in the decoded global block. The parser therefore returns only fields established by `CUninInfo` or literal registry operations.

## Setup Factory 5 and 6

Versions 5 and 6 store product identity and built-in uninstall configuration in fixed project blocks. The uninstall block contains enablement, visibility text, unique key, generated uninstaller name, and supporting wizard text. ProductCode is the exact unique key only when the built-in route is enabled.

Literal `CRegistryData` records in version 5 and condition-resolved Modify Registry actions in version 6 can create additional uninstall entries. A custom entry is visible only when it has a non-empty `DisplayName` and `SystemComponent` is not 1. Custom entries are kept separate from the built-in identity.

## Setup Factory 7-10

Modern media exposes product variables and uninstall policy in `irsetup.dat`. The built-in route is accepted only when its key expression is the exact compiled `%ProductName%%ProductVer%` form supported by the runtime evidence. Literal Lua registry writes targeting `Software\\Microsoft\\Windows\\CurrentVersion\\Uninstall\\<key>` provide more precise ARP evidence and take precedence for the fields they establish.

Computed Lua arguments, conditional branches, external DLL results, and dynamically assembled paths remain unresolved. They can indicate that another ARP entry may exist but cannot replace a source-backed key.

## Hives, views, and visibility

HKCU and HKLM entries remain separate evidence. If visible entries occur in more than one hive, the parser does not collapse them into one scope or ProductCode. The registry view follows the decoded action and runtime profile where available. A PE execution level alone does not prove the uninstall hive.

The common visible-row rule is:

```text
visible = DisplayName is non-empty AND SystemComponent != 1
```

Hidden rows remain installed-state evidence but are not emitted as visible AppsAndFeaturesEntries.

## Display values and commands

DisplayName, DisplayVersion, Publisher, DisplayIcon, InstallLocation, UninstallString, and QuietUninstallString are returned only when their compiled values resolve deterministically. Product metadata is not copied into an ARP row merely because it looks similar. Generated-uninstaller paths and quoting are retained as evidence; dynamic arguments or runtime-generated paths require VM validation.

## Associations

Registry writes outside the exact uninstall path remain registry or association evidence. They do not prove ProductCode or ARP visibility. The shared registry-association projector derives protocols and file extensions from literal, condition-resolved writes. A missing ProgID or computed command produces a structured diagnostic rather than a fabricated association.

## Validation

When package matching depends on ProductCode, scope, registry view, visibility, or uninstall-command quoting, compare the parser tuple against VM installed state. Restore a checkpoint only when the VM is not shared with another task, capture before and after snapshots, record the installer exit code separately, and inspect the exact registry values rather than normalized display text.
