# DeployMaster metadata model

## Identity

The locator identity is form-feed-delimited strict UTF-8. Fields 0 through 6 contain publisher, publisher URL, display name, package URL, display version, OLE Automation release day, and copyright. Fields 7 through 10 contain readme filename, license filename with an optional leading policy marker, and x86/x64 support-DLL filenames. Fields 11 through 18 contain machine and user application paths, common-files and publisher-common paths, machine and user menu paths, and common and user data paths.

The first byte of locator field 11 is a route marker: `0x01` means machine, `0x02` means user, `0x03` means dual scope, and `0x06` means user scope with required administration. The byte is removed before path projection. Raw and normalized paths are retained separately.

Classic identity is Windows-1252 and uses a different 17-field schema. It adds a display-icon filename at field 7 and has only one support-DLL field. Its installation and menu paths occupy fields 11 through 14. Classic and locator identities must never share positional decoding.

## Components

Locator component metadata begins with a byte count. Each record contains a length-prefixed UTF-8 name, flags, requirement indexes, and a description. Flag bit `0x02` selects default installation and bit `0x01` makes the component user-selectable. Requirement indexes must point to earlier components and cannot repeat.

Classic components use byte-length Windows-1252 strings and a related flag layout. The parser reports stable component indexes because installation forests and item groups are serialized in component order.

## Installation tree

Locator installation trees are recursive. A marker below `0xFE` introduces a UTF-16LE directory name and create-empty flag. `0xFE` starts an item list and `0xFF` closes the current list. File items preserve component, source index, destination, x86/x64 applicability, overwrite policy, uninstall retention, and optional arguments. Shortcut and URL-shortcut records preserve their target, destination, labels, flags, and arguments.

Classic forests use byte-length Windows-1252 directory names but the same `0xFE` and `0xFF` structural roles. The implemented route recovers `%APPFOLDER%`, `%APPMENU%`, `%DESKTOP%`, and nested destinations without assigning names from payload order.

## Registry program

Locator registry metadata is a recursive opcode stream. Implemented opcodes select roots and child keys, delete keys, choose default or named values, keep existing values, configure logging/removal, write `REG_SZ`, `REG_DWORD`, or `REG_BINARY`, and terminate branches. `HKEY_AUTO` maps to HKCU, HKLM, or conditional SHCTX according to the selected installation scope.

Classic registry records use a NUL-terminated root and a smaller branch vocabulary. Both routes return typed `CustomRegistryWrites` and `DeletedRegistryKeys`; they do not apply writes to the analysis host.

Literal writes under `Software\Microsoft\Windows\CurrentVersion\Uninstall` are grouped into custom ARP candidates. Entries without `DisplayName` or with nonzero `SystemComponent` remain registry evidence but are excluded from visible `AppsAndFeaturesEntries`.

## Associations

Dedicated file-type records preserve extension, description, default-selection evidence when present, icon indexes, action names, architecture-specific executable indexes, and parameters. An executable index of `-1` is unresolved and cannot establish an installed command. Literal class registrations from the Registry tab are interpreted independently and merged with the dedicated records.

## Prerequisites and execution

Locator trailing metadata contains a built-in .NET Framework requirement and custom prerequisite descriptors. The .NET record exposes compatible 1.0 through 3.5 flags, the minimum supported 4.x release, optional bundled installer filename, and fallback URL. Undocumented trailing bytes stay raw.

Completion and uninstall records hold architecture-specific file indexes and arguments. Resolved indexes become `ExecutedPayloads` with `AfterInstall` or `BeforeUninstall` stages. The parser reports the child file and command but does not infer its side effects or silent behavior.

Classic prerequisite and completion records remain unresolved. Their bounded positions are preserved, and the parser emits `DeployMaster.Metadata.ClassicEffectsPartial` rather than treating absent projections as proof of absent behavior.

## Policy records

`UpdatePolicy` reports deletion of obsolete files, compatible-release requirements, patch text, and blocked window classes or captions. `CompletionActions` reports final-message, reboot-prompt, Start Menu display, and post-install launch settings. `UninstallConfiguration` reports pre-uninstall executions and retention behavior.

`PackageSettings` exists on Header74 media. It exposes identity prompts, `PortableInstallationMode`, removable-drive marker policy, allowed-drive policy, and a default portable folder. The common record is three bytes; portable-only fields follow only when the mode is nonzero.
