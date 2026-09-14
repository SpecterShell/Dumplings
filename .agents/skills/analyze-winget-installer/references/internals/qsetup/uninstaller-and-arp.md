# QSetup uninstaller and ARP

## Built-in registration

Visible built-in registration requires enabled `SET_CREATE_UNINSTALL` and `SET_ADD_UNINSTALL_TO_ADD_REMOVE_PROGRAMS`. The uninstall key and `DisplayName` use `SET_ADD_REMOVE_PROGRAMS_DISPLAY_NAME`, falling back to `SET_PROG_NAME`. Display version, publisher, install location, icon, support URL, and update URL come from their corresponding literal directives.

```text
HKLM or HKCU\Software\Microsoft\Windows\CurrentVersion\Uninstall\<DisplayName>
+-- DisplayName
+-- DisplayVersion
+-- Publisher
+-- InstallLocation
+-- DisplayIcon
`-- UninstallString
```

An explicit machine route projects HKLM and an explicit user route projects HKCU. QSetup's 64-bit setup state selects the 64-bit registry view even when the native launcher is I386. Ordinary I386 state selects the 32-bit view.

## ProductCode ownership

The EXE ProductCode is the actual visible uninstall-key name. Use it only when registration is proven. A Composer build number, payload filename, nested MSI code, PE product name, or shortcut name cannot substitute for the key.

Literal custom uninstall writes take precedence over the built-in row. Multiple visible custom keys remain separate `AppsAndFeaturesEntries` and leave installer-level ProductCode unresolved. `SystemComponent=1` rows remain in `CustomArpEntries` and `RegistryWrites` but are excluded from visible matching.

## Uninstaller name resolution

The parser resolves the generated uninstaller in this order:

1. Literal `SET_UNINSTALL_EXE_NAME`.
2. Exact compiled shortcut target tied to `SET_PROG_STAMP`.
3. A formula verified for the structural generation.

The verified historical formula is `UnInstall_<stamp>.exe` through QSetup 7. The verified current formula is `<media>_<stamp>.exe` for QSetup 12. QSetup 8 through 11 remain unresolved when both explicit routes are absent. Archived 8.1, 9.1, 10.0, and 11.0 builder installers all use explicit names and therefore do not prove the blank-name formula.

`Uninstaller.NamingRoute` records the selected evidence. An unresolved generated name prevents the parser from fabricating `UninstallString`; it does not invalidate unrelated metadata.

## Command quoting

The resolved executable path is quoted when required. A controlled QSetup 12 install confirms the registry stores the expected quoted install location and uninstall command for the generated media-name route. Custom arguments and quiet-uninstall behavior require explicit directive or VM evidence.

## Ownership conflicts

A nested MSI or EXE can write another visible row. Review `ExecutedPayloads`, custom uninstall writes, and VM snapshots before deciding which row represents the package. Preserve distinct rows when both outer bootstrapper and nested application registrations are visible.
