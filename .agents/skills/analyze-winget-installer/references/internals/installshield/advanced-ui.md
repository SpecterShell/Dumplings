# InstallShield Advanced UI internals

[Back to InstallShield internals](overview.md).

Advanced UI and Suite/Advanced UI are bootstrapper products rather than a single package database. The suite plans and coordinates a collection of parcels, presents a shared UI, evaluates detection and eligibility conditions, passes command lines to child packages, and can own a separate Apps & Features entry.

## Runtime architecture

```text
suite setup.exe
  -> opens InstallShield bootstrap container
  -> reads Setup.xml package and planning model
  -> loads Setup_UI.xml / Setup_UI.dll presentation resources
  -> initializes suite properties and selected language
  -> evaluates modes, abort conditions, selections, and package eligibility
  -> stages local or download-backed parcel files
  -> runs parcel operations in planned order or transactions
  -> records suite maintenance state and optional outer ARP entry
```

The suite process is the orchestrator. Each MSI, MSP, EXE, AppX, InstallScript package, or prerequisite retains its own runtime and installation semantics.

## Setup.xml document

The central catalog is XML with a namespace of the form `installshield/<year>/bootstrap` or `installshield/<year>.<revision>/bootstrap`. InstallShield 2012 Spring, for example, emits `installshield/2012.2/bootstrap`, while InstallShield 2013 emits `installshield/2013/bootstrap`. The namespace identifies the outer bootstrap schema generation and is independent from the versions of nested packages.

```text
Extracted Advanced UI media
+-- Setup.xml
|   +-- Setup/@SuiteId
|   +-- ARPInfo
|   +-- LanguageSelection / Languages
|   +-- Properties / SetProperty
|   +-- SelectionTree
|   +-- Modes / AbortConditions
|   +-- Actions / Events
|   +-- Transactions
|   +-- WindowsFeaturesDefinitions
|   `-- Parcels, in catalog order
|       +-- identity and platform attributes
|       +-- package files or download locations
|       +-- eligibility and detection conditions
|       +-- install/repair/modify/uninstall operations
|       `-- operation properties and command lines
+-- Setup_UI.xml / Setup_UI.dll
+-- optional Setup.inx and localized string tables
`-- parcel directories and payloads
```

Catalog order matters. Transactions and package records share the planning stream even though a transaction is not itself an executable parcel.

## Suite identity

`Setup/@SuiteId` is the suite identity. `ARPInfo` supplies its presentation and uninstall metadata:

```text
SuiteId                 -> outer uninstall-key identity
ARPInfo/DisplayName     -> localized suite name
ARPInfo/Version         -> suite display version
ARPInfo/Publisher       -> suite publisher
ARPInfo/Icon            -> suite ARP icon
ARPInfo/URLInfoAbout    -> publisher/product URL
ARPInfo/HelpLink        -> support URL
```

The outer suite and its parcels have separate identities. An MSI ProductCode, AppX family name, or nested InstallScript ProductGUID does not replace the SuiteId. A suite can hide parcel ARP entries and expose only its own entry, or it can leave both suite and parcel registrations visible.

If the suite lacks the records needed to register itself, the first parcel's identity is not a safe substitute.

## Localization

The suite can store literal strings or tokens resolved through `Languages`. `LanguageSelection/@Default` supplies the authored default language. UI labels, ARP strings, conditions, and messages can all be localized.

Token identity and resolved text are distinct. A missing token in one language does not authorize falling back to an unrelated parcel string. A token can also resolve differently at runtime when the user selects another suite language.

## Parcel catalog

Each parcel describes one installable or prerequisite unit. Common element families include:

| Element | Installed technology |
| --- | --- |
| `Msi` | Windows Installer product. |
| `Msp` | Windows Installer patch. |
| `Exe` | Generic executable package. |
| `IsmMsi` | InstallShield-authored MSI project. |
| `IsmIsp` / `InstallScript` | InstallShield InstallScript package. |
| `Appx` / `AppxBundle` | AppX/MSIX package or bundle. |
| `Prq` / `Prerequisite` | InstallShield prerequisite package. |
| Other typed records | Product-specific extension handled by the suite runtime. |

A parcel can contain:

- Suite-local ID and UI name.
- ProductCode, version, platform, or other technology-specific identity.
- Physical file records and download locations.
- Eligibility and installed-state detection expressions.
- One or more named operations.
- Properties controlling privilege, transaction, exit, and reboot handling.
- Selection-tree and feature relationships.

## Physical content

`Package`, `Folder`, and `File` records describe where bytes come from. A file may be embedded in the bootstrap media, staged under a parcel directory, or downloaded from a source URL.

```text
parcel content record
  +-- media-relative folder and file name
  +-- stream or package identifier
  +-- authored byte size
  +-- authored MD5
  `-- optional source URL
```

These values are catalog claims until the corresponding bytes are available and verified. A URL-backed parcel may not exist in the distributed executable.

## Operations

Storage and execution are modeled separately. One parcel can define install, repair, modify, remove, or other operations with different commands.

```text
Operation
  +-- Name / operation kind
  +-- executable target
  +-- CommandLine                 interactive invocation
  +-- Silent                      unattended invocation
  `-- Property[]
      +-- success and failure handling
      +-- reboot request and reboot codes
      +-- elevation behavior
      `-- suite-specific planning flags
```

An operation's arguments belong to that parcel and operation. They are not automatically valid for the outer `setup.exe`, another parcel, or the parcel's uninstaller.

## Conditions

Advanced UI uses several condition classes for different planning stages:

| Record | Purpose |
| --- | --- |
| `Eligible` | Determines whether a parcel can participate on the target. |
| `Detect` | Determines installed state and possible maintenance action. |
| selection `When` | Enables a feature-to-parcel relationship. |
| `Mode` | Selects first-install, maintenance, update, or another suite mode. |
| `AbortCondition` | Stops planning or execution and displays a message. |

Conditions form typed Boolean trees. AND, OR, and NOT combine leaves such as OS version, architecture, MSI product state, registry state, suite properties, package detection, and extension-defined predicates.

```text
AND: any False -> False; all True -> True; otherwise Unknown
OR:  any True  -> True; all False -> False; otherwise Unknown
NOT: True and False invert; Unknown remains Unknown
```

Eligibility and detection are not interchangeable. An already-installed package can still be eligible; detection changes the operation the suite plans.

## Selection tree and modes

`SelectionTree` connects user-visible suite features to parcel IDs. A package can be eligible but unselected, or selected through several feature paths. Suite modes select different UI and action graphs for first install, maintenance, upgrade, repair, or uninstall.

Planning therefore depends on:

```text
target facts
  + suite mode
  + condition results
  + feature selections
  + parcel detection
  + transaction membership
  = ordered operation plan
```

Catalog presence alone does not prove that a parcel runs in the default plan.

## Actions and events

Suite events trigger actions around UI and package phases. Actions can set properties, call suite code, invoke InstallScript functions, or affect package planning. `CallInstallScript` arguments can name a function in the suite's `Setup.inx`.

The InstallScript program is supplemental to the XML plan. It can calculate properties or perform side effects, but parcel identity, operation commands, transactions, and selection records remain part of the suite model.

A dynamic function expression or native action cannot be reduced to a literal entry point without runtime state.

## Properties and install locations

Suite properties are initialized and changed by actions. A common pattern is:

```text
SetProperty Name="INSTALLDIR"
  Value="[ProgramFiles64Folder]Vendor\Product"
```

Folder tokens are suite runtime properties. The resulting path is the suite's installation root or a value passed to selected parcels. It does not prove that every nested MSI uses `INSTALLDIR`; an MSI can use `INSTALLLOCATION`, `APPDIR`, or another directory property.

## Transactions, return codes, and reboot

Transactions group package operations for coordinated commit and rollback. Their behavior depends on parcel technology and suite policy; they are not MSI transactions merely because one parcel is an MSI.

Operation properties tell the suite how to interpret child exit codes, whether to continue, and whether to request or defer a reboot. The child process still produces the exit code. A suite can translate or aggregate that outcome before returning from the outer executable.

## Prerequisites and Windows features

Prerequisite parcels can point to external `.prq` definitions. The suite record selects and schedules the prerequisite; the PRQ owns its detection rules, payloads, commands, return-code handling, and privilege setting.

`WindowsFeaturesDefinitions` describes operating-system features that the suite can enable or require. These are target-state operations, not payload files. Both prerequisite and Windows-feature decisions can change after detection on the target machine.

## Installation and maintenance lifecycle

On first install the suite resolves language and properties, evaluates abort and eligibility conditions, collects selections, detects parcel state, stages files, and executes planned operations. It then records enough state to enter a maintenance plan later.

Maintenance can expose a different selection tree and invoke repair, modify, or uninstall operations. A newer suite can also plan upgrades against the suite's own registration while individual parcels use their own upgrade mechanisms.

Scope is determined by the suite's registration and execution context. A machine-scoped suite can contain user-scoped parcels, and parcel architecture does not by itself define the architecture of the outer bootstrapper.

## Static-analysis boundaries

The XML catalog can establish suite identity, localized metadata, parcels, physical content claims, operation commands, condition syntax, transactions, and authored selection relationships. It cannot determine conditions that need the target registry, installed products, user choices, downloaded content, or extension code.

Unknown condition results should preserve candidate parcels rather than mark them selected or excluded. An authored silent command is evidence of intent; it does not prove that every nested package completes unattended on every target.
