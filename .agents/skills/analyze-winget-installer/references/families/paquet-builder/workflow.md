# Paquet Builder workflow

## When to use

Use this workflow after structural analysis identifies Paquet Builder. Author the outer package as `InstallerType: exe`; Paquet Builder is a generic EXE family rather than a WinGet known installer type.

## Detection

Run `Get-WinGetInstallerAnalysis -Path $InstallerPath` for routing or call `Get-PaquetBuilderInfo -Path $InstallerPath` when the family is already known. A product string such as `Paquet Builder`, `G.D.G. Software`, or `installpackbuilder.com` is only a routing hint. Confirmation requires one of the supported resource/archive structures described in [Paquet Builder parser internals](../../internals/paquet-builder/overview.md).

## Binary structure

Paquet Builder media falls into five verified structural routes. Classic 2.6 media uses PE `RCDATA`, an overlay GPacker/LZHUF control stream, a packed setup controller, and an ordered GAF payload. Version 2.7 uses an `ISFX` descriptor to locate an encoded `@GDG` program and Microsoft Cabinet. Version 2.8 replaces the program compression with safe `AP32`/aPLib and uses one 7z payload. Version 2.9 stores an outer raw-LZMA `ENG` runtime and an inner transformed `GP`/LZMA package program. Version 3 and later use separate payload and runtime 7z archives; the runtime archive contains `pbfprop.dat` and `PBCore*.dll`. Archived 3.0 and 3.2 launchers additionally wrap their native image in UPX/LZMA, which the parser reconstructs in memory after validating its bounds and checksums.

```text
Classic2                  Cabinet2                  Legacy2 / Resource2          Split3
PE                        PE                        PE                           PE + optional UPX/LZMA + PBCore.SetVar calls
+-- RCDATA metadata       +-- RCDATA/ENG            +-- RCDATA/ENG               `-- overlay
`-- overlay               +-- RCDATA/ISFX           |   `-- AP32 or GP/LZMA           +-- payload 7z
    +-- GPacker control   +-- @GDG / GINFOS         `-- overlay/7z payload           `-- runtime 7z
    `-- ZIP + GAF         `-- MSCF cabinet
```

Use the internal reading path when developing or reviewing the parser: [architecture](../../internals/paquet-builder/architecture.md), [format history](../../internals/paquet-builder/format-history.md), [binary format](../../internals/paquet-builder/binary-format.md), [metadata model](../../internals/paquet-builder/metadata-model.md), [setup runtime](../../internals/paquet-builder/setup-runtime.md), [uninstaller and ARP](../../internals/paquet-builder/uninstaller-and-arp.md), [parser implementation](../../internals/paquet-builder/parser-implementation.md), and [coverage](../../internals/paquet-builder/coverage.md).

## Step 1: parse once

```powershell
$Info = Get-PaquetBuilderInfo -Path $InstallerPath
$Info | Select-Object StructuralRoute, FormatGeneration, DisplayName, DisplayVersion, Publisher, ProductCode, UpgradeCode, Scope, SupportedScopes, DefaultInstallLocation, DisplayIcon, UninstallString, RequestedExecutionLevel, SupportsSilentInstallation, InstallerSwitches, InstallModes, AppsAndFeaturesEntries, PackageConfiguration, PackageScript, RegistryWrites, Shortcuts, FileOperations, UninstallOperations, Diagnostics, UnresolvedFields
```

Reuse `$Info`. Do not parse the installer again through individual `Read-*FromPaquetBuilder` functions after `Get-PaquetBuilderInfo`.

## Step 2: follow the structural route

For `ClassicResourcePackage`, inspect `ClassicEnvelope`, `ClassicCatalog`, `InstalledFiles`, `RegistryWrites`, `Shortcuts`, and `ExecutedPayloads`. The parser validates the GPacker control CRC, exact ZIP boundary, every packed controller record, the complete GAF member sequence, and each installed file's size and Adler-32. A complete controller can prove machine state and associations. The absolute `{app}` root and ProductCode remain unresolved when the catalog does not contain them.

For `CabinetPackageRuntime`, inspect `IsfxDescriptor`, `PackageConfiguration`, `PackageScript`, `NestedMsiPath`, `ProductCode`, `UpgradeCode`, and `AppsAndFeaturesInstallerType`. The verified 2.7 route gives exact configuration and cabinet offsets. The parser decodes the transformed `@GDG` resource table and GINFOS program. A sole nested MSI may own ARP identity; a non-MSI child remains separate.

For `LegacyEmbeddedPeRuntime`, inspect `PackageConfiguration`, `PackageScript`, `NestedMsiPath`, `ProductCode`, `UpgradeCode`, and `AppsAndFeaturesInstallerType`. The parser verifies both AP32 CRC values, decodes the aPLib stream, and parses the same named-resource and script model. The verified 2.8 builder installer is an EXE wrapper around one MSI and one external cabinet, so the nested MSI owns ARP identity.

For `CompressedResourceRuntime`, inspect `RuntimeResourceInfo`, `PackageConfiguration`, `PackageScript`, `RegistryWrites`, `FileExtensions`, and `NestedMsiPath`. The parser decodes both the outer runtime PE and inner GP/LZMA named-resource table. It recognizes script-selected MSI installation and literal generic-EXE ARP rows. Resolve only fields listed in `UnresolvedFields`; the package tail is no longer opaque.

For `SplitArchiveRuntime`, inspect `CompiledVariableAssignments`, `PackedPeInfo`, `RuntimeCatalog`, `PayloadFiles`, and `RuntimeFiles`. Literal `PBCore.SetVar` calls can prove `PBINSTALLSCOPE`, `DESTPATH`, and enabled silent handling. A literal full uninstall-key path can prove `ProductCode`; arbitrary native actions remain outside the static model. `PackedPeInfo` records the accepted UPX header, sizes, filter, and Adler-32 values when the extra reconstruction layer was required.

## Step 3: extract only the needed group

```powershell
Expand-PaquetBuilderInstaller -Path $InstallerPath -DestinationPath $DestinationPath -ArchiveKind Payload -CollisionAction Rename
Expand-PaquetBuilderInstaller -Path $InstallerPath -DestinationPath $DestinationPath -ArchiveKind Runtime -CollisionAction Rename
```

Omit `-Name` to extract all entries. Use `-ArchiveKind All` only when both application and runtime files are needed; the function keeps them under separate `Payload` and `Runtime` directories. Classic media extracts installed GAF members to their catalogued destinations, Cabinet 2.7 media expands its exact ISFX-declared cabinet range, and legacy/resource generations expose `ENG` plus other `RCDATA` evidence through the runtime route. Resource 2.9 emits the decoded runtime as `ENG.exe` and preserves its original encoded package configuration as `ENG.tail.bin`; use `PackageConfiguration` for the decoded semantic view.

## Step 4: author switches and modes

WinGet has no Paquet Builder defaults. Add `InstallerSwitches` and `InstallModes` only when `$Info.SupportsSilentInstallation` is true and the parser returns exact switch evidence. Current verified media uses `/s` for silent installation. Marker-only family detection must not add `/s`, `/silent`, or `silentWithProgress`.

```yaml
InstallerType: exe
InstallModes:
- interactive
- silent
InstallerSwitches:
  Silent: /s
```

The documented package exit codes are `0` for success, `1` for decompression failure, `2` for cancellation, and `3` for an unexpected fatal error. These are not extra success codes.

## Step 5: author scope and Apps & Features

`PBINSTALLSCOPE=0` proves user scope and `PBINSTALLSCOPE=1` proves machine scope. Both values indicate a conditional or dual-scope package, so author separate entries only after confirming how the package selects a route. A `requireAdministrator` manifest can prove machine scope when no compiled scope assignment is available.

Use the parser's nested MSI, literal uninstall-row, `UNINSTKEY`/`UNINSTALLINFO`, or modern literal uninstall-key evidence for `ProductCode` and `AppsAndFeaturesEntries`. A 2.9 MSI is selected only when `PBExecMSI` names its exact payload path. Do not substitute another MSI found among application files. Keep unresolved ARP fields out of a new manifest until VM evidence identifies the visible uninstall entry.

## VM validation

Follow [VM validation workflow](../../workflows/vm-validation.md). For Paquet Builder, compare user and machine launches when `SupportedScopes` contains both values, capture the visible uninstall key and registry view, test only the switches returned for the exact artifact, and record all four documented exit-code paths when practical.

## Known examples

- `GDGSoftware.PaquetBuilder`; current media uses the split-archive route and the literal uninstall identity `GDGSoftPB2019`.

## Source references

- [Paquet Builder package command line](https://www.installpackbuilder.com/help/automation-command-line/package-installer-command-line)
- [Archived download.installpackbuilder.com builder installers](https://web.archive.org/web/*/https://download.installpackbuilder.com/pbinst.exe)
- [Archived installpackbuilder.com builder installers](https://web.archive.org/web/*/http://www.installpackbuilder.com/files/pbinst.exe)
- [Archived gdgsoft.com builder installers](https://web.archive.org/web/*/http://www.gdgsoft.com/files/pbinst.exe)
- [Archived gdgsoftware.com x86 builder installers](https://web.archive.org/web/*/https://download.gdgsoftware.com/pb/pbinst.exe)
- [Archived files.gdgsoft.com builder installers](https://web.archive.org/web/*/https://files.gdgsoft.com/pb/pbinst.exe)
- [Archived gdgsoftware.com x64 builder installers](https://web.archive.org/web/*/https://download.gdgsoftware.com/pb/pbinst64.exe)
