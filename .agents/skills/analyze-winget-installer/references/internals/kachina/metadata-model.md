# Kachina metadata model

## Configuration JSON

Structural detection requires non-empty `appName`, `publisher`, `regName`, and `exeName`. Defaults exist for optional runtime fields.

| Field | Meaning | Parser projection |
| --- | --- | --- |
| `appName` | application and shortcut display name | `DisplayName` |
| `publisher` | ARP publisher | `Publisher` |
| `regName` | uninstall subkey | `ProductCode` |
| `exeName` | main installed executable | display icon and payload analysis target |
| `uninstallName` | generated uninstaller name | uninstall command, default `uninst.exe` |
| `updaterName` | generated updater name | extraction and uninstall file list, default `update.exe` |
| `programFilesPath` | default target below Program Files | `DefaultInstallLocation` |
| `uacStrategy` | target-writability elevation policy | default and supported scope evidence |
| `source` or `dfsPath` | update source or ordered source catalog | source evidence only; never fetched by parser |
| `runtimes` | prerequisite package identifiers | dependency evidence, not automatic manifest dependencies |
| `userDataPath` | optionally removed user data | uninstall behavior evidence |
| `ignoreFolderPath` | update-preserved paths | update behavior evidence |
| `extraUninstallPath` | additional removal paths | uninstall behavior evidence |
| `needWebView2` | host runtime requirement | dependency evidence |

Current `source` can be a string or an ordered array containing `id`, `name`, `uri`, `hidden`, and `icon`. The parser retains every valid source and selects the first as default evidence. Entries without a URI produce a field-specific diagnostic.

## Release metadata

| Field | Meaning |
| --- | --- |
| `repo_name` | release repository identity |
| `tag_name` | installed DisplayVersion |
| `hashed` | installed path, size, and content hash records |
| `patches` | old/new hash patch relationships |
| `deletes` | paths removed during update |
| `installer` | metadata about the generated installer itself |

Config-only media omits metadata. Its product identity and target source remain available, but target version, installed payload catalog, architecture, and integrity evidence require the source metadata fetched by the runtime.

## Payload identity

`hashed[].file_name` is the installed relative path. `md5` or `xxh` selects the physical TLV name. `size` is the expected decompressed length. Record-name identity and content integrity are checked independently.

## System effects

The built-in runtime creates Start Menu application and uninstall shortcuts, an optional desktop shortcut, updater and uninstaller executables, and one ARP row after release metadata is available. It preserves or deletes paths from configuration and metadata lists. The current structured configuration does not provide general registry, protocol, file-extension, PATH, autorun, firewall, or certificate operations; those arrays remain empty unless a future source-backed structure proves them.

## Unknown fields

Unknown JSON properties remain available on `Configuration` and `Metadata`. They do not become manifest fields. Dynamic online source responses and HDiff result state remain outside the static metadata model.
