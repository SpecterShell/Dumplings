# InstallShield internals

InstallShield is not one executable format. It is a long-lived family of authoring systems, build tools, launchers, installation engines, media databases, and scripting runtimes. Products built by different releases can share a launcher while using incompatible media or script formats. A modern wrapper can also carry an older compatibility runtime.

This reference describes the installation system itself. The [InstallShield workflow](../../families/installshield/workflow.md) covers WinGet authoring, and the shared [parser development workflow](../../parser-development/workflow.md) covers implementation and testing rules.

## System model

An InstallShield setup is easiest to understand as five independent layers:

```text
authoring project
  .ism database + scripts + source files + release settings
        |
        v
build output
  launcher + configuration + runtime + media catalog + payloads
        |
        v
bootstrap
  choose language/platform/package, check prerequisites, prepare runtime
        |
        v
installation engine
  InstallScript runtime, Windows Installer, or Advanced UI suite engine
        |
        v
installed state
  files, registry, services, shortcuts, product log, and ARP entries
```

Each layer has its own data model and version. They must be identified independently when comparing two media sets or reconstructing runtime behavior.

## Installation models

### InstallScript

InstallScript projects use InstallShield's proprietary runtime and media database. Authored `.rul` source is compiled into `setup.ins` or `setup.inx`. The runtime interprets that program, transfers files selected through media features and components, writes registry sets and shell objects, and records maintenance information.

The compiled script controls more than custom actions. It owns setup flow, dialogs, target-directory selection, file transfer, maintenance, update logic, and usually the visible uninstall entry.

### Basic MSI

Basic MSI projects compile primarily to a Windows Installer database. Standard MSI tables own features, components, files, registry changes, ProductCode, UpgradeCode, and ARP registration. InstallShield adds authoring tables and may build a `Setup.exe` bootstrapper for prerequisites, language selection, transforms, architecture selection, and command-line preparation.

A Basic MSI can contain compiled InstallScript custom actions. Their presence does not turn the project into InstallScript MSI.

### InstallScript MSI

InstallScript MSI combines a Windows Installer product database with the InstallScript runtime. MSI still owns the product transaction and its normal ARP entry, while InstallScript actions supply UI or authored behavior at scheduled points. Runtime verification can require the MSI to be launched through InstallShield `Setup.exe`.

### Advanced UI and Suite/Advanced UI

Advanced UI is a bootstrap suite. `Setup.xml` describes an outer product and an ordered catalog of MSI, MSP, EXE, AppX, prerequisite, InstallScript, and other parcels. The suite can own one ARP entry through `SuiteId`; parcel ProductCodes identify nested packages rather than the outer suite.

### Other build artifacts

InstallShield also builds merge modules, objects, patches, transforms, prerequisite definitions, web-deployment parcels, and reusable setup engines. These artifacts can occur inside a setup without being the top-level product.

InstallAnywhere is a separate installer family despite later sharing corporate ownership with InstallShield.

## Authoring and build pipeline

The `.ism` project is an authoring database, not a shipped installer format. It can be stored as an XML representation of MSI-style tables or as a Windows Installer compound database. Standard MSI tables coexist with InstallShield authoring tables such as `InstallShield`, `ISRelease`, `ISProductConfiguration`, `ISSetupPrerequisites`, `ISRegistrySet`, `ISScriptFile`, and many feature, component, language, and media tables.

One project can define several releases and product configurations. The build selects a release, resolves path variables and source files, compiles scripts, filters platform/language data, chooses compression and disk layout, and emits the selected media form. For details, read [project and build model](project-model.md).

## Distributed artifact map

The same logical project can be emitted as a single compressed executable or a directory containing external media.

| Artifact | InstallShield role |
| --- | --- |
| `Setup.exe` | Bootstrapper or reusable setup engine. It can contain an overlay or rely on sibling media. |
| `Setup.ini` | Startup configuration: product defaults, language set, media mode, package selection, command line, prerequisites, and runtime version. |
| `setup.ins` | Older compiled InstallScript program. |
| `setup.inx` | Newer compiled InstallScript program. |
| `*.obl` | Compiled InstallScript object library containing one or more script modules. |
| `ISRT.dll` / runtime support | InstallScript runtime implementation used by the setup engine. |
| `StringTable_*.ips` | Localized script resources used by generated string-loading wrappers. |
| `setup.iss` | Recorded InstallScript dialog responses for silent playback. |
| `data1.hdr` | Proprietary media catalog, file descriptors, and in newer formats project metadata graphs. |
| `data1.cab`, `data2.cab`, ... | Proprietary payload volumes referenced by `data1.hdr`. These are not Microsoft Cabinet files. |
| `ISSetup.dll` | MSI Binary-table host for compiled InstallScript custom actions. Its overlay can contain `ISSetupStream`. |
| `IsConfig.ini` | Maps opaque MSI custom-action exports such as `f1` to authored InstallScript function names. |
| `Setup.xml` | Advanced UI suite catalog, outer ARP data, package graph, conditions, and operations. |
| `*.prq` | Setup-prerequisite definition with detection, payload, command-line, reboot, and privilege data. |
| `*.msi` / `*.msp` | Windows Installer package or patch selected or orchestrated by the launcher. |

File presence alone does not establish execution. `Setup.ini`, suite operations, MSI sequence tables, InstallScript calls, and media feature selection describe which artifact is used.

## Runtime architecture

A typical external-media InstallScript setup follows this chain:

```text
Setup.exe
  -> read Setup.ini
  -> select language and media configuration
  -> initialize InstallShield runtime
  -> load setup.inx and localized resources
  -> run framework initialization and project event handlers
  -> transfer selected media components
  -> write maintenance log and uninstall registration
```

A Basic MSI wrapper follows a different chain:

```text
Setup.exe
  -> read Setup.ini
  -> evaluate and install selected prerequisites
  -> choose exact package section and Location
  -> apply authored command line / transform / language
  -> launch Windows Installer for the selected MSI
```

PackageForTheWeb adds a delivery stage before either chain. Advanced UI replaces the simple package-selection stage with a suite catalog and operation planner.

Read [runtime and installation lifecycle](runtime-lifecycle.md) for startup, framework events, silent mode, maintenance, update, and uninstall behavior.

## Configuration versus runtime state

`Setup.ini` provides build-time defaults and launcher configuration. The runtime then derives state from command-line switches, installed-product logs, target machine properties, feature selection, and script assignments.

Important InstallScript state includes:

| State | Role |
| --- | --- |
| `MODE` | Normal, record, or silent execution mode. |
| `MAINTENANCE` | Existing product maintenance is active. |
| `UPDATEMODE` | Differential media or installed-version comparison selected update flow. |
| `ADDREMOVE` | Setup was started through Apps & Features maintenance. |
| `REMOVEONLY` | Removal-only behavior was requested. |
| `ALLUSERS` | Scope-related runtime state and maintenance-log placement. |
| `TARGETDIR` | Application target directory, initialized by project/framework logic. |
| `PRODUCT_GUID` | InstallScript product identity used by maintenance registration. |
| `INSTANCE_GUID` | Multi-instance installation identity. |
| `IFX_PRODUCT_NAME`, `IFX_PRODUCT_VERSION`, `IFX_COMPANY_NAME` | Framework product metadata. |
| `ADDREMOVE_SYSTEMCOMPONENT` | Controls visibility of the generated uninstall entry. |

These are variables, not constants embedded in every installer. Script code and runtime initialization can replace their values.

## InstallScript framework lifecycle

Generated event-based projects use an InstallShield framework around authored handlers. The official framework source shows this broad sequence:

```text
Preprogram
  -> install EXIT and HELP handlers
  -> OnSetTARGETDIR
  -> OnSetUpdateMode
  -> OnCheckMediaPassword

InitInstall
  -> filter components by platform and language
  -> OnBegin

ShowWizardPages
  -> OnShowUI or OnSuiteShowUI
      -> OnFirstUIBefore / OnMaintUIBefore / OnUpdateUIBefore
      -> OnMoveData
          -> OnMoving
          -> create default registry set
          -> transfer selected files and components
          -> OnMoved
      -> matching UI-after handler

ExitInstall
  -> OnEnd
```

`program ... endprogram` projects can replace the generated event path and call runtime functions directly. Named event handlers are not necessarily reachable merely because they exist in the compiled program.

## Media selection and transfer

InstallScript media uses setup types, features, components, and file groups:

```text
setup type
  -> selected feature paths
      -> components eligible for platform and language
          -> file groups
              -> ranges of entries in data*.hdr/data*.cab
```

Registry sets and shortcuts can be unassociated or tied to components. The default registry set is created during ordinary transfer. Named sets require an explicit `CreateRegistrySet` call unless component transfer selects them. Component-associated shortcuts follow the same selection model.

Read [proprietary media and cabinets](media-cabinets.md) for the catalog and record layouts.

## Maintenance and ARP

InstallShield has more than one ARP ownership model:

| Installation model | Normal visible ARP owner |
| --- | --- |
| InstallScript | `MaintenanceStart`, project variables, and explicit registry behavior. |
| Basic MSI | Windows Installer ProductCode registration. |
| InstallScript MSI | Windows Installer product, with possible supplemental script effects. |
| Advanced UI | Outer suite `SuiteId` and `ARPInfo`; nested package entries may be hidden. |
| Prerequisite or chained package | The child package can create its own independent entry. |

InstallScript maintenance records enough state to re-enter modify, repair, or remove behavior. The runtime stores an installation log and hides its installation-information directory. In maintenance mode it can recover `TARGETDIR`, installed version, selected components, and instance identity from that state.

Product GUID, uninstall key, and displayed metadata are related but not interchangeable. Script calls can override default product values or create additional uninstall keys.

## Silent and response-file behavior

InstallScript distinguishes record mode from silent playback. Response-backed dialogs write named sections and values while recording, then read them in `SILENTMODE`. A setup can therefore recognize `/s` yet still require a matching `setup.iss`, commonly supplied through `/f1`.

Some scripts bypass dialogs in silent mode and need no response file. Others reject silent execution, call custom DLLs, or generate a dialog sequence that depends on maintenance state. Silent capability must be derived from reachable runtime behavior, not from the existence of the command-line parser.

InstallScript MSI and Advanced UI have additional launch layers. Their silent behavior also depends on MSI UI level, suite operation command lines, prerequisites, and launcher contracts.

## Scope, elevation, and architecture

Scope can be represented in several places:

- MSI `ALLUSERS` and installation context.
- InstallScript `ALLUSERS`, registry-root state, maintenance log, and explicit HKCU/HKLM writes.
- Advanced UI suite uninstall-key checks and parcel properties.
- The outer PE requested execution level.
- Prerequisite privilege settings.

Machine scope does not by itself prove that the launcher requests elevation. Likewise, a prerequisite requiring administrator rights does not prove that the main package is machine-wide.

InstallShield can build separate x86, x64, and other platform media or one launcher that selects nested packages. Launcher architecture, payload architecture, and installed executable architecture are separate facts.

Read [prerequisites](prerequisites.md) for `.prq` behavior and privilege boundaries.

## Format generations

InstallShield changed storage and script formats repeatedly:

- InstallShield 3 uses Setup30 footer catalogs and TTCOMP/PKWARE Implode members.
- InstallShield 5 uses legacy proprietary cabinet descriptors and raw Deflate.
- InstallShield 6 and later use `ISc(` common headers and larger descriptor catalogs.
- Later generations switched catalog strings to Unicode while preserving much of the 0x57-byte file descriptor family.
- InstallScript programs occur as old INS, OBS, aLuZ, kUtZ, and OBL forms.
- Modern releases add Advanced UI suite XML while retaining older runtime and media compatibility.

Read [versions and generations](versions-and-generations.md) before interpreting any version field. Product, schema, engine, cabinet, script, suite, MSI, and packaged-application versions are distinct domains.

## Reference map

Read the focused page for the layer under investigation:

- [Project and build model](project-model.md): `.ism` storage, authoring tables, product configurations, releases, source resolution, compilation, and emitted media.
- [Versions and generations](versions-and-generations.md): product release, project schema, runtime engine, cabinet, bytecode, MSI, and suite version domains.
- [Outer containers](containers.md): Setup30 packages, PE overlays, PackageForTheWeb, external media, and package selection.
- [Proprietary media and cabinets](media-cabinets.md): `ISc(` headers, descriptors, volumes, compression, registry sets, and shell objects.
- [InstallScript bytecode](installscript-bytecode.md): compiled program formats, catalogs, instruction framing, runtime ABI, events, and dialogs.
- [Runtime and installation lifecycle](runtime-lifecycle.md): launcher startup, language initialization, IFX events, transfer, maintenance, silent mode, and elevation boundaries.
- [MSI integration](msi-custom-actions.md): Basic MSI, InstallScript MSI, `ISSetup.dll`, `ISSetupStream`, action sequencing, and launcher contracts.
- [Advanced UI](advanced-ui.md): suite identity, parcel catalog, conditions, operations, transactions, and maintenance planning.
- [Prerequisites](prerequisites.md): PRQ files, payloads, conditions, command lines, privilege behavior, and release references.
- [Coverage and remaining gaps](coverage.md): implemented structural profiles, fixture coverage, partial semantic paths, and runtime-only boundaries.

## Static-analysis boundaries

Static reconstruction must answer these questions in order:

1. Which physical containers and media databases are present?
2. Which installation model owns execution and ARP?
3. Which configuration or suite record selects nested payloads?
4. Which script entry points are reachable for the intended scenario?
5. Which effects are unconditional, feature-dependent, locale-dependent, or runtime-dependent?
6. Which version field belongs to each layer?

Unresolved runtime behavior should not be inferred from filenames or arbitrary strings. Native DLL exports, child executables, missing external media, user choices, and target-machine state remain static-analysis boundaries.

## Source references

- Format implementations and research: [ISx](https://github.com/lifenjoiner/ISx), [setup30](https://github.com/ostrich/setup30), [Unshield](https://github.com/twogood/unshield), and [InstallScript Decompiler](https://github.com/jte/installscript-decompiler).
- Release research: [historical InstallShield releases and documentation](https://zzz.buzz/notes/links-to-installshield-downloads-and-documentation/) and the [schema-version mapping discussion](https://stackoverflow.com/questions/29690042/find-installshield-version-used-for-creating-an-ism-file).
- Official runtime and authoring documentation: [InstallShield documentation](https://docs.revenera.com/installshield/), [Setup.ini](https://docs.revenera.com/installshield/helplibrary/SetupIni.htm), [InstallScript language reference](https://docs.revenera.com/installshield/LangRef/Langref.htm), and [Advanced UI overview](https://docs.revenera.com/installshield26helplib/helplibrary/SteOverview.htm).
- Windows Installer: [CustomAction table](https://learn.microsoft.com/en-us/windows/win32/msi/customaction-table), [action sequencing](https://learn.microsoft.com/en-us/windows/win32/msi/sequencing-actions), and [MSI summary properties](https://learn.microsoft.com/en-us/windows/win32/msi/summary-information-stream-property-set).
