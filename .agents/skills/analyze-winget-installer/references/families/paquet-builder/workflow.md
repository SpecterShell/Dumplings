# Paquet Builder workflow

## When to use

Use this workflow after structural analysis identifies Paquet Builder. Author the outer package as `InstallerType: exe`; Paquet Builder is a generic EXE family rather than a WinGet known installer type.

## Detection

Run `Get-WinGetInstallerAnalysis -Path $InstallerPath` for routing or call `Get-PaquetBuilderInfo -Path $InstallerPath` when the family is already known. A product string such as `Paquet Builder`, `G.D.G. Software`, or `installpackbuilder.com` is only a routing hint. Confirmation requires one of the supported resource/archive structures described in [Paquet Builder parser internals](../../internals/paquet-builder/overview.md).

## Binary structure

Paquet Builder media falls into five verified structural routes. Classic 2.6 media uses PE `RCDATA`, an overlay GPacker/LZHUF control stream, and a following ZIP package. Version 2.7 uses an `ISFX` descriptor to locate a Microsoft Cabinet. Version 2.8 uses one 7z payload and an `ENG` PE runtime resource. Version 2.9 keeps the one-archive form but stores a raw-LZMA `ENG` runtime beginning with `GP`. Version 3 and later use separate payload and runtime 7z archives; the runtime archive contains `pbfprop.dat` and `PBCore*.dll`.

```text
Classic2                  Cabinet2                  Legacy2 / Resource2        Split3
PE                        PE                        PE                         PE + PBCore.SetVar calls
+-- RCDATA metadata       +-- RCDATA/ENG            +-- RCDATA/ENG             `-- overlay
`-- overlay               +-- RCDATA/ISFX           `-- overlay/7z payload         +-- payload 7z
    +-- GPacker control   `-- MSCF cabinet                                          `-- runtime 7z
    `-- ZIP package
```

## Step 1: parse once

```powershell
$Info = Get-PaquetBuilderInfo -Path $InstallerPath
$Info | Select-Object StructuralRoute, FormatGeneration, DisplayName, DisplayVersion, Publisher, ProductCode, UpgradeCode, Scope, SupportedScopes, DefaultInstallLocation, RequestedExecutionLevel, SupportsSilentInstallation, InstallerSwitches, InstallModes, AppsAndFeaturesEntries, Diagnostics, UnresolvedFields
```

Reuse `$Info`. Do not call each `Read-*FromPaquetBuilder` compatibility function after `Get-PaquetBuilderInfo`.

## Step 2: follow the structural route

For `ClassicResourcePackage`, inspect `ClassicEnvelope`, `PayloadFiles`, and extraction diagnostics. The parser validates the GPacker control CRC and exact ZIP boundary and can extract `SETUP*.GAF` and the setup runtime. It does not yet map GAF members to installed destinations or infer ARP and switch behavior from the decoded control bytes.

For `CabinetPackageRuntime`, inspect `IsfxDescriptor`, `NestedMsiPath`, `ProductCode`, `UpgradeCode`, and `AppsAndFeaturesInstallerType`. The verified 2.7 route gives exact package and cabinet offsets, and a sole nested MSI may own the ARP identity. The pre-cabinet configuration remains unresolved.

For `LegacyEmbeddedPeRuntime`, inspect `NestedMsiPath`, `ProductCode`, `UpgradeCode`, and `AppsAndFeaturesInstallerType`. The verified 2.8 builder installer is an EXE wrapper around one MSI and one external cabinet, so the nested MSI owns the ARP identity.

For `CompressedResourceRuntime`, use `PayloadFiles`, `RuntimeResourceInfo`, and extraction results. The parser decodes the raw-LZMA runtime PE and exports its separately sized tail, but it does not infer ARP, scope, or switch behavior from opaque trailing state. Resolve those fields through VM validation when the parser leaves them unresolved.

For `SplitArchiveRuntime`, inspect `CompiledVariableAssignments`, `RuntimeCatalog`, `PayloadFiles`, and `RuntimeFiles`. Literal `PBCore.SetVar` calls can prove `PBINSTALLSCOPE`, `DESTPATH`, and enabled silent handling. A literal full uninstall-key path can prove `ProductCode`; arbitrary native actions remain outside the static model.

## Step 3: extract only the needed group

```powershell
Expand-PaquetBuilderInstaller -Path $InstallerPath -DestinationPath $DestinationPath -ArchiveKind Payload -CollisionAction Rename
Expand-PaquetBuilderInstaller -Path $InstallerPath -DestinationPath $DestinationPath -ArchiveKind Runtime -CollisionAction Rename
```

Omit `-Name` to extract all entries. Use `-ArchiveKind All` only when both application and runtime files are needed; the function keeps them under separate `Payload` and `Runtime` directories. Classic media exports its validated outer ZIP entries, Cabinet 2.7 media expands its exact ISFX-declared cabinet range, and legacy/resource generations expose `ENG` plus other `RCDATA` evidence through the runtime route. Resource 2.9 emits the decoded runtime as `ENG.exe` and its opaque tail as `ENG.tail.bin`.

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

Use the parser's nested MSI or literal uninstall-key evidence for `ProductCode` and `AppsAndFeaturesEntries`. Do not substitute a random MSI found among later application payload files. Keep unresolved ARP fields out of a new manifest until VM evidence identifies the visible uninstall entry.

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
