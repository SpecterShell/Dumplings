# MicaSetup uninstaller and ARP

## Built-in registration gate

The v2 runtime writes its built-in uninstall entry only when `IsCreateRegistryKeys` is enabled and the running process is elevated. A resolved `KeyName` alone does not prove ProductCode.

```text
installation route
+-- elevated && IsCreateRegistryKeys && KeyName is resolved
|   `-- HKLM\Software\Microsoft\Windows\CurrentVersion\Uninstall\<KeyName>
|       +-- DisplayName, DisplayVersion, Publisher
|       +-- DisplayIcon, InstallLocation, UninstallString
|       +-- NoModify=1, NoRepair=1
|       `-- SystemComponent=0|1
`-- otherwise
    `-- <InstallLocation>\Uninst.dat
```

The user route writes `Uninst.dat` rather than a Windows uninstall key. It must not receive installer-level ProductCode or Apps & Features entries from `KeyName`.

## Registry view and visibility

`IsUseRegistryPreferX86=true` selects `Registry32`; false selects `Registry64`; null uses the process-default view. `SystemComponent=1` keeps the physical HKLM key but hides it from the visible Apps & Features set. The parser retains the registry writes and system-component evidence but does not expose a visible match entry.

A visible built-in entry therefore requires machine scope, enabled registry creation, a resolved non-empty `KeyName`, and `SystemComponent=0`. `WritesAppsAndFeaturesEntry`, `ProductCode`, `AppsAndFeaturesProductCode`, and `AppsAndFeaturesEntries` follow that gate.

## Values and commands

`DisplayName`, `DisplayVersion`, `Publisher`, and optional `DisplayIcon` come from generated options. `InstallLocation` is the resolved configured root. The uninstaller is `Uninst.exe` by default; modern v2 can select lowercase `uninst.exe` with `IsUninstLower`. `UninstallString` is emitted only when uninstaller creation and a deterministic location are both proven. The parser does not fabricate `QuietUninstallString`.

`IsCreateUninst=false` can leave other installation behavior intact. The absence of a generated uninstaller is returned separately from ARP visibility so authoring can detect a dangling or unusable uninstall entry if custom code registers one.

## Custom registration

Literal static `Registry.SetValue` calls are independent of the built-in gate. They may create associations or custom uninstall rows. The parser preserves these writes and lets the shared registry interpreter identify complete literal records. Instance `RegistryKey` flows and helper methods remain unresolved because their root, view, key lifetime, and conditional execution are not recoverable from a single call site.

When built-in and custom rows coexist, treat each physical uninstall key as separate evidence. Do not replace the built-in key with assembly GUIDs, application mutex names, payload product names, or first-run registration.
