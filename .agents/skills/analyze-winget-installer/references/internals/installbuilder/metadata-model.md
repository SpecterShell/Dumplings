# InstallBuilder metadata model

## Project recovery and XML

The compiled `project.xml` is the central semantic record. Dumplings prefers the exact record owned by a validated Metakit VFS, decodes it as strict UTF-8, and parses it as XML. A bounded zlib candidate is accepted only as the weaker `ProjectRecord` route when the VFS cannot be decoded. The parser never invokes Tcl or the installer runtime while reading the project.

The XML root must be `project`. Its descendants combine package identity, build-time defaults, parameters, components, folders, files, pages, action lists, rules, requirements, and platform settings. Element order matters for action execution and registry state, so ordered collections remain ordered after parsing.

## Project defaults

InstallBuilder omits many properties when they retain runtime defaults. The parser applies only documented defaults needed for interpretation.

| Property | Default | Meaning |
| --- | --- | --- |
| `installationType` | `normal` | Normal installation rather than upgrade-only behavior |
| `createUninstaller` | `1` | Generate the project uninstaller |
| `createWindowsARPEntry` | `1` | Create the built-in Windows ARP row when the uninstaller route is active |
| `windowsARPRegistryPrefix` | `${project.fullName} ${project.version}` | Built-in uninstall subkey name |
| `productDisplayName` | `${product_fullname}` | Built-in ARP `DisplayName` |
| `uninstallerName` | `uninstall` | Generated uninstaller basename |
| `uninstallerDirectory` | `${installdir}` | Generated uninstaller directory |
| `requireInstallationByRootUser` | `0` | Additional root or administrator requirement |
| `requestedExecutionLevel` | `requireAdministrator` | Windows launcher execution level when PE evidence is unavailable |
| `windows64bitMode` | `0` | Use the native 64-bit Windows paths and registry view from an x86 launcher |
| `installationScope` | `auto` | Shortcut ownership policy, not package scope |
| `unattendedModeUI` | `none` | UI style for unattended mode |

Empty defaults for icon, comments, contact, information URL, and help URL remain empty rather than being synthesized from unrelated package metadata.

## Identity fields

| Result | Primary project source | Interpretation |
| --- | --- | --- |
| `DisplayName` | `fullName` | Installed package display identity after deterministic substitution |
| `DisplayVersion` | `version` | Package version after deterministic substitution |
| `Publisher` | `vendor` | Installed package publisher, not the builder producer |
| short identity | `shortName` | Variable and storage identity used by project expressions |
| `ProjectSchemaVersion` | `projectSchemaVersion` | Project vocabulary evidence, not a container dispatch key |

Identity values may reference other deterministic project values. Dumplings resolves substitutions recursively for at most 16 passes. A remaining `${...}` token causes the affected identity field to be null and produces a field-scoped diagnostic; the raw expression remains available as evidence.

## Variable namespaces

InstallBuilder expressions use `${name}` substitutions. The parser provides a case-insensitive dictionary of source-backed values but does not create values from the parser host.

| Namespace | Examples | Source |
| --- | --- | --- |
| Project identity | `${project.shortName}`, `${project.fullName}`, `${project.version}`, `${project.vendor}` | Compiled project |
| Product aliases | `${product_shortname}`, `${product_fullname}`, `${product_version}` | Resolved project identity |
| Installation | `${installdir}`, `${project.uninstallerName}`, `${project.uninstallerDirectory}` | Compiled parameter and uninstaller settings |
| Platform | `${platform}`, `${platform_name}`, `${platform_install_prefix}` | Validated Windows PE and project settings |
| Windows folders | `${windows_folder_program_files}`, `${windows_folder_local_appdata}`, `${windows_folder_common_appdata}` and related shell folders | Manifest-safe environment projections |
| User paths | `${user_home_directory}` and user shell-folder variables | `%USERPROFILE%`, `%APPDATA%`, or `%LOCALAPPDATA%` forms |
| Runtime state | command-line parameters, UI input, registry and filesystem probes, script results | Unresolved unless explicitly supplied by trusted evidence |

Stable Windows directories become manifest-safe variables such as `%ProgramFiles%`, `%ProgramFiles(x86)%`, `%CommonProgramFiles%`, `%SystemRoot%`, `%ProgramData%`, `%APPDATA%`, `%LOCALAPPDATA%`, `%PUBLIC%`, and `%USERPROFILE%`. The parser never substitutes the current analyst's profile or Windows directory.

## Directory parameters

The installation directory normally comes from a `directoryParameter` named `installdir`. Its explicit `value` takes precedence over `default`. The resolved default becomes `DefaultInstallLocation` after slash normalization. The parameter's `cliOptionName` defines the install-location switch; when a custom parameter omits that field, the runtime uses the parameter name.

```text
directoryParameter
+-- name or @name = installdir
+-- value, preferred when present
+-- default, fallback
`-- cliOptionName, normally prefix

WinGet projection: --<cliOptionName> "<INSTALLPATH>"
```

Parameters remain runtime-mutable even when they have deterministic defaults. Their configured values can be shown beside unresolved expression source, but a default cannot prove the result of a rule that depends on user or command-line input.

## Components, folders, and payload mapping

The physical VFS catalog does not directly describe default installed state. Components and folders supply selection, platform, destination, and rule evidence.

| Result collection | Meaning |
| --- | --- |
| `PackagedPayloadFiles` | Every logical application file physically represented by the supported payload route |
| `PayloadFiles` | Files selected for the statically established default installation |
| `ConditionalPayloadFiles` | Files whose component, platform, or rule state is unknown |
| `ExcludedPayloadFiles` | Files proven absent from the default selection |
| `PayloadCatalog` | Physical path, logical path, size, compression, timestamp, conditions, and destination evidence |

Folder mappings are inherited through the project hierarchy. A component or folder excluded by a false default-selection rule does not contribute to `PayloadFiles`. Unknown rules preserve the file under the conditional collection rather than choosing an outcome.

## Condition model

Conditions use three values: `True`, `False`, and `Unknown`. The parser resolves only the documented subset whose operands are deterministic.

| Rule | Supported static behavior |
| --- | --- |
| `isTrue`, `isFalse` | Recognize literal `1`, `true`, or `yes` and their false alternatives |
| `compareText` | Ordinal equality, inequality, contains, and does-not-contain, with optional case folding |
| `compareTextLength` | Numeric length comparisons |
| `compareValues` | Invariant numeric comparison when both values are numeric, otherwise ordinal text comparison |
| `compareVersions` | Comparison when both operands parse as .NET versions |
| `platformTest` | Resolve Windows and a bounded subset of architecture tests from PE evidence |
| `regExMatch` | Resolve source-backed expressions that are compatible with the bounded .NET route; Tcl-specific constructs remain unknown |
| Nested rule groups | Combine with documented `all` or `any` logic and optional negation |

Filesystem tests, registry probes, target Windows-version checks without a trusted target context, Tcl code, external scripts, malformed expressions, and mutable parameter comparisons remain `Unknown`. A false child can settle an `all` group and a true child can settle an `any` group even when another child is unknown; otherwise uncertainty propagates.

## Action lists and ordering

`ProjectActions` retains every recognized leaf action in source order. The parser traverses nested `actionList` nodes under groups, conditions, and loops rather than examining only direct project children. Each action records its XML element name, phase, lifecycle, scalar properties, resolved values, inherited rules, condition state, unresolved variables, and redacted-property names.

The main persistent installation order is:

```text
preInstallationActionList
readyToInstallActionList
folder-owned actionList, immediately after each folder is unpacked
postInstallationActionList
built-in uninstaller and ARP creation
postUninstallerCreationActionList
```

Initialization, page, final-page, failure, rollback, and uninstallation lists remain evidence but are not projected as unconditional installed-state changes. See [setup runtime](setup-runtime.md) for the lifecycle model.

## Registry operations

`registrySet` and `registryDelete` records are preserved as ordered operations. Each record retains the authored key, value name, value data, type, view, phase, condition state, and resolved form.

```text
registrySet
+-- key and value name
+-- type and value data
+-- optional Windows registry view
+-- inherited conditions
`-- phase and lifecycle

registryDelete
+-- key
+-- optional value name; omission deletes the complete key
+-- optional Windows registry view
+-- inherited conditions
`-- phase and lifecycle
```

`RegistryWrites` and `RegistryDeletes` separate the operation kinds. `EffectiveRegistryWrites` applies deterministic set/delete semantics in runtime order. A later value delete removes one earlier set; a later key delete removes all earlier values under that key. Conditional operations do not silently mutate the authoritative final state and instead mark the affected result uncertain.

## File associations

`associateWindowsFileExtension` is a native InstallBuilder action rather than merely a collection of arbitrary registry rows. One action can register a space-separated extension list under one ProgID and define friendly text, MIME type, icon, executable, arguments, verbs, scope, phase, and conditions. `removeWindowsFileAssociation` removes the corresponding mapping.

`FileExtensionAssociations` preserves adds and removals. `EffectiveAssociations` applies deterministic lifecycle ordering. `FileExtensions` includes only surviving literal extensions. An unresolved description, icon, or optional command argument does not erase an otherwise proven extension registration, but an unresolved extension expression keeps the extension set incomplete.

Literal effective registry writes are also passed through the shared association projector, allowing conventional `Software\Classes` protocol and extension registrations to be reported. Runtime-computed keys and values remain raw operation evidence.

## Shortcuts and executable identity

Shortcut records retain destination, name, executable, arguments, working directory, icon, platform and component conditions, and payload matching. A shortcut that targets an embedded executable contributes to `PrimaryExecutableCandidates`. It does not prove scope because `installationScope` controls shortcut ownership independently from package and ARP scope.

Installation and final-page execution actions can also nominate a primary executable. Primary-candidate analysis remains opt-in because extracting executables and adjacent sidecars is more expensive than metadata parsing.

## Persistent system effects

The parser normalizes the following source-backed action families while retaining each complete action in `ProjectActions`:

| Result | Project actions |
| --- | --- |
| `EnvironmentChanges` | `setEnvironmentVariable`, `addEnvironmentVariable`, `deleteEnvironmentVariable` |
| `PathChanges` | `addDirectoryToPath`, `removeDirectoryFromPath` |
| `WindowsServices` | create, delete, start, stop, and restart Windows service actions |
| `ScheduledTasks` | add and delete scheduled task actions |
| `FontChanges` | add and remove font actions |
| `SharedDllChanges` | add and remove shared-DLL reference actions |
| `WindowsAclChanges` | set and clear Windows ACL actions |

`setEnvironmentVariable` changes only the installer process. Persistent environment and PATH actions are distinguished from that transient operation. Service and task passwords are never returned; the result reports `PasswordConfigured` and records the property name under `SensitiveProperties`.

## Execution actions

`runProgram` and related execution records retain executable, arguments, phase, condition, wait and launch behavior, and payload ownership. Installation-phase calls to embedded installer-like files become `NestedInstallerCandidates`. Final-page launches remain presentation effects and cannot own the outer package's ARP entry solely because they execute after installation.

An action can call a downloaded file, an external path, a DLL, or a script. Static analysis records that boundary but cannot infer the child process's registry, dependency, or installability effects.

## Runtime requirements

Structured `autodetectJava` actions expose accepted version ranges, bitness, vendor constraints, and JRE or JDK requirements. `autodetectDotNetFramework` actions expose configured .NET Framework bounds. Windows-version rules remain condition evidence. These records describe installer requirements but do not identify a corresponding WinGet dependency package by themselves.

## Dynamic project logic

`DynamicProjectLogic` is designed for direct agent review. Each record includes:

| Property | Meaning |
| --- | --- |
| `EvidenceKind` | Rule, expression, or script reference |
| `OwnerType` | Action, component, folder, shortcut, parameter, or project property that owns the logic |
| `Property` | Affected source property when applicable |
| `Phase` | Runtime action list or project location |
| `SourceCode` | Exact expression, rule XML, or script reference from the project |
| `ReferencedVariables` | Variable names found in the source |
| `VariableValues` | Deterministic value, configured mutable default, or runtime-only classification |
| `AffectedFields` | Manifest conclusions that could change if the logic resolves differently |

Password-like values are redacted before these records are returned. Agents may reason from complete simple source and known values, but must not feed the text to `Invoke-Expression`, Tcl, the installer, or another host evaluator.

## Interpretation rule

A project node becomes authoritative metadata only after its structure, lifecycle, condition, and variables are understood. Unknown XML is retained in the parsed project or `ProjectActions`; it is not assigned guessed semantics. Extending projection requires published runtime behavior or controlled builder evidence plus a fixture that exercises the relevant route.

## Source references

- [InstallBuilder project settings](https://releases.installbuilder.com/installbuilder/docs/installbuilder-userguide/project.html)
- [InstallBuilder variables](https://releases.installbuilder.com/installbuilder/docs/installbuilder-userguide/variables.html)
- [InstallBuilder components](https://releases.installbuilder.com/installbuilder/docs/installbuilder-userguide/components.html)
- [InstallBuilder actions](https://releases.installbuilder.com/installbuilder/docs/installbuilder-userguide/action.html)
- [InstallBuilder rules](https://releases.installbuilder.com/installbuilder/docs/installbuilder-userguide/_rules.html)
