# Actual Installer uninstaller and ARP internals

## Built-in registration gate

Actual Installer writes its application GUID to an uninstall key only when both the uninstaller and Programs and Features visibility are enabled. This gate also controls whether an update installer can discover the installed product through the built-in route.

```text
Include Uninstaller = true
AND Show in Programs and Features = true
  |
  +-- create visible uninstall key
  +-- use Product GUID as key identity in supported generations
  `-- permit GUID-based update detection

otherwise
  `-- no built-in visible product registration
```

The parser evaluates `Uninstall` and `ShowAddRemove` or `ShowInAddRemovePrograms`. Visibility defaults to the uninstaller setting when the explicit visibility key is absent. If the gate is false, ProductCode and `AppsAndFeaturesEntries` remain empty even when a GUID string exists elsewhere in the configuration.

## ProductCode

Modern supported media stores a brace-delimited application GUID. The parser accepts only the canonical GUID form and returns it as ProductCode after the built-in visibility gate passes.

Cabinet4 media can enable Programs and Features without exposing a Product GUID. VM validation of the official 4.8 builder installer proves that this runtime uses literal `AppName` as the uninstall-key name and writes `AppName AppVersion` as `DisplayName`; the parser applies that route-specific rule. Cabinet3 still has no completed installed-state observation, so it emits `ActualInstaller.ARP.LegacyKeyUnresolved` rather than assuming the Cabinet4 behavior.

Custom registry records can create an uninstall key under another name. The parser groups literal root, view, and key identity, rejects hidden or incomplete groups, and projects a visible custom entry only when `DisplayName` is resolved. A single complete custom entry can supply ProductCode when no built-in Product GUID is active; multiple custom entries remain ambiguous.

## Hive and view

The ordinary built-in key is located below:

```text
HKCU\Software\Microsoft\Windows\CurrentVersion\Uninstall\<ProductGUID>
HKLM\Software\Microsoft\Windows\CurrentVersion\Uninstall\<ProductGUID>
```

User scope selects HKCU and machine scope selects HKLM. A 32-bit setup uses the 32-bit registry view on 64-bit Windows; a validated x64-compliant setup uses the 64-bit view. Dual-scope media has no unconditional single hive until the launch route selects one.

Custom HKCU/HKLM records are subject to the runtime's token and root-redirection behavior described in [setup runtime](setup-runtime.md). Literal configuration is therefore evidence of requested write semantics, while checkpointed installed state remains authoritative for an unusual elevation route.

## Built-in values

The current parser projects this static tuple where each source value is literal and its path resolves. Cabinet4 substitutes literal `AppName` for ProductCode and appends a literal `AppVersion` to DisplayName:

```text
ProductCode              Product GUID
DisplayName              AppName
DisplayVersion           literal AppVersion
Publisher                CompanyName or Publisher
InstallLocation          resolved installation directory
DisplayIcon              installation directory plus main executable
UninstallString          installation directory plus configured/default uninstaller
InstallerType            exe
```

The parser defaults the uninstaller filename to `Uninstall.exe` when uninstallation is enabled and no explicit name is present. It does not currently prove exact command quoting, arguments, or the silent suffix across every generation, so `QuietUninstallString` remains null.

`DisplayIcon` is derived only when both installation directory and main executable resolve. It is not guessed from the outer setup icon.

## VM-validated 5.2 tuple

A silent installation of the 5.2 builder setup produced the following visible machine-scope 32-bit entry on a 64-bit VM:

```text
Key               HKLM\Software\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall\{318020E9-4E14-DAB0-1CE4-2EE91C6FF5D0}
DisplayName       Actual Installer
DisplayVersion    5.2
Publisher         Softeza Development
InstallLocation   C:\Program Files (x86)\Actual Installer
DisplayIcon       C:\Program Files (x86)\Actual Installer\AInstaller.exe
UninstallString   C:\Program Files (x86)\Actual Installer\Uninstall.exe
```

The parser's manifest-safe paths for this fixture are `%ProgramFiles(x86)%\Actual Installer`, `%ProgramFiles(x86)%\Actual Installer\AInstaller.exe`, and `%ProgramFiles(x86)%\Actual Installer\Uninstall.exe`. This comparison validates the tuple for that route and fixture.

## VM-validated 4.8 tuple

A silent installation of the 4.8 builder setup completed with exit code 0 and produced a visible machine-scope 32-bit entry whose key was the literal application name:

```text
Key               HKLM\Software\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall\Actual Installer
DisplayName       Actual Installer 4.8
DisplayVersion    4.8
Publisher         Softeza Development
InstallLocation   C:\Program Files (x86)\Actual Installer
DisplayIcon       C:\Program Files (x86)\Actual Installer\AInstaller.exe
UninstallString   C:\Program Files (x86)\Actual Installer\Uninstall.exe
```

## Generated uninstaller

Metadata containers can carry helper material used to create the final uninstaller. A logical `[Files]` record can also lack a direct payload entry because its output is generated at installation time. `GeneratedOutputs` classifies these records and names a unique `AUninstall.exe`, `AIUninstall.exe`, or `Uninstall.exe` helper when present. A repeated logical destination already supplied by another physical record is classified as `DuplicateLogicalRecord` rather than reported as missing.

Installed-state comparisons established that the 5.2, 8.0, and 8.4 runtimes copy the selected uninstaller helper byte for byte. The physical route catalog therefore marks Cabinet5 and numbered-ZIP generated uninstallers as `ExactCopy`; ordinary extraction writes the helper to the configured installed uninstaller path. `Expand-ActualInstallerInstaller -MetadataEntries` remains available for inspecting the original helper under `_actual\metadata`. Cabinet3, Cabinet4, and generated updater helpers remain evidence-only because their final output bytes have not been verified.

The generated uninstaller documents `/S` for silent removal. VM-observed built-in ARP entries store the unquoted uninstaller path in `UninstallString` and do not add a `QuietUninstallString`. `UninstallerCommandEvidence` therefore returns the registry value separately from a safely quoted `<uninstaller> /S` invocation. A concrete package can add custom commands, running-application checks, or retained files, so successful silent removal still requires VM evidence when these details matter.

## Update detection

Update installers search both user and machine uninstall roots for the application GUID. The project can then update in place, remove the old release, install side by side, or ask. The Product GUID therefore participates in both ARP identity and update behavior.

If built-in registration is disabled, update detection cannot use this path even if payload files are present. The runtime then follows clean-install behavior unless custom logic finds the product separately.

## Custom ARP writes

`[Registry]` can create explicit keys directly below the uninstall roots. The parser decodes literal path, value name, type, value, overwrite/removal policy, and view; groups rows by case-insensitive root/view/key identity; and returns each complete group as `CustomAppsAndFeaturesEvidence`.

A group with `SystemComponent` set to a nonzero integer is hidden and is not projected as a visible entry. A group without a resolved nonempty `DisplayName` is incomplete. Resolved `DisplayVersion`, `Publisher`, `InstallLocation`, `DisplayIcon`, `UninstallString`, and `QuietUninstallString` remain available in the group's value dictionary, while the schema-facing Apps & Features entry contains only supported manifest fields.

Conditions, `HKDE`, split elevation, root redirection, custom variables, and command-side registry writes can still make the final result scope-dependent. Multiple complete custom keys produce `ActualInstaller.ARP.MultipleCustomEntries` instead of an arbitrary ProductCode.

## Visibility and hidden entries

The built-in "Show in Programs and Features" option is an enablement gate rather than a `SystemComponent=1` hide mechanism. When disabled, published behavior says the product GUID is not registered through the built-in route. An explicit custom registry row could still write `SystemComponent`; that is package-specific evidence and requires the row to be decoded literally.

## ARP confidence rules

- A Product GUID alone does not prove that the setup writes a visible entry.
- A visibility option without an exposed legacy key identity does not justify a guessed ProductCode.
- An outer PE product name does not replace `AppName` or the installed `DisplayName`.
- A helper template is not the installed uninstaller.
- A default scope is not the selected hive for every dual-scope execution.
- Explicit custom uninstall keys remain separate from the built-in Product GUID route.

## Source references

- [Actual Installer update installers and Product GUID behavior](https://www.actualinstaller.com/articles/how-to-create-update-installer.html)
- [Actual Installer registry behavior](https://www.actualinstaller.com/help/registry.html)
- [Actual Installer command-line parameters](https://www.actualinstaller.com/help/command-line.html)
