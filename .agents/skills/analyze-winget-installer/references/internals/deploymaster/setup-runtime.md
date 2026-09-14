# DeployMaster setup runtime

## Scope and elevation

The package-control scope byte is an initial route, while the identity marker establishes the concrete built-in registry and destination behavior. Marker `0x06` is intentionally user scope with required administration even though its package-control value also appears on machine media. The parser reports that route as `Scope=user`, `RegistryRoot=HKCU`, and `RequiresAdministrativeRights=true`.

Dual-scope media chooses user scope when run unelevated on a clean system and machine scope when elevated. A prior machine installation can make a later silent run take the elevated maintenance route. Machine-only media run unelevated with `/silent` exits successfully without installing and without prompting for UAC. These behaviors make launch context part of the evidence; a manifest must not guess one scope from the outer requested-execution level alone.

The runtime can elevate itself. `RequiresAdministrativeRights` describes compiled package behavior and is not automatically equivalent to a WinGet `ElevationRequirement` value.

## Architecture selection

The normalized control header exposes five practical application modes: x86 only on x86 Windows, x86 on x86 and x64 Windows, mixed x86/x64 selected by the operating system, x64 with an x86 setup stub, and x64 with a pure x64 stub. Per-file flags further select architecture-specific installed items.

Mixed media stores distinct runtime cores, support DLLs, and uninstaller payloads. The installed x86 uninstaller is named `UnDeploy.exe` even when its source record is `UnDeploy32.exe`; the x64 route installs `UnDeploy64.exe`. The outer setup PE machine must not replace this package evidence.

## Command line

Locator-based runtimes support `/s` and `/silent`, `/nodesktop`, `/temp`, `/appfolder`, `/appcommonfolder`, `/appmenu`, and `/userdata`. Mixed media can accept `/32`. Verified dual-scope Header70 and Header74 media supports `/userall`; Header66 does not.

Header70 and Header74 runtime cores contain `/noadmin`, which suppresses the elevated relaunch and the DeployIT `Stub` registration path. Header66 uses an older `/elevate /silent` relaunch protocol. `/components`, `/advanced`, `/usercurrent`, `/userall`, and `/elevate` also occur as internal mode markers. Token presence alone does not prove that an internal marker is a supported public override; `/usercurrent` remains withheld until direct invocation behavior is independently validated.

`/portable` is reported only when package settings enable a portable route and the bounded runtime core contains the exact token. Generated PE versions identify the packaged application, so a reported application version cannot be compared with the DeployMaster 7.5 feature introduction.

Classic 2.5.x runtime images contain no referenced unattended switch table or bounded slash-token route. They are interactive-only. Family-level modern suggestions must be replaced by exact parser evidence for a classic artifact.

## Portable routes

`PortableInstallationMode=Never` has no portable path. `UserChoice` preserves normal installation and allows a separate portable choice. `Always` executes only the portable path and suppresses built-in ARP, registry, shortcut, association, prerequisite, and elevation effects. The parser therefore returns no ProductCode or Apps & Features entry for always-portable media.

The portable switch is not sufficient to classify the setup itself as a WinGet portable installer. The intended invocation, selected destination, and absence of system effects must be validated for the package being authored.

## Prerequisites and child execution

Silent DeployMaster does not make a nested prerequisite silent. Built-in .NET and custom prerequisite records are separate installability evidence, and each child command must be analyzed independently. Support DLLs can veto installation, add folders, validate registration input, alter registry behavior, and perform completion work beyond the declarative records.

Post-install and pre-uninstall file indexes are resolved into `ExecutedPayloads`. Their payload architecture and command line are available for follow-up analysis; the parser does not execute them.

## Expiration and platform policy

The control header contains supported Windows flags, optional Windows 10 and 11 version-code ranges, and a future-Windows bit. These values describe runtime compatibility but do not map mechanically to WinGet `MinimumOSVersion`.

Both fixed-date and days-after-release builder settings compile to one final expiration date and message. The original authoring mode is unrecoverable. An expired artifact can refuse before showing its welcome page, so a time-limited setup should not be submitted when a durable release exists.

## Uninstaller behavior

The generated uninstaller accepts `/silent` and replays the deployment log. Controlled 6.x uninstallers removed deployed files but left the ARP key stale. Uninstall validation must therefore compare registry state as well as process exit and filesystem changes.
