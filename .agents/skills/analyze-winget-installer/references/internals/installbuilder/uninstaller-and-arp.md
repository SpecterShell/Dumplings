# InstallBuilder uninstaller and ARP internals

## Built-in registration gate

InstallBuilder's built-in Windows uninstall registration is active only when all three conditions are true:

```text
installationType == normal
AND createUninstaller == true
AND createWindowsARPEntry == true
= built-in Windows ARP row
```

`installationType=upgrade` can reuse or update an existing installation without creating a fresh deterministic row. `createUninstaller=false` disables the built-in row even if `createWindowsARPEntry` remains true. A project can still create a custom uninstall row through explicit registry actions.

## Built-in ProductCode

The built-in uninstall subkey is `windowsARPRegistryPrefix`. Its documented default is `${project.fullName} ${project.version}`. Dumplings resolves only deterministic project substitutions and uses the resulting subkey leaf as WinGet `ProductCode`.

```text
HKLM\Software\Microsoft\Windows\CurrentVersion\Uninstall\<windowsARPRegistryPrefix>
```

This ProductCode is an arbitrary registry identity, not an MSI GUID. Preserve spaces, punctuation, and case as written by the runtime. If the prefix contains a runtime-only variable, return no authoritative ProductCode and report the unresolved variables.

## Built-in hive and view

The built-in route writes HKLM. Registry view comes from the native launcher or `windows64bitMode`:

| Runtime evidence | Built-in key view |
| --- | --- |
| x86 launcher and `windows64bitMode=0` | 32-bit uninstall view, physically under WOW6432Node on a 64-bit OS |
| x86 launcher and `windows64bitMode=1` | 64-bit uninstall view |
| native x64 or ARM64 launcher | 64-bit uninstall view |

Do not encode `WOW6432Node` into `RegistryKey`. Keep the logical path and the separate `RegistryView` property.

## Built-in values

The parser reconstructs these values from project properties and runtime defaults:

| ARP value | Source |
| --- | --- |
| `DisplayName` | `productDisplayName`, default `${product_fullname}` |
| `DisplayVersion` | resolved project `version` |
| `Publisher` | resolved project `vendor` |
| `UninstallString` | quoted resolved `uninstallerDirectory\uninstallerName.exe` |
| `DisplayIcon` | `productDisplayIcon` |
| `InstallLocation` | resolved `installdir` default |
| `URLInfoAbout` | `productUrlInfoAbout` |
| `Comments` | `productComments` |
| `Contact` | `productContact` |
| `HelpLink` | `productUrlHelpLink` |
| `NoModify` | fixed integer `1` |
| `NoRepair` | fixed integer `1` |

The generated uninstall command is quoted even when the path contains no space. A missing `.exe` suffix on `uninstallerName` is completed before path construction. `QuietUninstallString` is not inferred because the built-in project fields do not prove a separate quiet command.

`EstimatedSize` and `InstallDate` are generated from runtime installation state and remain null during static parsing. Do not calculate `EstimatedSize` from packaged payload lengths because component selection, generated files, downloaded resources, and child installers can change the result.

## Custom registry ARP entries

Persistent `registrySet` actions can add, replace, supplement, or hide uninstall keys. Dumplings groups effective writes by root and authored key, resolves the key after deterministic substitutions, and interprets values only beneath the Windows uninstall path.

```text
HKLM or HKCU
`-- Software\Microsoft\Windows\CurrentVersion\Uninstall\<key>
    +-- DisplayName
    +-- DisplayVersion
    +-- Publisher
    +-- UninstallString and QuietUninstallString
    +-- DisplayIcon and InstallLocation
    +-- URLInfoAbout, Comments, Contact, HelpLink
    +-- SystemComponent
    +-- NoModify and NoRepair
    `-- EstimatedSize and InstallDate
```

The subkey leaf becomes the custom ProductCode. Registry view follows an explicit action view when present and otherwise uses the project context. A custom row can exist beside the built-in row or can target the same identity and override selected values.

## Operation order

ARP reconstruction respects runtime phase order. This matters because InstallBuilder creates its built-in row after `postInstallationActionList` and before `postUninstallerCreationActionList`.

```text
preInstallationActionList registry changes
readyToInstallActionList registry changes
folder actionList registry changes
postInstallationActionList registry changes
create built-in uninstaller and ARP row
postUninstallerCreationActionList registry changes
```

A deterministic delete of the built-in key during an earlier phase is followed by built-in recreation. The same delete in `postUninstallerCreationActionList` removes the final row. A value-level delete clears only the matching projected property. A conditional final delete makes the identity uncertain rather than definitely absent.

## Visibility

A row is visible when it has an effective `DisplayName`, its installation condition is true, and `SystemComponent` is absent or false. Any nonzero numeric `SystemComponent` is hidden. Recognized textual true values are also hidden. A condition-dependent `SystemComponent` produces uncertain visibility.

| Collection | Meaning | WinGet use |
| --- | --- | --- |
| `VisibleArpEntries` | Deterministic visible rows | Eligible for `AppsAndFeaturesEntries` |
| `HiddenArpEntries` | Deterministic hidden rows | Evidence only; never projected as visible package identity |
| `UncertainArpEntries` | Conditional identity or visibility | VM validation required |
| `ArpEntries` | Union of all reconstructed rows | Complete static evidence |

A package that writes only hidden entries returns no WinGet-facing ProductCode. Hidden registration is not converted into a visible row merely because its values look complete.

## Primary entry selection

When the built-in row survives and is visible, it remains the primary package identity. If project actions deterministically remove or hide it and exactly one custom visible row survives, that custom row becomes primary. Multiple visible custom rows are returned without guessing which one owns the package.

```text
visible surviving built-in row -> primary
else exactly one visible custom row -> primary
else -> no single ProductCode
```

`WritesAppsAndFeaturesEntry` is true when at least one visible row exists, false when the project deterministically creates none, and null when conditional rows or upgrade behavior prevent a conclusion.

## Conditional and unresolved values

A custom key whose path remains dynamic cannot establish ProductCode. A known key with conditional display values can retain its identity while requiring review of `AppsAndFeaturesEntries`. An unresolved display name, version, publisher, or uninstaller value is reported against the affected field rather than causing unrelated metadata to be discarded.

The exact rule or expression remains in `DynamicProjectLogic`. VM validation should recreate the target files, registry values, command-line parameters, or prior product version that controls the branch.

## Upgrade behavior

Upgrade projects may discover a previous installation, reuse its directory and uninstall key, update values in place, or remove an older row. Static analysis cannot infer the installed prior version from the current package. When `installationType=upgrade` and no fresh deterministic row is proven, `WritesAppsAndFeaturesEntry` remains unknown and ProductCode remains null.

For packages that publish both clean-install and update launchers, validate the clean installer separately. Do not transfer a ProductCode between artifacts solely because their display metadata matches.

## Nested installer ownership

An InstallBuilder wrapper can execute MSI, EXE, or prerequisite payloads during installation. The outer project may create its own ARP row, the child may create another row, or project actions may suppress the outer row. `NestedInstallerCandidates` identifies embedded setup-like executions but does not transfer their ProductCode automatically.

Determine ownership from the outer ARP gate, ordered registry actions, nested parser evidence, and VM installed-state differences. An application launched from a final page does not become the installer owner.

## VM validation procedure

Capture installed-state evidence before installation, after installation, and after first run when the project launches or initializes the application. Compare at least:

- Visible and hidden HKLM 32-bit, HKLM 64-bit, and HKCU uninstall rows.
- Exact key leaf, `DisplayName`, `DisplayVersion`, `Publisher`, and `SystemComponent`.
- `UninstallString`, quoting, uninstaller filename, and install directory.
- Runtime-only `EstimatedSize` and `InstallDate`.
- Clean installation versus upgrade from an accepted prior version.
- Unattended uninstallation and whether the key and install directory are removed.
- Child-installer rows separately from the outer InstallBuilder row.

The current 26.8.0 x64 builder fixture wrote the predicted 64-bit HKLM row with ProductCode `InstallBuilder for Windows 26.8.0`, a quoted `%ProgramFiles%\installbuilder-26.8.0\uninstall.exe` command, `NoModify=1`, and `NoRepair=1`. Silent uninstall removed the row and installation directory. This is route validation for that fixture, not a universal substitute for testing custom projects.

## WinGet projection

`AppsAndFeaturesEntries` contains only nonempty schema-supported values from visible entries: `DisplayName`, `Publisher`, `DisplayVersion`, `ProductCode`, and `InstallerType`. Redundant fields can be removed later by `Optimize-WinGetManifest` according to the default locale and installer-level ProductCode rules.

Do not place `RegistryHive`, `RegistryView`, uninstall commands, URLs, `SystemComponent`, `NoModify`, `NoRepair`, `EstimatedSize`, or `InstallDate` into WinGet `AppsAndFeaturesEntries`; retain them as analysis evidence.

## Source references

- [InstallBuilder Windows behavior](https://releases.installbuilder.com/installbuilder/docs/installbuilder-userguide/_windows.html)
- [InstallBuilder project settings](https://releases.installbuilder.com/installbuilder/docs/installbuilder-userguide/project.html)
- [InstallBuilder Windows registry behavior](https://releases.installbuilder.com/installbuilder/docs/installbuilder-userguide/_windows.html)
