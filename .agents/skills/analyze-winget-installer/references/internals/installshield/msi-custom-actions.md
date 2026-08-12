# InstallShield MSI internals

[Back to InstallShield internals](overview.md).

InstallShield can build a conventional Windows Installer package, an InstallScript MSI package whose installation lifecycle depends on the InstallScript runtime, or an MSI parcel controlled by an Advanced UI suite. The same `.msi` container can also carry individual compiled InstallScript custom actions without becoming an InstallScript MSI project.

## MSI database layers

An MSI is a Compound File Binary database. Standard Windows Installer tables describe product identity, features, components, files, registry values, custom actions, and action sequencing. InstallShield adds `IS*` tables and binary streams for builder-specific behavior.

```text
MSI compound database
+-- Summary Information
|   `-- Creating Application: InstallShield [product version]
+-- standard MSI tables
|   +-- Property / Directory / Feature / Component
|   +-- File / Registry / Shortcut / ServiceInstall
|   +-- Upgrade / LaunchCondition / Media
|   +-- CustomAction
|   `-- InstallUISequence / InstallExecuteSequence / other sequences
+-- InstallShield-authored tables
|   +-- ISSetupPrerequisites
|   +-- ISFeatureSetupPrerequisites
|   +-- ISInstallScript* or ISScriptFile, depending on generation
|   `-- other project- and UI-related IS* tables
`-- Binary streams
    +-- ISSetup.dll
    `-- prerequisite, support, or custom-action binaries
```

The Summary Information `Creating Application` value is builder evidence. It is not the package version and does not by itself distinguish Basic MSI from InstallScript MSI.

## Basic MSI

In a Basic MSI project, Windows Installer owns the installation transaction. Standard MSI tables define the product and installed resources. InstallShield can add dialogs, launch conditions, prerequisites, setup-launcher settings, and compiled InstallScript custom actions, but those additions do not replace the MSI component model.

Typical identity comes from:

```text
Property.ProductCode     -> MSI product identity and default ARP key
Property.UpgradeCode     -> related-product family
Property.ProductName     -> default DisplayName
Property.ProductVersion  -> default DisplayVersion
Property.Manufacturer    -> default Publisher
Directory                -> authored destination tree
Component + Registry     -> installed registry state
```

Windows Installer writes the normal ARP entry and sets `WindowsInstaller=1`. An InstallShield-authored custom ARP entry or hidden MSI registration is a project override, not the default Basic MSI model.

## InstallScript MSI

InstallScript MSI combines the MSI database with the InstallScript engine and framework. Its script can control UI, initialization, maintenance, and custom system changes while Windows Installer still manages MSI features and components.

Structural indicators include:

- `ISVerifyScriptingRuntime` custom action.
- Custom actions whose names begin with `ISInstallScript`.
- Generation-specific `ISInstallScript*` tables.
- `ISScriptFile`.

Other `IS*` tables occur in Basic MSI projects and are not sufficient on their own. Conversely, `Binary.ISSetup.dll` plus one compiled function can be present in a Basic MSI package.

The MSI normally remains the owner of ProductCode, UpgradeCode, version, and ARP registration. InstallScript may add registry entries or change runtime behavior, but its presence does not turn the default MSI ARP entry into an EXE entry.

## ISSetup.dll and ISSetupStream

Compiled InstallScript custom actions are packaged in a PE image named `ISSetup.dll` in the MSI `Binary` table. InstallShield appends a structured InstallShield stream to that PE. The stream contains the program and supporting resources required by the runtime.

```text
Binary table stream: ISSetup.dll
+-- PE image
|   +-- native custom-action/runtime entry points
|   `-- PE resources and version information
`-- InstallShield overlay: ISSetupStream
    +-- setup.inx                    compiled InstallScript program
    +-- IsConfig.ini                fN-to-function mapping
    +-- StringTable_0xLLLL.ips      localized strings
    +-- String*.txt / support files generation-dependent
    `-- runtime configuration
```

The MSI stream has no original filesystem path. At runtime Windows Installer and the InstallShield custom-action host materialize or map it as required. The embedded files are distinct from ordinary MSI `File` table payloads.

## Opaque export mapping

An authored InstallScript custom action is not named directly in the MSI `CustomAction.Target` field. The target commonly uses a generated export such as `f1`; `IsConfig.ini` maps that export to the authored function.

```text
CustomAction row
  Action = MyInstallScriptAction
  Source = ISSetup.dll
  Target = f1

IsConfig.ini
  [f1]
  Function=ConfigureProduct

runtime dispatch
  f1 -> ConfigureProduct(...) in setup.inx
```

The mapping is exact and generation-specific. A missing section, an empty `Function` value, or a dynamic runtime target leaves the authored entry point unknown; searching all function names does not reconstruct the dispatch.

## Custom-action sequencing

`CustomAction` defines what to invoke. Sequence tables define when it may run:

```text
InstallUISequence
InstallExecuteSequence
AdminUISequence
AdminExecuteSequence
AdvertiseExecuteSequence
  -> Action name
  -> Condition expression
  -> Sequence number
```

One action can appear in several sequences or be invoked by another action. Conditions reference MSI properties, feature/component action states, product state, operating-system facts, and command-line properties. Their truth value belongs to a specific Windows Installer session.

Custom-action type bits also control execution context. Relevant distinctions include immediate versus deferred execution, rollback or commit execution, impersonated versus no-impersonate execution, source type, target type, and return-processing behavior. These bits affect privileges and transaction semantics even when the mapped InstallScript function is identical.

Deferred actions receive a restricted MSI session and normally consume values prepared through `CustomActionData`. They cannot be modeled as ordinary immediate calls with access to every MSI property.

## Runtime verification and Setup.exe

InstallScript MSI projects may include `ISVerifyScriptingRuntime`. Its purpose is to verify that the MSI was launched through the InstallShield bootstrapper and that the expected scripting runtime is available.

```text
setup.exe
  +-- checks platform, language, prerequisites, and launcher configuration
  +-- initializes or deploys InstallScript runtime support
  +-- supplies transforms and MSI properties
  `-- invokes msiexec for the selected package

MSI sequence
  `-- ISVerifyScriptingRuntime
      `-- validates launcher/runtime contract
```

The verifier is evidence of a launcher contract. It does not imply that every direct `msiexec` invocation fails in the same way. Product configuration, properties, already-installed runtimes, and action conditions can alter the result.

Even a Basic MSI may rely on `Setup.exe` for prerequisites, language transforms, architecture selection, chained packages, or authored command-line properties. That operational dependency is separate from InstallScript MSI classification.

## Prerequisite tables

InstallShield MSI projects can associate setup prerequisites with the package or individual features:

```text
ISSetupPrerequisites
  -> prerequisite identifier/name
  -> build source and setup location
  -> order and release flags

ISFeatureSetupPrerequisites
  -> Feature_ foreign key
  -> prerequisite identifier/name
```

The MSI row is a reference. The corresponding `.prq` definition contains detection conditions, payload URLs, hashes, command lines, success/reboot codes, and privilege behavior. A feature reference means the prerequisite is conditional on feature planning; it is not an unconditional package dependency.

Setup prerequisites normally run in the bootstrapper before MSI execution. Launching the MSI directly can therefore bypass checks or dependencies that the vendor expected the launcher to satisfy.

## Advanced UI parcels

An Advanced UI suite can stage an InstallShield-authored MSI as one parcel among many. In this arrangement:

- The MSI keeps its ProductCode and Windows Installer transaction.
- The suite may hide the MSI ARP entry with properties such as `ARPSYSTEMCOMPONENT=1`.
- The suite can own a separate visible ARP entry identified by `SuiteId`.
- The suite operation supplies MSI properties and selects when the parcel runs.

Parcel identity and suite identity must therefore remain separate even when the suite installs only one MSI.

## ARP and maintenance ownership

For a normal Basic MSI or InstallScript MSI installation, Windows Installer owns repair, uninstall, patching, source resolution, ProductCode registration, and the visible ARP record. `WindowsInstaller=1` distinguishes that record from a generic EXE registration.

InstallShield can change visibility or add another entry through:

- MSI ARP properties such as `ARPSYSTEMCOMPONENT`.
- Authored `Registry` rows under an uninstall key.
- Compiled InstallScript custom actions.
- An outer Advanced UI suite.
- A prerequisite or chained package with its own registration.

An embedded function's registry write is supplemental evidence. It does not erase the standard MSI identity unless the authored behavior explicitly hides or replaces it.

## Silent installation and elevation

MSI `/quiet` and `/passive` select Windows Installer UI levels. They do not guarantee that an InstallShield custom action, prerequisite, or bootstrapper can operate in that mode.

InstallScript UI invoked from a custom action can display independently of MSI's basic UI. A no-impersonate deferred action can execute with elevated service privileges, while an immediate impersonated action uses the client context. Bootstrapper prerequisites can require elevation before `msiexec` starts.

This explains packages where:

- `/passive` requests elevation and then installs.
- `/passive` requests elevation but an InstallScript page still appears.
- `/quiet` fails until `msiexec` is started from an elevated process.
- direct MSI invocation differs from the vendor `Setup.exe`.

The exact behavior depends on sequence conditions, custom-action type bits, launch conditions, package installation privileges, and bootstrapper policy.

## Static-analysis boundaries

Structured MSI tables can establish builder identity, project type, sequence, action context, prerequisite references, ProductCode, UpgradeCode, and standard resource ownership. `ISSetupStream` can establish the compiled program and its literal function mapping.

Static inspection cannot execute native `ISSetup.dll` code, resolve all MSI conditions without session state, or prove the effects of imported DLLs. Failure to decode one embedded script action does not invalidate independently stored MSI identity and table metadata.
