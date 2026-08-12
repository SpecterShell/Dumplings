# InstallShield runtime and installation lifecycle

[Back to InstallShield internals](overview.md).

The runtime lifecycle depends on the project model. InstallScript projects use the ISRT/IFX framework, Basic MSI projects delegate the product transaction to Windows Installer, InstallScript MSI combines both systems, and Advanced UI adds a suite planner around nested packages.

## Bootstrap startup

`Setup.exe` is a bootstrapper and compatibility host. Depending on the release, it may contain the product media, unpack a wrapper archive, or read sibling files. Startup commonly performs these steps:

```text
process creation
  -> apply PE requestedExecutionLevel
  -> parse setup command line
  -> locate/decode Setup.ini
  -> select setup language
  -> determine media and package configuration
  -> evaluate selected prerequisites
  -> load InstallScript runtime or launch the selected MSI/suite
```

The launcher can restart itself or a child at a different privilege level. Its PE architecture and version belong to the runtime stub, not necessarily to the application payload.

## Setup.ini

`Setup.ini` is the launcher's structured configuration. Common sections are:

| Section | Typical contents |
| --- | --- |
| `[Startup]` | Product, ProductGUID, CompanyName, EngineVersion, MediaFormat, ScriptDriven, PackageName, CmdLine, language-dialog and integrity options. |
| `[Languages]` | Default and supported language IDs, exact-match requirements, RTL language set. |
| `[0xLLLL]` | Localized language names or startup strings. |
| `[ISSetupPrerequisites]` | Release-selected prerequisite references and ordering. |
| Package-named section | Exact `Location` of the MSI or package selected by `[Startup] PackageName`. |
| OS/build maps | Builder-generated compatibility data used by the runtime. |

Fields differ by generation and project type. An absent field can mean a runtime default rather than a malformed configuration.

`ProductGUID` seeds InstallScript identity but does not alone prove that an uninstall entry is created. `PackageName` identifies a configuration section; the corresponding `Location` selects the nested package. `CmdLine` belongs to the configured launch stage.

## Language initialization

InstallShield language IDs use Windows locale identifiers, commonly written as hexadecimal `0xLLLL`. The launcher can use a fixed default, show a language dialog, require an exact locale match, or choose a fallback.

Language selection affects:

- Localized launcher and dialog strings.
- InstallScript `StringTable_*.ips` resources.
- Locale-specific setup types and media metadata.
- MSI transform or language selection.
- ARP display strings written by script or suite code.

Several valid localized values can therefore exist for one logical field. The binary may not identify which one appears on a particular target until runtime.

## InstallScript runtime layers

InstallScript execution is split between the native runtime and compiled script:

```text
Setup.exe / setup runtime
  -> ISRT native services
      files, registry, dialogs, logging, shell, process, system queries
  -> IFX generated framework
      setup lifecycle and default handlers
  -> project script
      authored event overrides and helper functions
  -> linked OBL libraries
      optional runtime domains such as SQL, IIS, XML, or suite support
```

Built-in functions are native runtime calls, not bytecode implementations. A compiled script instruction identifies the call and arguments; the side effect is defined by ISRT and target-machine state.

## Framework startup

Event-based projects use generated framework code. The official framework first installs EXIT and HELP handlers, then performs startup callbacks:

```text
Preprogram
  -> ISRTPreprogram
  -> OnSetTARGETDIR
  -> OnSetUpdateMode
  -> OnCheckMediaPassword
  -> product-specific requirement checks
```

`OnSetTARGETDIR` skips its default initialization in maintenance mode because the previous target directory is read from the installation log. In first install, the framework can start from a path such as `<FOLDER_APPLICATIONS>\<IFX_COMPANY_NAME>\<IFX_PRODUCT_NAME>` and then replace it with media-authored data.

`OnSetUpdateMode` compares the installed and media product versions. Differential media or a changed installed version can select update flow. Apps & Features and remove-only launches suppress update mode.

## Initialization and filtering

`InitInstall` initializes framework state, checks target requirements, filters components, and calls `OnBegin`. File groups are filtered by operating-system platform and language before transfer.

This filtering occurs before normal feature transfer. A file present in the catalog is not necessarily eligible for the current target.

## UI and scenario selection

`ShowWizardPages` enters the framework callback. Unless the setup is hosted by a suite, `OnShowUI` selects one scenario:

```text
UPDATEMODE == true       -> OnUpdateUIBefore
else MAINTENANCE == true -> OnMaintUIBefore
else                     -> OnFirstUIBefore

then OnMoveData

UPDATEMODE == true       -> OnUpdateUIAfter
else MAINTENANCE == true -> OnMaintUIAfter
else                     -> OnFirstUIAfter
```

Suite-hosted InstallScript packages use `OnSuiteShowUI` and suite-specific before/after callbacks. A `program ... endprogram` project can bypass the generated event sequence and call `InitInstall`, `ShowWizardPages`, transfer, or other runtime operations itself.

## File transfer

`OnMoveData` enters the runtime's transfer phase. Framework callbacks around that phase include:

```text
IfxOnTransferring
  -> initialize service domains and exception state
  -> OnMoving
  -> CreateRegistrySet(<Default>)

media transfer
  -> install selected feature/component file groups
  -> apply component-associated registry and shell records
  -> update progress and installation log

completion
  -> OnMoved
  -> post-transfer product integration
```

The exact callback list varies by generation and linked runtime domains. Script code can call file, registry, shell, service, process, or custom DLL functions before and after the built-in transfer.

## Registry sets and shell objects

Registry sets are media-authored collections. The default set is created during normal transfer. A named unassociated set normally requires `CreateRegistrySet(name)`; an empty name can select all appropriate sets.

Component-associated registry records and shortcuts follow component transfer. Their effects depend on setup type, feature state, platform/language filtering, and maintenance operation.

`RegDBSetDefaultRoot` and related state choose how SHCTX resolves. Explicit HKCU or HKLM calls override contextual defaults. Registry state is process-local runtime state and can change during the script.

## Installation log and maintenance state

InstallScript maintains its own product log. The framework adds transferred files and the log itself, stores source and instance information, and hides the installation-information directory. The log allows later maintenance to recover target paths, components, shared-file state, and product version.

Important modes include:

| State | Runtime meaning |
| --- | --- |
| First install | No matching maintenance log/product state was selected. |
| Maintenance | Existing product state was found; modify, repair, or remove UI can run. |
| Update | Differential media or installed/media version comparison selected update events. |
| Add/Remove launch | Runtime entered through the registered uninstall command. |
| Remove-only | UI and behavior are constrained to product removal. |
| Multi-instance | `INSTANCE_GUID`, target path, and product registration identify a selected instance. |

Maintenance behavior can read values that were never literal in the original installer. Static analysis must distinguish runtime log reads from build-time constants.

## MaintenanceStart and ARP

`MaintenanceStart` registers the setup for future maintenance and writes the default uninstall entry using runtime state. Typical values are derived from:

```text
uninstall key identity <- PRODUCT_GUID / instance identity
DisplayName            <- IFX_PRODUCT_NAME or override
DisplayVersion         <- IFX_PRODUCT_VERSION or override
Publisher              <- IFX_COMPANY_NAME or override
InstallLocation        <- TARGETDIR
UninstallString        <- installed maintenance launcher and arguments
SystemComponent        <- ADDREMOVE_SYSTEMCOMPONENT
scope/root             <- ALLUSERS and registry-root behavior
```

`RegDBSetItem` can change maintenance metadata before registration. Direct registry calls can alter the default entry or create additional entries. Localized strings and conditional branches can produce several possible display values.

## Record and silent modes

InstallScript dialogs support a record/playback model:

```text
record mode
  dialog executes interactively
  -> response values written to setup.iss sections

silent mode
  dialog function detects MODE == SILENTMODE
  -> reads the expected response section
  -> returns recorded values without showing the dialog
```

Standard response files also record decisions for read-only files, shared files, destination paths, components, and completion behavior. Dialog order and section requirements can vary between first install and maintenance.

A missing or mismatched response section can abort playback, choose defaults, or fall back to UI depending on the dialog and script. Custom dialogs and native DLL calls can implement unrelated behavior.

Some projects explicitly skip all response-backed dialogs in silent mode and are genuinely silent without `setup.iss`. Others detect silent mode and exit.

## Basic MSI lifecycle

For Basic MSI, the bootstrapper prepares a Windows Installer invocation:

1. Resolve prerequisites, language, and selected package.
2. Choose the exact MSI and optional transform.
3. Compose authored and caller command-line properties.
4. Launch Windows Installer at the selected UI level.
5. Let MSI sequencing and the Windows Installer service own transaction, rollback, repair, upgrade, and ARP registration.

InstallShield custom actions can still run inside MSI sequences. Their execution context follows MSI custom-action type and sequence rules rather than the standalone InstallScript setup lifecycle.

## InstallScript MSI lifecycle

InstallScript MSI adds runtime initialization and script events to the MSI transaction. `ISVerifyScriptingRuntime` can verify that Setup.exe prepared the runtime. InstallScript actions appear in UI or execute sequences and can run immediate, deferred, rollback, or commit work according to their MSI type.

The MSI owns product state, but script code can create additional files, registry entries, or child processes. Basic UI does not guarantee that every InstallScript UI action becomes noninteractive.

## Advanced UI lifecycle

The suite engine evaluates outer mode and abort conditions, computes package eligibility and selection, then walks the ordered parcel/transaction catalog. For each operation it chooses normal or silent arguments, evaluates detection, tracks exit/reboot behavior, and advances or rolls back the transaction according to suite policy.

Suite InstallScript actions run selected functions from the suite's compiled script. Nested packages retain their own runtime lifecycles.

## Elevation boundaries

Elevation can occur at several stages:

- The outer PE can request administrator rights before startup.
- The suite or launcher can start a prerequisite elevated.
- Windows Installer can request elevation through its service/UI path.
- A script can launch a child with elevation behavior.
- A machine operation can fail when silent mode suppresses the UI needed for consent.

An already elevated launcher and a child elevated after startup can observe different state and command-line behavior. This is why some packages work only when `msiexec` starts from an elevated shell even though an unelevated passive launch displays UAC.

## Static-analysis boundaries

Compiled code can describe calls and branches without revealing all runtime results. These inputs remain external to the file format:

- Registry and installed-product state.
- Existing maintenance logs and feature state.
- User selections and dialog responses.
- Native DLL exports and child process behavior.
- Network prerequisite availability.
- Windows Installer service and UAC decisions.

Static analysis should preserve these dependencies rather than replace them with the most likely path.

## Sources

This lifecycle is grounded in the official IFX/ISRT source and sample projects distributed with InstallShield 11.5 and 2026, plus the official documentation linked from [the overview](overview.md#source-references).
