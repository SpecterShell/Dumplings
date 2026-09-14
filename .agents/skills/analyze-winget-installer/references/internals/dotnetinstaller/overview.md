# dotNetInstaller internals

This reference describes the dotNetInstaller file format and runtime behavior consumed by Dumplings. Use the [dotNetInstaller workflow](../../families/dotnetinstaller/workflow.md) for package analysis and WinGet authoring.

Read [binary notation](../../parser-development/binary-notation.md), [parser contracts](../../parser-development/contracts.md), and [performance guidance](../../parser-development/performance.md) before changing the parser.

## Mental model

dotNetInstaller is a native PE bootstrapper whose resources contain one XML configuration and zero or more Microsoft Cabinet streams. The XML is the execution plan. Cabinet entries and explicitly supplied sidecars are physical inputs. The runtime chooses configurations and components from locale, OS, architecture, installed-state, and authored selection rules, then selects a full, basic, or silent command for each component.

```text
distributed bootstrapper
+-- native PE runtime
|   +-- command-line parser and UI-level fallback
|   `-- exact runtime capability tokens
`-- PE resources
    +-- CUSTOM/RES_CONFIGURATION: configuration XML
    +-- CUSTOM/RES_CAB_LIST: display-only file summary
    +-- RES_CAB/*: global or component-owned cabinet parts
    +-- CUSTOM/RES_BANNER and CUSTOM/RES_SPLASH
    `-- optional HTM resources for the HTML launcher

logical execution
+-- select applicable configurations
+-- resolve reference configurations
+-- select required and chosen components
+-- resolve embedded, downloaded, or sidecar payloads
+-- choose full/basic/silent command with runtime fallback
`-- execute optional completion command
```

The wrapper usually does not own the visible Apps & Features row. A selected nested MSI or another nested installer does. Static parsing must keep launcher capabilities, authored component routes, physical payload availability, and final installed state separate.

## Reading path

1. [Architecture](architecture.md) explains the builder, launcher, configuration graph, and evidence boundaries.
2. [Format history](format-history.md) records source-backed release and behavior changes.
3. [Binary format](binary-format.md) defines PE resources and cabinet-set framing.
4. [Metadata model](metadata-model.md) describes XML records, filters, commands, and path tokens.
5. [Setup runtime](setup-runtime.md) covers mode fallback, selection, downloads, completion commands, elevation, and exit behavior.
6. [Uninstaller and ARP](uninstaller-and-arp.md) explains nested ownership and MSI selection.
7. [Parser implementation](parser-implementation.md) documents parsing, extraction, limits, diagnostics, and performance.
8. [Coverage](coverage.md) lists verified fixtures and remaining boundaries.

## Structural routes

| Route | Resource organization | Parser consequence |
| --- | --- | --- |
| `ConfigurationOnly` | configuration XML without `RES_CAB` | Payloads are downloaded, adjacent, or absent; explicit companion files are required for nested parsing. |
| `GlobalCabinetExtensionless` | `SETUP_1`, `SETUP_2`, ... | One historical cabinet set is available to all components. |
| `GlobalCabinetNamed` | `SETUP_1.CAB`, `SETUP_2.CAB`, ... | One modern named cabinet set is available to all components. |
| `PerComponentCabinetsExtensionless` | global parts plus `SETUP_<ID>_<N>` | Transitional per-component ownership without `.CAB` resource suffixes. |
| `PerComponentCabinetsNamed` | global parts plus `SETUP_<ID>_<N>.CAB` | Current component-owned cabinet route. |
| `MixedCabinetNames` | named and extensionless parts coexist | Structurally valid custom or transitional media; each logical set is validated independently. |

## Source references

- [dotNetInstaller repository](https://github.com/dotnetinstaller/dotnetinstaller)
- [InstallerLinker resource writer](https://github.com/dotnetinstaller/dotnetinstaller/blob/master/InstallerLib/InstallerLinker.cs)
- [Configuration loader](https://github.com/dotnetinstaller/dotnetinstaller/blob/master/dotNetInstaller/ConfigFileManager.cpp)
- [Component extraction](https://github.com/dotnetinstaller/dotnetinstaller/blob/master/dotNetInstallerLib/ExtractComponent.cpp)
- [UI mode fallback](https://github.com/dotnetinstaller/dotnetinstaller/blob/master/dotNetInstallerLib/InstallUILevel.cpp)
- [Command-line parser](https://github.com/dotnetinstaller/dotnetinstaller/blob/master/dotNetInstallerLib/InstallerCommandLineInfo.cpp)
