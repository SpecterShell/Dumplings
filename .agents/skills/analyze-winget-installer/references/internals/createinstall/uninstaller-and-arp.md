# CreateInstall uninstaller and ARP

## Built-in Add/Remove profiles

The Add/Remove implementation is a linked Gentee routine selected by structure rather than PE version. Its source-defined value names and argument count provide a stable fingerprint.

| Profile | Observed builders | Call and emitted values |
| --- | --- | --- |
| `Legacy3` | 5.9.0 through 6.3.3 | `addremove`; key name, icon path, icon file; no `InstallLocation`, `NoModify`, `NoRepair`, or `EstimatedSize` |
| `Scoped4` | 6.4.0 through 7.0.19 | `addremoveex`; adds current-user selection and `InstallLocation` |
| `Policy4` | 7.0.26 through 7.1.3 | `addremoveex`; adds `NoModify` and `NoRepair` |
| `Extended5` | 7.1.7 through 8.11.2 | `addremoveext`; adds the estimated-size argument |

Dead-code elimination removes the whole family when Add/Remove Programs support is disabled. Absence of a built-in call is a valid program state, not a parse failure. Custom registry operations may still create an uninstall key.

## Registry reconstruction

The parser creates built-in writes using the exact routine arguments and resolved `MAINVAR` values, then appends deterministic custom `regsetsex` writes in execution order. Writes are grouped by root, registry view, and full uninstall key. Within a group, the final write for a value name wins.

```text
Software\Microsoft\Windows\CurrentVersion\Uninstall\<leaf>
+-- DisplayName
+-- DisplayVersion
+-- Publisher
+-- UninstallString
+-- DisplayIcon
+-- optional InstallLocation
+-- optional NoModify / NoRepair
`-- optional EstimatedSize
```

The key leaf becomes `ProductCode` only when exactly one deterministic visible entry remains. Multiple visible keys produce ambiguous evidence. Zero visible keys produce no ProductCode. A key is hidden when `SystemComponent` is nonzero, and a key without a nonempty `DisplayName` is not a visible Apps & Features record.

## Scope and view

HKCU maps to user scope and HKLM maps to machine scope. `SHCTX` represents runtime-selected context and therefore contributes both supported scopes while withholding a single `Scope`. The registry view follows the x86 or x64 setup runtime for built-in operations; custom registry calls retain their explicit view selector.

ProductCode identity does not imply one scope. The same key leaf may be written under HKCU or HKLM depending on runtime context. A manifest that splits scope entries must validate both installed states rather than duplicating a single observed ARP row.

`addremoveex` and `addremoveext` choose the `InstallLocation` value exactly as the shipped source does. The existence of `instlocation` is a route flag; that branch writes macro `instlocal`. Otherwise the routine writes `setuppath`. Reading `instlocation` itself as the path changes runtime semantics and can produce an ARP value the installer never writes.

## Uninstall command and icon

`MAINVAR.uninstexe` supplies the generated uninstaller path. The built-in route quotes a resolved path unless it is already quoted. The parser returns that exact quoted `UninstallString`. It does not fabricate a quiet uninstall command because the setup's `silentpar` does not by itself prove generated-uninstaller switch behavior.

The Add/Remove call can supply an icon path and filename. If it does not, the runtime uses the uninstaller path. Unknown language or runtime macros leave `DisplayIcon` unresolved instead of writing a host-expanded path.

## Estimated size

`Extended5` accepts a compiled text argument. A value of `1` tells the runtime to derive kibibytes from the GEA archive summary. Another positive decimal value is written as a literal kibibyte count. Empty or zero writes no value. Balabolka compiles `56327`; a controlled sub-kibibyte project produced no `EstimatedSize` after integer rounding.

## Installed-state witness

A controlled Extended5 install was compared value-for-value with the parser. The VM wrote one 32-bit-view HKLM key with quoted `UninstallString`, `DisplayName`, `DisplayIcon`, `DisplayVersion`, `InstallLocation`, `Publisher`, `NoModify`, and `NoRepair`. The generated `uninstall.ini` independently listed the same registry operations, and the generated uninstaller parsed as a no-GEA CreateInstall program.

This witness validates the route and value construction for that generation. Conditional custom writes, localized runtime strings, external DLLs, user-scope selection, and multiple uninstall keys still require artifact-specific installed-state comparison.

## WinGet projection

Use `ProductCode` only when the parser proves one visible key. `AppsAndFeaturesEntries` may carry identity fields for review, but normal manifest optimization removes values redundant with installer-level ProductCode and default-locale identity. Hidden records remain in `ArpEntries` and must not be projected as visible matching rows.
