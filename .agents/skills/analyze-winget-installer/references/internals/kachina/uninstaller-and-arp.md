# Kachina uninstaller and ARP behavior

## Built-in ARP record

After release metadata is available, Kachina writes one uninstall key named by `regName`:

```text
Software\Microsoft\Windows\CurrentVersion\Uninstall\<regName>
```

The hive follows actual process elevation. An elevated install writes HKLM. An unelevated private-path install writes HKCU. Registry view follows the host architecture for the generated runtime.

| Value | Source |
| --- | --- |
| `DisplayName` | configuration `appName` |
| `DisplayVersion` | metadata `tag_name`, with runtime fallback only outside static evidence |
| `Publisher` | configuration `publisher` |
| `InstallLocation` | selected target directory |
| `DisplayIcon` | target plus `exeName` |
| `UninstallString` | target plus `uninstallName` |
| `EstimatedSize` | sum of metadata installed-file sizes divided by 1024 |
| `NoModify` | 1 |
| `NoRepair` | 1 |
| `InstallerMeta` | serialized release metadata used by update and uninstall |

The default parser projection uses `%ProgramFiles%\<programFilesPath>` and the machine route. `RegistryRoutes` records the conditional HKCU alternative. `AppsAndFeaturesEntries` describes the default route and should be compacted by WinGet manifest optimization when ProductCode, display name, publisher, or installer type are redundant.

## Generated uninstaller

The uninstaller is reconstructed from the installer PE prefix, configuration record, and optional image. Its pre-index fields are cleared. At runtime it reads `InstallerMeta`, removes metadata payload files, updater, configured extra paths, optional user-data paths, shortcuts, the uninstall registry key, and itself.

`extraUninstallPath` is always part of the configured cleanup set. `userDataPath` is removed only when the user selects that option. Paths can contain `${INSTALL_PATH}` and `${APP_NAME}` substitutions. Static parsing retains these templates and their deterministic configuration values.

## Updates

An update can locate an existing installation by the current directory, parent directory, then HKLM and HKCU ARP `InstallLocation`. If installation state came from a registry route, finalization can recreate the updater, uninstaller, and ARP metadata. Static identity remains `regName` across versions.

## Visibility and matching

Kachina's built-in record is visible and has no `SystemComponent` flag in the verified source. The ProductCode must not be replaced by a payload hash, application executable name, source ID, or repository name. User and machine installations use the same key name in different hives, so scope is part of the installed-state match.

