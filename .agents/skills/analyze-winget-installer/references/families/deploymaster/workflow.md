# DeployMaster workflow

## When to use

Use `InstallerType: exe` for installers built with DeployMaster. WinGet has no DeployMaster-specific defaults, so every non-default mode and switch must be supported by static documentation or VM evidence.

## Detection

Strong evidence for DeployMaster 6 and later is a validated package locator at file offset `0x80`, a matching CRC32-protected package region, and DeployMaster PE version comments. Classic 2.x evidence instead requires trusted DeployMaster PE identity, a `BZh9` overlay, a BZip2 member that expands to a valid runtime PE, two leading length-prefixed zlib metadata records, and a safe filename catalog matching the contiguous payload tail. Do not classify arbitrary LZMA, BZip2, or zlib overlays from marker strings alone.

## Static analysis

Read [DeployMaster Parser Internals](../../internals/deploymaster/overview.md) before changing detection, extraction, binary decoding, or parser limits.

```powershell
. .\Modules\PackageModule\Index.ps1
$Info = Get-DeployMasterInfo -Path $InstallerPath
```

### Parse once

`Get-DeployMasterInfo` validates either the classic `ClassicBZip2` route or the later locator-based `Header66`, `Header70`, or `Header74` route. Reuse the returned object instead of calling multiple `Read-*FromDeployMaster` helpers. `OverlayInfo.FormatProfile`, `ObservedRuntimeRange`, and `ProfileEvidence` explain the selected structural route; the observed release range does not select it.

For classic 2.x media, the parser returns structured identity, default machine destination, release date, runtime architecture, component descriptors with recursive destination forests, the complete auxiliary and ordinary payload catalog, installed-file, shortcut, and URL-shortcut records with their component and destination ownership, explicit registry writes, file associations, and the built-in uninstall registration proven by the controlled 2.5.3 installation. Prerequisite and completion records remain unresolved, and the classic runtime is statically interactive-only, so no silent mode or switch is returned.

```powershell
$Info | Select-Object DisplayName, DisplayVersion, Publisher, ProductCode, Scope, SupportedScopes, InstallerArchitecture, ApplicationArchitectureMode, ApplicationArchitectures, SupportedOperatingSystemArchitectures, WritesAppsAndFeaturesEntry, Diagnostics
$Info.Components
$Info.InstallationItems
$Info.RegistryWrites
$Info.FileEntries
$Info.FileAssociations
$Info.Prerequisites
$Info.CompletionActions
$Info.UninstallConfiguration
$Info.UpdatePolicy
```

The parser distinguishes these builder modes:

- x86 application for x86 Windows only.
- x86 application for x86 and x64 Windows.
- x86 and x64 applications selected for the running Windows architecture.
- x64 application with an x86 installer stub.
- x64 application with a pure x64 installer.

Use the installed application architecture for manifest authoring. The outer stub architecture is separate evidence and does not by itself determine the manifest `Architecture`.

### Expand bounded content

Expansion never starts the installer. It writes each decoded runtime core, structured metadata block, and package file beneath separate safe paths. The classic route decodes its BZip2 runtime and selected zlib payload records through the same bounded destination and collision handling used by later media:

```powershell
$Files = Expand-DeployMasterInstaller -Path $InstallerPath -DestinationPath $DestinationPath -CollisionAction Rename
$Files
```

Inspect `Runtime\DeployMasterCore-x86.exe` and/or `Runtime\DeployMasterCore-x64.exe` for runtime behavior. Inspect `Payload` for the installed files and nested installers. Use `-Name` to select one file.

### Resolve scope and ARP

The package-control scope byte provides the initial static route:

- `0`: current user.
- `1`: all users.
- `2`: user and machine scope.

The identity route refines this value. In particular, marker `0x06` means a current-user installation with the builder's separate require-admin option enabled; it still writes HKCU despite sharing package-control value `1` with an all-users build. Use `RequiresAdministrativeRights` as behavior evidence, but do not automatically translate it to WinGet `ElevationRequirement` because the outer DeployMaster stub can perform its own elevation flow.

The structured identity block supplies `DisplayName`, `DisplayVersion`, `Publisher`, release date, copyright, publisher and package URLs, readme and license filenames, architecture-specific support DLLs, and separate user/machine install locations. DeployMaster's built-in uninstaller uses the display name as its uninstall-key identity, so the parser returns that value as `ProductCode` and emits one `BuiltInRegistrationVariants` record for each normal-install scope and application architecture. A single-scope, single-architecture package also exposes `BuiltInRegistration`, `UninstallString`, and `DeploymentLogPath` directly. Controlled installations establish `UnDeploy.exe` for x86 installations and `UnDeploy64.exe` for x64 installations. Mixed media physically stores `UnDeploy32.exe` and `UnDeploy64.exe`, but the selected x86 payload is installed and registered as `UnDeploy.exe`. Header66 and Header70 runtimes always leave the executable path unquoted and quote the `Deploy.log` path; Header74 runtimes quote each resolved path exactly when it contains a space, which covers every standard install location and reproduces the fully quoted form observed in controlled installations. Live elevated installations of the cracked 6.1.2, 6.5.2, 6.5.3, 7.1.1, and 7.2.0 demo media confirm these routes against the real registry, and every generation writes the full built-in value set. The same validation confirms `NoModify=1`, `NoRepair=1`, and the `Software\JGsoft\DeployIT` log-tracking value. `VersionMajor` and `VersionMinor` are string values holding the first two dot-separated `DisplayVersion` components, so `DEMO 6.1.2` registers as `DEMO 6` and `1`. Live installs also confirm that the application URL becomes both `HelpLink` and `URLInfoUpdate`, while the publisher URL becomes `URLInfoAbout`; in every locator-based generation from 6.0.1 through 7.7.0 the runtime falls back to the publisher URL for `HelpLink` and `URLInfoUpdate` when no application URL is configured. These values remain parser and registry evidence because WinGet `AppsAndFeaturesEntries` has no corresponding URL fields. `EstimatedSize`, `InstallDate`, and the tracking `Stub` value are generated at runtime and remain named evidence rather than guessed values; a reinstall over an existing deployment registers an indexed log name such as `Deploy2.log`. Media whose project defines an application icon also registers a `DisplayIcon` value, which the parser leaves unresolved. A support DLL can veto installation, add folders, validate identity input, modify registry behavior, and run custom completion code; inspect the extracted DLL or validate the package in a VM whenever `SupportDlls` is nonempty.

The classic 2.x route has separate installability and ARP behavior. Static runtime analysis proves that 2.5.x media has no unattended command-line route, so author it as interactive-only and do not test or guess silent switches. A controlled 2.5.3 installation confirms a 32-bit HKLM uninstall key whose `ProductCode` is the package identity `DisplayName`; its visible `DisplayName` concatenates publisher, package name, and version, and its command is `%WINDOWS%\UnDeploy.exe "<MachineInstallLocation>\Deploy.log"`. Classic ARP does not write Publisher or DisplayVersion values, so the parser does not fabricate them in `AppsAndFeaturesEntries`. Explicit Registry-tab uninstall rows are projected separately and merged only when their key name matches the built-in identity.

`CustomRegistryWrites` and `DeletedRegistryKeys` contain the recursive Registry-tab program. Literal `REG_SZ`, `REG_DWORD`, and `REG_BINARY` writes are decoded for locator-based media; classic 2.x media currently proves `REG_SZ` and `REG_DWORD`. An unconditional custom write below an uninstall key is also projected into `AppsAndFeaturesEntries`; keep-existing and unresolved conditional behavior remains raw evidence for VM validation. For `Brinno.BrinnoVideoPlayer`, VM evidence confirms an x86 HKLM EXE ARP entry keyed `Brinno Video Player` with no `WindowsInstaller` value.

DeployMaster provides no built-in hidden-ARP or ARP-customization option. No builder tab or serialized project field controls ARP visibility, byte searches of the 7.7 builder and the 6.0.1 through 7.7 runtime cores find no `SystemComponent` or `QuietUninstallString` references in any string encoding, and the shipped help describes the Add/Remove Programs entry as unconditional. Registry-tab uninstall writes are therefore the only custom ARP mechanism, and the parser labels them as custom evidence rather than built-in variants. Controlled builder projects prove three shapes end to end: a Registry-tab `Custom.Product` key with `DisplayName`, `DisplayVersion`, and `Publisher` installs into HKLM and is projected as a second `AppsAndFeaturesEntries` row; the same key plus a `SystemComponent=1` DWORD is written to the registry but excluded from `AppsAndFeaturesEntries` because Windows hides the row; and a current-user project with `Require admin rights` enabled registers an HKCU `Custom.User.Product` row and the hidden HKLM record in one elevated silent install, which also live-validates the marker-6 identity route (user scope with `RequiresAdministrativeRights`). The builder enforces the matching constraints at build time: HKCU records require `Install for all users` to be disabled, and HKLM records require current-user installs to require admin rights or be disabled, so real media never combines a machine-scope built-in registration with HKCU custom uninstall rows. Treat a visible custom row as the package's second uninstall identity and never merge it with the built-in registration unless the key names match.

### Resolve file associations

`FileAssociations` contains each literal extension, description, default flag when the format stores one, icon indexes, action names, executable indexes, and parameters. Current records use length-prefixed UTF-8 strings; archived 6.0 through 7.2 records use form-feed-terminated Windows-1252 strings and do not encode the default flag. Classic 2.x records also use form-feed strings but carry only x86 icon and executable indexes. Include `FileExtensions` when the literal extensions are valid.

An executable index of `-1` means the action did not resolve to a packaged file and should not be treated as an installed open command. Literal protocol and file-extension registrations from the Registry tab are merged with the dedicated file-type records; dynamic application registration still requires VM evidence.

### Review behavior and prerequisites

`Components` records default and user-selectable state plus component dependencies. `InstallationFolders`, `InstalledFiles`, `Shortcuts`, and `UrlShortcuts` preserve component ownership and catalog indexes. Each installed-file record reports its x86/x64 applicability, `AlwaysOverwrite`, `OverwriteIfNewer`, or `NeverOverwrite` policy, and whether the uninstaller deliberately retains it. `ExecutedPayloads` resolves exact post-install and pre-uninstall file indexes; analyze those payloads separately before assigning wrapper behavior.

`UpdatePolicy` reports whether the package deletes obsolete files, requires a compatible previous release, and blocks installation while configured window classes or captions are present. Patch explanatory text is returned as both one string and normalized lines. Treat these running-application checks as potential unattended blockers and verify them in the VM when the application may already be open.

`Prerequisites` contains the built-in .NET Framework record and custom third-party setup descriptors. `DotNetFrameworkRequirement` names the builder's compatible 1.0 through 3.5 targets, minimum 4.x version, optional automatic-installer filename, and fallback URL; its trailing undocumented bytes remain raw. Silent DeployMaster cannot suppress prompts from nested prerequisite installers, so validate the complete chain when prerequisites are present.

`PackageSettings` reports identity prompts and documented portable-installation settings for validated `Header74` media. The common record is three bytes; only a nonzero portable mode appends marker mode, drive policy, and the compressed default-folder block. `PortableInstallationMode` is `Never`, `UserChoice`, or `Always`; `PortableMarkerMode` controls `RemovableDrive.sys`; `PortableAllowAnyDrive` and `PortableDefaultFolder` describe the portable destination UI. `UserChoice` retains the normal ARP-writing path alongside the portable path. `Always` suppresses `ProductCode`, `AppsAndFeaturesEntries`, and effective registry writes because every run creates a portable installation. A portable path copies files without ARP, registry, shortcut, association, prerequisite, or elevation effects. Do not classify the artifact itself as a WinGet portable installer unless the intended command path is proven.

`CommandLineSwitches` records the source-documented runtime interface. In addition to `/s` and `/silent`, DeployMaster supports `/nodesktop`, `/temp`, `/appfolder`, `/appcommonfolder`, `/appmenu`, and `/userdata`; mixed x86/x64 packages also accept `/32`. Structurally verified dual-scope `Header70` and `Header74` media exposes `/userall`, matching the documented behavior present by 6.5.1. `/portable` was introduced in 7.5, but generated PE version resources contain the packaged application version rather than the DeployMaster runtime version. The parser therefore returns `/portable "<PATH>"` only when valid package settings enable the route and a bounded expansion of the runtime core contains the switch itself. `UninstallerSwitches` records the generated uninstaller's `/silent` mode. Only project schema fields into a WinGet manifest when they serve that package's installation behavior.

`SupportedWindowsVersions`, `SupportsFutureWindowsVersions`, and the Windows 10/11 minimum and maximum version codes expose the compiled Platform-tab constraints. These are installer compatibility evidence, not a direct WinGet `MinimumOSVersion` conversion.

`ExpirationPolicy` reports the final date after which the runtime refuses to show its welcome screen and the compiled expiration message. DeployMaster compiles both a fixed date and “days after release” into the same final date, so the original builder mode cannot be distinguished from shipped media. Prefer a non-expiring artifact and do not submit an installer that will expire during normal WinGet use.

## Manifest shape

DeployMaster is a generic EXE family. The documented silent and install-folder switches therefore need explicit installer-level fields:

```yaml
Installers:
- Architecture: x64
  InstallerType: exe # DeployMaster
  InstallerUrl: https://example.com/Product-1.2.3-x64.exe
  InstallerSha256: <SHA256>
  InstallModes:
  - interactive
  - silent
  InstallerSwitches:
    Silent: /silent
    InstallLocation: /appfolder "<INSTALLPATH>"
```

Remove a switch or mode that the current package does not support. Do not infer an unattended switch from another generic EXE family.

## WinGet defaults and overrides

WinGet supplies no DeployMaster defaults for generic `InstallerType: exe`. Treat the documented DeployMaster switches as complete installer-level overrides, and retain only modes demonstrated by the current package.

## Apps & Features

Use structured parser evidence to identify the visible Apps & Features owner. Do not substitute metadata from a hidden or nested payload unless that payload writes the visible uninstall entry.

## Scope and architecture

Use explicit parser evidence for scope and installed payload architecture. Preserve existing manifest intent and use VM validation when either value is conditional or unresolved.

## VM validation

Follow [VM validation workflow](../../workflows/vm-validation.md) for silent behavior, exit codes, default scope of a dual-scope package, conditional ARP writes, or first-run associations. DeployMaster-specific checks are:

- Test `/silent` and `/appfolder` exactly as documented for the package.
- For `ClassicBZip2`, do not author silent modes or switches; the runtime is statically proven interactive-only. Compare unusual packages with the source-backed 32-bit HKLM ARP route because only the 2.5.3 demo has been validated live.
- Compare HKCU and both HKLM uninstall views with the parsed scope. Dual-scope media installs user scope when run unelevated with no prior machine install, machine scope when elevated, and takes the elevated update path when a machine install is already registered; machine-scope media silently exits without installing when run unelevated.
- Compare the generated `UninstallString`, `Deploy.log` path, and `Software\JGsoft\DeployIT` value with the applicable `BuiltInRegistrationVariants` record; note that the registered log name becomes indexed, such as `Deploy2.log`, when the previous log file still exists.
- For custom Registry-tab uninstall records, confirm the projected custom row against the actual key and, for records carrying `SystemComponent`, that the key exists while the row stays hidden and out of `AppsAndFeaturesEntries`.
- Uninstall through the registered `UnDeploy.exe`/`UnDeploy64.exe` command with `/silent` to verify the uninstaller; the archived 6.x-era uninstallers delete the deployment files but leave the ARP key behind as a stale entry.
- For portable-only media, confirm that `/silent` performs the portable route and creates no ARP or registry state.
- Confirm whether unresolved file-type actions are intentionally omitted.
- Confirm installed executable architecture rather than using the stub alone.
- Test every nested prerequisite because `/silent` does not make a third-party setup unattended.
- Confirm post-install launch and pre-uninstall commands when `ExecutedPayloads` is nonempty.

## Known examples

- `Brinno.BrinnoVideoPlayer`

## Source references

- [DeployMaster manual](https://www.deploymaster.com/manual.html)
- [DeployMaster version history](https://www.deploymaster.com/history.html)
- [Archived DeployMaster builder media](https://web.archive.org/web/*/https://download.jgsoft.com/deploymaster/SetupDeployMasterDemo.exe)
