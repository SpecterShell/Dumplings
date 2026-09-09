# CreateInstall workflow

## When to use

Use `InstallerType: exe` for CreateInstall-generated setup EXEs. The parser covers structurally verified CreateInstall 5.9.0 through 8.11.2 media. The earlier Gentee Installer products distributed as `ci2000.exe`, `setupgen.exe`, and `sgpro.exe` are a separate unsupported family and must not be classified as CreateInstall.

## Detection

Call `Test-CreateInstall` or `Get-CreateInstallInfo`. Strong detection requires a valid PE containing one `.gentee` section, one bounded `Gentee Launcher\0` link header, a valid GE 4 program, and a referenced `MAINVAR` project table. A GEA archive is optional because CreateInstall can compile projects without packaged files. Product strings, PE version resources, `.ci` or `.ciq` names, and isolated GEA data are hints rather than sufficient installer-family evidence.

The parser validates GEA v1/v2 structures and expands Store, LZGE, and Gentee-modified PPMd-I blocks with bounded source-backed decoders. Do not pass GEA PPMd blocks to SharpCompress's standard `PpmdStream`: Gentee changed the PPMd-I model, allocator, framing, and solid continuation behavior.

## Static analysis

Read [CreateInstall parser internals](../../internals/createinstall/overview.md) before changing detection, extraction, bytecode decoding, operation routing, or parser limits.

### 1. Parse once

Load PackageModule once, call `Get-CreateInstallInfo` once, and reuse the returned object:

```powershell
. .\Modules\PackageModule\Index.ps1

$Info = Get-CreateInstallInfo -Path $InstallerPath
$Info | Select-Object DisplayName, DisplayVersion, Publisher, ProductCode, Scope, SupportedScopes, RequestedExecutionLevel, DefaultInstallLocation, InstallerSwitches, InstallModes, WritesAppsAndFeaturesEntry, AppsAndFeaturesEntries, GenteeExpressions, Diagnostics
```

`InstallerSwitches` comes from the compiled `MAINVAR.silentpar` value. Do not replace it with a guessed `-silent` switch. `InstallModes` includes silent modes only when that compiled value resolves deterministically.

### 2. Review payload and installation routes

Inspect the physical archive and the files selected by compiled `unpackgroup` or `unpackgroupex` calls:

```powershell
$Info | Select-Object GEA, CanExpand, ExtractedFiles, InstallGroupRoute, InstallGroupCalls, InstalledFiles, PayloadArchitectures, PayloadDependencyInfo
```

`ExtractedFiles` is the physical GEA catalog. `InstalledFiles` maps selected archive entries to their resolved destination paths and retains conditional routes as evidence. Architecture and PE dependency results are advisory payload evidence and are not automatic WinGet dependency mutations.

CreateInstall can contain no GEA archive. In that valid route, `CanExpand` is false, `ExtractedFiles` is empty, and the parser emits `CreateInstall.Archive.Absent` while retaining compiled metadata, ARP, registry, shortcut, and child-process evidence.

### 3. Inspect registry and ARP behavior

```powershell
$Info | Select-Object ArpEntries, RegistryWrites, ConditionalRegistryWrites, RegistryAssociationInfo, Protocols, FileExtensions
```

The parser reconstructs built-in `addremove`, `addremoveex`, and `addremoveext` writes and deterministic custom `regsetsex` writes. Custom writes execute later and override earlier values with the same hive, view, key, and value name. `ProductCode` is emitted only when the resulting deterministic registry state proves exactly one visible uninstall key. Conditional or unresolved registry writes remain separate and require VM validation.

The Add/Remove routine profile controls whether current-user scope, `InstallLocation`, `NoModify`, `NoRepair`, and `EstimatedSize` exist. Do not project newer values onto older compiled routines. Hidden records and records without `DisplayName` remain in `ArpEntries` but do not become visible Apps & Features entries.

### 4. Inspect system effects and prerequisite checks

```powershell
$Info.EnvironmentChanges | Select-Object Operation, Name, Value, Scope, Condition
$Info.PrerequisiteChecks | Select-Object Kind, Architecture, Versions, Combination, PackageDependencyCandidates, MayAbortInstallation, Condition
$Info.Services | Select-Object Operation, Name, DisplayName, BinaryPath, StartType, StartAfterInstall, Condition
$Info.Registrations | Select-Object Kind, Path, Name, RegistrationMethod, Framework, Condition
$Info.ScheduledTasks | Select-Object Operation, Name, Executable, Arguments, TriggerType, Condition
```

Environment evidence covers source-backed set operations and reports the structurally identical `globappend`/`globdel` route as `AppendOrRemove`; do not choose one operation without additional evidence. Prerequisite evidence identifies the Visual C++ generations and architecture checked by `checkredist`; `PackageDependencyCandidates` is advisory and must not be copied into a manifest without confirming that the checked runtime and package version satisfy the application. A non-empty `FailureMessage` means the runtime can prompt and abort when the check fails. Service evidence covers create, start, stop, and delete routes. Registration evidence covers fonts, COM/ActiveX and type libraries, and .NET `RegAsm` calls. Scheduled-task routes are identified through exact `citools.dll` imports rather than unstable linked object IDs.

### 5. Inspect shortcuts and nested execution

```powershell
$Info.Shortcuts | Select-Object Route, ShortcutPath, TargetPath, Arguments, WorkingDirectory, Condition
$Info.ExecutedPayloads | Select-Object Kind, Executable, NestedInstallerPath, Arguments, Wait, Condition
$Info.FileOperations | Select-Object Operation, Route, Source, Destination, OverwriteMode, Condition
$Info.Downloads | Select-Object Url, Destination, OverwriteMode, UsesTlsSupport, Condition
$Info.ArchiveOperations | Select-Object Format, Source, Destination, IncludeWildcard, ExcludeWildcard, Condition
$Info.ConfigurationChanges | Select-Object Operation, FilePath, Section, Key, Value, Utf, WriteBom, Condition
```

Shortcut evidence covers direct `shortcutex` calls and `shlist` table rows. Child execution covers direct `run` calls and `runmsiex` operations, including MSI action, quiet/passive, no-restart, logging, wait, and condition evidence. File evidence covers direct and list-based copies. Download evidence identifies external payloads that are absent from the GEA catalog. Archive evidence describes configured 7z, cabinet, and ZIP expansion but does not recursively add the nested archive contents to `InstalledFiles`. Configuration evidence covers source-backed INI set and delete records. Analyze a proven nested MSI or EXE separately before composing wrapper and nested switches.

### 6. Extract files when needed

```powershell
$Files = Expand-CreateInstallInstaller -Path $InstallerPath -DestinationPath $DestinationPath -VolumePath $CompanionDirectory -CollisionAction Rename
```

Omitting `-Name` extracts every archive entry. Use `-Name` for exact paths or wildcard selection. Omit `-VolumePath` when companion volumes are beside the main setup; otherwise point it at their directory. `GEA.VolumeFiles`, `MissingVolumes`, and `AllVolumesAvailable` show which one-based names were derived from the archive pattern. Missing companions preserve catalog and metadata evidence but disable extraction. Internal callers use `Rename`; interactive callers can retain the default prompt-on-collision behavior. Password-protected and unknown compression records are reported but not bypassed.

### 7. Resolve diagnostics and validate dynamic behavior

Use structured diagnostic IDs and affected fields rather than matching message text. `GenteeExpressions` contains each condition that the bounded evaluator could not decide, together with the guarded operation, operation-specific context, direct and transitive variable values, and a bounded summary of a referenced `@function`:

```powershell
$Info.GenteeExpressions | Select-Object Operation, Expression, ExpressionKind, Variables, ReferencedFunction, Context
```

CreateInstall's `ifcondition` accepts an optional leading `!`. A plain `#name#` condition reads the named macro and is true when its string is non-empty and is neither `0` nor `false`. An `@name` condition looks up and executes a zero-argument compiled Gentee function. `FunctionFound: true` identifies that function and exposes its object ID, literal strings, called functions, and at most 256 decoded commands. `CommandsTruncated: true` means the function requires deeper bytecode inspection.

Treat `Variables.Source: ProjectVariable` and `KnownMacro` as compiled static evidence. `RuntimeOrUnknown` means the value is populated at runtime or its source has not been proven; absence is not evidence that the condition is false. Identifier-like strings from an `@function` are conservative candidate variable names, so confirm how the function consumes them before deciding the branch. Use the function commands and local CreateInstall/Gentee sources to prove simple comparisons. If external calls, runtime probes, user choices, OS state, or unrecognized opcodes affect the result, retain both branches and follow [VM validation workflow](../../workflows/vm-validation.md).

Apply a human judgment only to the operation in `Context` and the fields in `AffectedFields`. Do not turn a conclusion about one condition into a package-wide scope, architecture, ARP, or dependency claim. Record the source or VM evidence used for the decision.

Unresolved macros outside conditions, ambiguous `AppendOrRemove` environment mutations, unsupported INI formatting or text transformations, external DLL side effects, password-protected archives, and reported nested archives whose contents affect installed state require additional evidence. Follow the VM workflow to confirm visible ARP state, scope, child execution, and silent behavior when static evidence remains incomplete.

## Manifest shape

CreateInstall is a generic EXE family, so WinGet supplies no family-specific switches or modes. Author only artifact-proven fields:

```yaml
Installers:
- Architecture: x86
  InstallerType: exe # CreateInstall
  Scope: machine
  InstallerUrl: https://example.com/Product-1.2.3-x86.exe
  InstallerSha256: <SHA256>
  InstallModes:
  - interactive
  - silent
  - silentWithProgress
  InstallerSwitches:
    Silent: -silent
    SilentWithProgress: -silent
  UpgradeBehavior: install
  ProductCode: <ProductCode>
```

This example applies only when the compiled project contains `silentpar=-silent` and deterministic registry evidence proves the shown scope and ProductCode. Omit unsupported, unresolved, empty, or advisory fields.

## Apps & Features

Prefer the parser's visible `ArpEntries` and `AppsAndFeaturesEntries`. Do not substitute PE metadata or a nested payload identity for the outer visible uninstall record. Existing accepted examples include `CreateInstall`, `CreateInstall Free`, `CreateInstall Light`, and `Balabolka`, but package history is corroborating evidence rather than a parser fallback.

## Scope and architecture

Use the deterministic uninstall hive and registry view first. A `requireAdministrator` PE manifest can establish machine-only elevation when no uninstall record is available, but an as-invoker launcher without registry evidence does not prove user scope. Use installed payload architecture evidence rather than assuming that the x86 CreateInstall runtime matches the application architecture.

## Known examples

- `CrossPlusA.Balabolka`
- `Novostrim.CreateInstall`
- `Novostrim.CreateInstall.Free`
- `Novostrim.CreateInstall.Lite`

## Source references

- [CreateInstall product site](https://www.createinstall.com/)
- [CreateInstall release history](https://www.createinstall.com/history.html)
- [CreateInstall help](https://www.createinstall.com/help/index.html)
- [Gentee GEA source index](https://www.gentee.com/source/src/projects/gea/index.htm)
