# DeployMaster workflow

## When to use

Use `InstallerType: exe` for installers built with DeployMaster. WinGet has no DeployMaster-specific defaults, so every non-default mode and switch must be supported by static documentation or VM evidence.

## Detection

Strong evidence is a validated DeployMaster package locator at file offset `0x80`, a matching CRC32-protected package region, and DeployMaster PE version comments. Do not classify an arbitrary LZMA overlay from marker strings alone.

## Static analysis

Read [DeployMaster Parser Internals](../../internals/deploymaster/overview.md) before changing detection, extraction, binary decoding, or parser limits.

```powershell
. .\Modules\PackageModule\Index.ps1
$Info = Get-DeployMasterInfo -Path $InstallerPath
```

### Parse once

`Get-DeployMasterInfo` validates the locator, file size, CRC32, current or legacy control-header layout, and structured stored/LZMA metadata. Reuse the returned object instead of calling multiple `Read-*FromDeployMaster` helpers:

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

Expansion never starts the installer. It writes each decoded runtime core, structured metadata block, and package file beneath separate safe paths:

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

The structured identity block supplies `DisplayName`, `DisplayVersion`, `Publisher`, release date, copyright, publisher and package URLs, readme and license filenames, architecture-specific support DLLs, and separate user/machine install locations. DeployMaster's built-in uninstaller uses the display name as its uninstall-key identity, so the parser returns that value as `ProductCode` and emits built-in ARP writes. A support DLL can veto installation, add folders, validate identity input, modify registry behavior, and run custom completion code; inspect the extracted DLL or validate the package in a VM whenever `SupportDlls` is nonempty.

`CustomRegistryWrites` and `DeletedRegistryKeys` contain the recursive Registry-tab program. Literal `REG_SZ`, `REG_DWORD`, and `REG_BINARY` writes are decoded. An unconditional custom write below an uninstall key is also projected into `AppsAndFeaturesEntries`; keep-existing and unresolved conditional behavior remains raw evidence for VM validation. For `Brinno.BrinnoVideoPlayer`, VM evidence confirms an x86 HKLM EXE ARP entry keyed `Brinno Video Player` with no `WindowsInstaller` value.

### Resolve file associations

`FileAssociations` contains each literal extension, description, default flag, icon indexes, action names, executable indexes, and parameters. Include `FileExtensions` when the literal extensions are valid.

An executable index of `-1` means the action did not resolve to a packaged file and should not be treated as an installed open command. Literal protocol and file-extension registrations from the Registry tab are merged with the dedicated file-type records; dynamic application registration still requires VM evidence.

### Review behavior and prerequisites

`Components` records default and user-selectable state plus component dependencies. `InstallationFolders`, `InstalledFiles`, `Shortcuts`, and `UrlShortcuts` preserve component ownership and catalog indexes. `ExecutedPayloads` resolves exact post-install and pre-uninstall file indexes; analyze those payloads separately before assigning wrapper behavior.

`UpdatePolicy` reports whether the package deletes obsolete files, requires a compatible previous release, and blocks installation while configured window classes or captions are present. Patch explanatory text is returned as both one string and normalized lines. Treat these running-application checks as potential unattended blockers and verify them in the VM when the application may already be open.

`Prerequisites` contains the built-in .NET Framework record and custom third-party setup descriptors. `DotNetFrameworkRequirement` names the builder's compatible 1.0 through 3.5 targets, minimum 4.x version, optional automatic-installer filename, and fallback URL; its trailing undocumented bytes remain raw. Silent DeployMaster cannot suppress prompts from nested prerequisite installers, so validate the complete chain when prerequisites are present.

`PackageSettings` reports identity prompts and the documented portable-installation settings. `PortableInstallationMode` is `Never`, `UserChoice`, or `Always`; `PortableMarkerMode` controls `RemovableDrive.sys`; `PortableAllowAnyDrive` and `PortableDefaultFolder` describe the portable destination UI. A portable path copies files without ARP, registry, shortcut, association, prerequisite, or elevation effects, but the same package may still support a normal installation. Do not classify the artifact itself as a WinGet portable installer unless the intended command path is proven.

`CommandLineSwitches` records the complete source-documented runtime interface. In addition to `/s` and `/silent`, DeployMaster supports `/nodesktop`, `/temp`, `/appfolder`, `/appcommonfolder`, `/appmenu`, and `/userdata`; mixed x86/x64 packages also accept `/32`. `UninstallerSwitches` records the generated uninstaller's `/silent` mode. Only project schema fields into a WinGet manifest when they serve that package's installation behavior.

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
- Compare HKCU and both HKLM uninstall views with the parsed scope.
- Confirm whether unresolved file-type actions are intentionally omitted.
- Confirm installed executable architecture rather than using the stub alone.
- Test every nested prerequisite because `/silent` does not make a third-party setup unattended.
- Confirm post-install launch and pre-uninstall commands when `ExecutedPayloads` is nonempty.

## Known examples

- `Brinno.BrinnoVideoPlayer`
