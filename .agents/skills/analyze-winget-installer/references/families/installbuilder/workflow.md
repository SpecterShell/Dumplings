# InstallBuilder workflow

## When to use

Use this workflow for BitRock, VMware InstallBuilder, and Backstaff InstallBuilder Windows media. The WinGet installer type is `exe`; `InstallBuilder` is the detected family and is not a schema value.

## Detection

Require a valid PE plus a bounded, parseable `project.xml` record and validated InstallBuilder container evidence. Legacy media embeds a Metakit VFS directly; later media normally adds a CookFS `CFS0002` payload. Product strings such as `BitRock`, `InstallBuilder`, `unattendedmodeui`, and `--mode unattended` are routing hints only and must not establish the family by themselves.

Read [InstallBuilder parser internals](../../internals/installbuilder/overview.md) before changing binary detection, extraction, or limits.

## Binary structure

InstallBuilder uses two verified physical payload routes. Both keep the compiled project in a TclKit/Metakit VFS; legacy media also stores application files there, while later media maps logical files onto independently compressed CookFS2 pages.

```text
LegacyMetakit
PE -> Metakit JL/LJ header -> commit root -> VFS catalog
                                +-- project.xml
                                +-- origindist
                                `-- stored or zlib contents:B payloads

CookFS2
PE -> project-owning Metakit VFS -> CookFS pages -> hashes -> sizes
                                      -> CFS2.200 index -> CFS0002 footer
```

Use [binary format](../../internals/installbuilder/binary-format.md) for exact offsets, adaptive Metakit descriptors, CookFS index records, compression framing, integrity records, and structural invariants. Use [format history](../../internals/installbuilder/format-history.md) before associating a route with a builder release.

## Static parsing

### 1. Parse once

Call `Get-InstallBuilderInfo` once and reuse the result for metadata, ARP, scope, switches, ordered registry operations, effective registry state, associations, shortcuts, project actions, environment and PATH changes, Windows services, scheduled tasks, fonts, shared-DLL reference counts, Windows ACL changes, executed payloads, runtime requirements, payload catalog, and diagnostics. `RegistryOperations` preserves every `registrySet` and `registryDelete`, while `RegistryWrites`, `RegistryDeletes`, and `EffectiveRegistryWrites` separate raw operation kinds from the deterministic final set state. `ProjectActions` preserves every compiled leaf action with its true XML element name, phase, lifecycle, literal and resolved parameters, conditions, and unresolved variables; password-like action properties are replaced with `<redacted>` while `SensitiveProperties` records their presence. `DynamicProjectLogic` collects exact unresolved rule XML, InstallBuilder expressions, script references, affected fields, referenced variable names, and the available deterministic or configured parameter values so an agent can analyze the source directly without executing Tcl. `PayloadFiles` contains the logical files selected for the default installation, `ConditionalPayloadFiles` contains files governed by unresolved component, platform, or runtime conditions, `ExcludedPayloadFiles` contains files excluded from the default selection, and `PackagedPayloadFiles` contains every logical file physically packaged. `PayloadCatalog` retains physical container paths, destination mappings, sizes, compression, conditions, and modification timestamps. `ExtractedFiles` describes everything the extractor can materialize, including `project.xml` and all packaged logical payloads:

```powershell
$Info = Get-InstallBuilderInfo -Path C:\Path\To\Installer.exe
$Info | Select-Object Family, FormatGeneration, ProductCode, DisplayName, DisplayVersion, Publisher, Scope, RegistryView, DefaultInstallLocation, InstallerSwitches, InstallModes, VisibleArpEntries, HiddenArpEntries, UncertainArpEntries, NestedInstallerCandidates, RuntimeRequirements, Diagnostics
$Info.DynamicProjectLogic | Select-Object EvidenceKind, OwnerType, Property, Phase, SourceCode, ReferencedVariables, VariableValues, AffectedFields
```

Do not invoke the installer with `--help`; some runtimes show a transient GUI window. Do not infer fields from that UI when the compiled project provides stronger evidence.

### 2. Interpret project and ARP evidence

The recovered project is authoritative for `shortName`, `fullName`, `version`, `vendor`, installation parameters, uninstaller policy, literal `registrySet` and `registryDelete` actions, and supported modes. Identity fields are recursively resolved from deterministic project substitutions before they are returned; an unresolved runtime expression produces a null field plus a field-scoped diagnostic instead of leaking `${...}` into a manifest. The parser applies documented InstallBuilder defaults when the project omits them.

For a normal installation, the built-in Windows ARP route requires both `createUninstaller` and `createWindowsARPEntry`. It writes beneath HKLM using `windowsARPRegistryPrefix`, whose documented default is `${project.fullName} ${project.version}`; `productDisplayName` defaults to `${product_fullname}`. The parser reconstructs the fixed `NoModify` and `NoRepair` values and the configured display, publisher, icon, location, URL, comments, contact, help, and quoted uninstall-command values. `EstimatedSize` and `InstallDate` are runtime values and remain unset during static analysis.

An unconditional literal `registrySet` action in a persistent installation phase can add, override, or hide ARP evidence, and a later `registryDelete` can remove a value or an entire key. The parser evaluates `preInstallationActionList`, `readyToInstallActionList`, folder-owned `actionList`, `postInstallationActionList`, and `postUninstallerCreationActionList` in runtime order and exposes the surviving sets through `EffectiveRegistryWrites`. Folder-owned actions run immediately after that folder is unpacked and are installation effects rather than unknown-phase records. Registry operations retain raw and deterministically resolved key, name, and value forms; association projection uses only the effective resolved state. Operations from initialization, page-only, rollback, failure, and uninstallation phases remain in `RegistryOperations`, but they are excluded from authoritative ARP and association projection. The built-in ARP entry is created with the uninstaller after `postInstallationActionList`; a deterministic delete in `postUninstallerCreationActionList` therefore changes the final ARP projection, while a conditional delete makes it uncertain. Any nonzero numeric `SystemComponent` is hidden. `VisibleArpEntries` supplies WinGet-facing evidence; `HiddenArpEntries` and `UncertainArpEntries` are retained for investigation but are not projected into `ProductCode` or `AppsAndFeaturesEntries`. Conditional Tcl actions remain diagnostics and add the affected conclusions to `UnresolvedFields`. Upgrade installers can update an existing registration instead of creating a new one, so do not fabricate a ProductCode when no authoritative key is resolved.

`associateWindowsFileExtension` is a separate native action that registers one ProgID for a space-separated extension list; `removeWindowsFileAssociation` removes the corresponding scope/extension/ProgID mapping. `FileExtensionAssociations` retains both operation kinds with their ProgID, friendly name, MIME type, icon, scope, verbs, executable, arguments, phase, conditions, and unresolved variables, while `EffectiveAssociations` contains the deterministic final native state. An extension contributes to `FileExtensions` only when a surviving add is proven; unresolved optional command, icon, or description values do not erase a proven extension registration. Uninstallation and conditional actions remain evidence. `EnvironmentChanges`, `PathChanges`, `WindowsServices`, `ScheduledTasks`, `FontChanges`, `SharedDllChanges`, and `WindowsAclChanges` similarly preserve lifecycle, condition state, unresolved variables, and whether the action applies to the default installed state. `setEnvironmentVariable` modifies only the installer process and never represents persistent installed state, while `addEnvironmentVariable`, `deleteEnvironmentVariable`, `addDirectoryToPath`, and `removeDirectoryFromPath` are persistent actions. Service and scheduled-task records never expose configured passwords; they report only `PasswordConfigured`.

Use `AppsAndFeaturesEntries` exactly as returned after reviewing diagnostics. Do not substitute PE version strings, a nested payload identity, or a guessed `<shortName> <version>` key.

### 3. Determine scope, elevation, and architecture

Use the PE requested execution level, `requireInstallationByRootUser`, literal HKLM/HKCU actions, and the built-in ARP route together. `requireAdministrator` or a proven HKLM-only route establishes machine scope. A project branching on `${installer_is_root_install}` with both HKCU and HKLM uninstall paths is conditional dual-scope evidence and needs VM validation before authoring separate entries. `installationScope` controls Start Menu and desktop shortcut ownership; it does not establish package installation or ARP scope.

Use `windows64bitMode` to select the registry and Program Files view for an x86 launcher. Native Windows x64 runtimes were introduced in InstallBuilder 19.5; a native x64 PE also establishes the 64-bit view. `PrimaryExecutableCandidates` identifies packaged executables referenced by shortcuts or installation/final-page execution actions. Extract and inspect those candidates with the shared PE functions to determine installed application architecture; never assume that it matches the launcher.

### 4. Review switches and modes

InstallBuilder is a generic EXE to WinGet, so no family defaults are supplied by the client. Family-only analyzer hints deliberately omit modes and switches. Suggest them only after the compiled project proves the corresponding behavior:

- `--mode unattended --unattendedmodeui none` is the silent switch for CookFS-era runtimes when `unattended` is allowed; the explicit UI override prevents a project-level `minimal` or `minimalWithDialogs` default from making WinGet's silent mode visible.
- `--mode unattended --unattendedmodeui minimal` is the progress mode when unattended installation is allowed.
- Legacy Metakit-only 3.x and 4.x media document `--mode unattended` but predate `unattendedModeUI`; suggest silent mode only, without `silentWithProgress`, for that route.
- The install-location switch comes from the `installdir` parameter's `cliOptionName`; the runtime uses the parameter name when a custom parameter omits `cliOptionName`. The normal documented mapping is `--prefix "<INSTALLPATH>"`.
- `--debugtrace "<LOGPATH>"` writes the installer log.

Do not add silent modes when the project excludes unattended mode. Review license, parameter, and action rules because custom project logic can still make an otherwise recognized switch unusable.

Review `RuntimeRequirements` before adding dependencies. Structured `autodetectJava` actions expose accepted Java versions, bitness, vendor, and JRE/JDK requirements; `autodetectDotNetFramework` exposes accepted .NET Framework minimum and maximum versions; Windows-version comparison rules remain explicit condition evidence. These records do not prove a matching WinGet dependency package and are not authored automatically.

The static condition evaluator handles the documented portable subset: `isTrue`, `isFalse`, `compareText`, `compareTextLength`, `compareValues`, `compareVersions`, `platformTest`, `regExMatch`, nested rule groups, negation, and all/any list logic. Comparisons resolve only deterministic project variables. Tcl-specific regular-expression constructs, target Windows-version tests, filesystem/registry probes, scripts, and host-dependent rules remain `Unknown`; never turn those conditions into unconditional manifest evidence. Inspect each corresponding `DynamicProjectLogic` record directly: `SourceCode` is the exact project expression or rule XML, `VariableValues` distinguishes deterministic project context from mutable parameter defaults and runtime-only values, and `AffectedFields` identifies which manifest conclusions depend on the result. Do not pipe this source to `Invoke-Expression`, `tclsh`, the installer runtime, or another evaluator on the host. Resolve simple logic manually when its inputs are complete; otherwise preserve the conditional evidence and validate the affected operation in the VM.

### 5. Inspect or extract payloads

Both supported payload routes expose the complete packaged catalog and classify its default-selection state. Legacy Metakit media reads the structured TclKit `origindist` record and compiled project folder destinations, excluding the Tcl/Tk runtime files stored beside the package. Later CookFS media maps physical component/folder paths through compiled folder destinations, component selection, platform lists, and inherited rules. Omit `-Name` to extract all packaged logical payload files or select one path or wildcard; extraction does not silently discard optional or conditionally selected files. Split CookFS `___bitrockBigFileN` records are reassembled under the original logical name. When an executable contains multiple Metakit VFS records, the parser selects the one that actually owns the required `project.xml` or `origindist` entry instead of relying on physical order.

When shortcut or execution actions identify the installed application's primary executable, opt into bounded payload analysis to obtain architecture and PE dependency evidence without manually extracting the whole package. The parser materializes at most four source-referenced primary executables plus bounded adjacent DLL, `.deps.json`, and `.runtimeconfig.json` sidecars, and removes the temporary analysis tree afterward. This can be expensive for large applications, so ordinary metadata parsing leaves `PayloadArchitectureInfo`, `PayloadArchitectures`, `PayloadDependencyInfo`, and `PayloadAnalysisFiles` empty:

```powershell
$Info = Get-InstallBuilderInfo -Path C:\Path\To\Installer.exe -AnalyzePrimaryExecutables -MaximumPayloadAnalysisBytes 536870912
$Info | Select-Object PayloadArchitectures, PayloadAnalysisFiles, PayloadDependencyInfo
```

```powershell
Expand-InstallBuilderInstaller -Path C:\Path\To\Installer.exe -DestinationPath C:\Output -CollisionAction Rename
Expand-InstallBuilderInstaller -Path C:\Path\To\Installer.exe -DestinationPath C:\Output -Name 'payload/setup.msi' -CollisionAction Rename
```

Legacy Metakit `contents` records may be stored or zlib-compressed. CookFS pages may be stored, Deflate-compressed, BZip2-compressed, or use the source-backed unencrypted LZMA handler. The parser decodes the index metadata, preserves each file's 64-bit Unix modification time, restores it during extraction, and verifies every decoded page against the indexed MD5 or CookFS CRC32 record before writing payload bytes. All supported routes are bounded and covered by extraction tests. Encrypted or unknown custom CookFS records require the project password and remain unsupported. Do not treat a metadata-only parse as complete payload evidence when `PayloadFiles` remains unresolved.

## Manifest shape

Use the artifact-specific fields returned by `Get-WinGetInstallerAnalysis`; the following shape illustrates a project that actually proves all listed modes and switches:

```yaml
Installers:
- Architecture: x64
  InstallerType: exe # InstallBuilder
  Scope: machine
  InstallerUrl: https://example.com/Product-1.2.3-x64.exe
  InstallerSha256: <SHA256>
  InstallModes:
  - interactive
  - silent
  - silentWithProgress
  InstallerSwitches:
    Silent: --mode unattended --unattendedmodeui none
    SilentWithProgress: --mode unattended --unattendedmodeui minimal
    InstallLocation: --prefix "<INSTALLPATH>"
    Log: --debugtrace "<LOGPATH>"
```

Keep `ProductCode`, `AppsAndFeaturesEntries`, `ElevationRequirement`, and registry-view-sensitive fields only when the project provides authoritative evidence.

## Apps & Features

Use only `VisibleArpEntries` for WinGet-facing identity. Prefer the surviving visible built-in entry; if project actions remove or hide it, the parser can promote exactly one deterministic custom visible entry. Keep `HiddenArpEntries` and `UncertainArpEntries` as evidence, and do not infer ProductCode from `SystemComponent` rows, upgrade-only behavior, PE version strings, or nested payload names. See [uninstaller and ARP internals](../../internals/installbuilder/uninstaller-and-arp.md) for write order, registry view, value construction, and primary-entry selection.

## Scope and architecture

Treat package scope, shortcut scope, registry view, setup launcher architecture, and installed payload architecture as independent facts. Derive package scope from effective ARP and registry behavior plus elevation evidence. Use `windows64bitMode` and the PE machine for registry view. Analyze a source-referenced installed executable when the manifest architecture cannot be established from artifact selection or trusted publisher evidence. See [setup runtime](../../internals/installbuilder/setup-runtime.md) for the complete decision model.

## VM validation

Follow [VM validation workflow](../../workflows/vm-validation.md). InstallBuilder-specific checks are the exact visible and hidden ARP tuples, uninstall-command quoting, runtime `EstimatedSize` and `InstallDate`, unattended and minimal-UI behavior, custom parameters, install-location override, upgrade-mode reuse of prior ARP state, component selection, conditional Tcl actions, and whether `runProgram` or nested installer actions own the visible entry. Compare parser phase classification with the installed-state transition when a project writes registry values outside the normal installation action lists. Treat final-page application launches separately from installation-time nested payload execution.

## Known examples

- `Phrase.Phrase`
- `Lansweeper.LsAgent`
- `JinweiZhiguang.Lanhu.Photoshop`
- `Hex-Rays.IDA.Free`
- `LiteratureAndLatte.Scrivener`
- `OpenSourcePhysics.Tracker`
- `PawelSalawa.SQLiteStudio`
- `ApacheFriends.Xampp.8`
- `PostgreSQL.PostgreSQL.9`
- `PostgreSQL.PostgreSQL.10`
- `PostgreSQL.PostgreSQL.11`
- `PostgreSQL.PostgreSQL.12`
- `PostgreSQL.PostgreSQL.13`
- `PostgreSQL.PostgreSQL.14`
- `PostgreSQL.PostgreSQL.15`
- `PostgreSQL.PostgreSQL.16`
- `PostgreSQL.PostgreSQL.17`
- `PostgreSQL.PostgreSQL.18`
- `Autodesk.LicensingService`
- `Graphisoft.BIMxDesktopViewer`

## Source references

- [InstallBuilder downloads](https://installbuilder.com/download-step-2)
- [InstallBuilder changelog](https://installbuilder.com/changelog)
- [InstallBuilder user guide](https://releases.installbuilder.com/installbuilder/docs/installbuilder-userguide/)
- [InstallBuilder internals overview](../../internals/installbuilder/overview.md)
- [InstallBuilder coverage](../../internals/installbuilder/coverage.md)
