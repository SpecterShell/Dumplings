# Zero Install uninstaller and ARP behavior

## Registration boundary

Application desktop integration begins writing an Apps & Features row in runtime 2.21.0. A bound bootstrapper that only runs the target does not write this row. Generic runtime launchers do not have a target ProductCode.

User integration writes HKCU. Machine integration writes HKLM. The uninstall subkey is the `FeedUri.PrettyEscape` form of the canonical target feed URI.

## ARP value history

| Value | Behavior |
| --- | --- |
| `DisplayName` | feed name plus ` (Zero Install)` before 2.23.3; plain feed name afterward |
| `Publisher` | feed publisher from 2.24.0 |
| `URLInfoAbout` | feed homepage |
| `DisplayVersion` | absent or deleted by built-in integration |
| `UninstallString` | deployed `0install-win.exe remove <feed-uri> [--machine]` |
| `QuietUninstallString` | uninstall command plus `--batch --background` |
| `ModifyPath` | deployed `0install-win.exe integrate <feed-uri> [--machine]` from 2.25.12 |
| `NoModify` | 1 before 2.25.12, then 0 |
| `NoRepair` | 1 |

The executable path depends on deployed runtime `InstallBase`. The parser returns executable and argument evidence separately instead of manufacturing a quoted absolute command.

## ProductCode rules

`ProductCode` is emitted only when all of these are true:

- The bootstrapper has an absolute target `app_uri`.
- The compiled mode requests desktop integration.
- The runtime generation supports application ARP registration.

When integration or runtime support is absent, `UninstallKeyNameCandidate` can still show the deterministic escaped URI, but it is not promoted to ProductCode.

## Associations

Desktop integration can register protocols and file types from feed capabilities. Final association evidence also depends on compiled integration categories. The parser returns deterministic selections as `Protocols` and `FileExtensions`, and keeps the complete compatible feed set as available evidence when selection is interactive.

## Manifest matching

Do not put a feed implementation version into `AppsAndFeaturesEntries.DisplayVersion`; the built-in ARP row does not write one. A target application can later write or modify ARP state, so VM comparison remains necessary when the package has first-run registration behavior.

