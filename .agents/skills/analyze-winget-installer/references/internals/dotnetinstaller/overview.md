# dotNetInstaller internals

This reference describes the dotNetInstaller file format and runtime behavior needed for static analysis. For package authoring, use the [dotNetInstaller workflow](../../families/dotnetinstaller/workflow.md).

Read [binary notation](../../parser-development/binary-notation.md), [parser contracts](../../parser-development/contracts.md), and [performance guidance](../../parser-development/performance.md) before changing the parser.

## Release history and compatibility boundaries

The upstream repository contains imported history back to the 1.x line and release tags for 2.1, 2.2, 2.3, 2.4, 3.0.812, 3.0.814, 3.1.415, and 3.2.115. The bootstrapper remains a PE resource wrapper throughout this history, but its XML storage, cabinet ownership, resource names, and command-line capabilities changed at separate points.

| Boundary | Upstream change | Static consequence |
| --- | --- | --- |
| Early 1.x | `/q`, configuration XML, and one global embedded cabinet set | Silent mode exists, but later switches and per-component extraction cannot be assumed. |
| 2009-02-22 | Ordered mixed XML children replaced plural grouping nodes | Both grouped and ordered XML must be accepted. |
| 2009-04-25 | `/qb` and basic UI mode added | `silentWithProgress` is available only when the compiled runtime contains the `qb` command token. |
| 2009-10-29 | User splash resources and `/nosplash` added | `/nosplash` must be capability-tested rather than inferred from a splash resource. |
| 2009-12-01 | Component files moved into independently extracted cabinet sets | Resource names begin carrying normalized component IDs. |
| 2009-12-09 | Embedded cabinet resource names gained `.CAB` | Extensionless and named cabinet resources require separate staging rules. |
| 2010-07 | Native and HTML launchers shared the same configuration and cabinet model | `HTM` resources identify the HTML launcher without changing payload semantics. |
| 2010-08-26 | `/noreboot` added and required-reboot exit code propagation changed | No-reboot behavior is available only when the compiled runtime contains the `noreboot` token. |

InstallerLinker writes the packaged application's `fileversion`, `productversion`, and version-resource strings into the output. Those values do not identify the dotNetInstaller runtime. Current runtimes compare the configuration's `schema.version` with their compiled `VERSION_VALUE`; the parser reports `RuntimeVersion` only when that structured schema value also occurs as an exact null-terminated token in non-resource PE data. Pre-schema media and mismatched sidecar configurations retain an unknown runtime version.

## PE resource layout

```text
PE bootstrapper
+-- executable and data sections
|   `-- native launcher and exact command-line parameter tokens
`-- .rsrc
    +-- CUSTOM / RES_CONFIGURATION    XML bytes; normal packaged route
    +-- CUSTOM / RES_CAB_LIST         UTF-16 display summary; optional and possibly truncated
    +-- CUSTOM / RES_BANNER           UI bitmap; optional
    +-- CUSTOM / RES_SPLASH           splash image; optional
    +-- HTM / ...                     HTML launcher pages; optional
    `-- RES_CAB / <resource name>      complete or continued Microsoft Cabinet member
        +-- 4D 53 43 46 ("MSCF")
        +-- cabinet folders and file catalog
        `-- compressed payload data
```

PE resource entries provide a file offset and bounded size. `RES_CONFIGURATION` is decoded as UTF-8 by InstallerLinker output, with BOM-marked UTF-16 accepted for hand-authored historical configurations. `RES_CAB_LIST` is display evidence only: upstream deliberately truncates long file lists, and extraction code derives cabinet names independently.

## Cabinet resource routes

The parser classifies physical cabinet ownership separately from XML generation and launcher capability profile.

| Route | Resource names | Meaning |
| --- | --- | --- |
| `ConfigurationOnly` | no `RES_CAB` entries | Online, external, bare, or otherwise configuration-only launcher. |
| `GlobalCabinetExtensionless` | `SETUP_1`, `SETUP_2`, ... | Historical single logical cabinet set. The staged filenames gain `.CAB` because the cabinet continuation metadata uses filenames. |
| `GlobalCabinetNamed` | `SETUP_1.CAB`, `SETUP_2.CAB`, ... | One global cabinet set using post-2009 resource naming. Modern packages can still use this route when all files are global. |
| `PerComponentCabinetsExtensionless` | global `SETUP_N` plus `SETUP_<ID>_N` | Short transitional route after component cabinet ownership was introduced and before `.CAB` was added to resource names. |
| `PerComponentCabinetsNamed` | global `SETUP_N.CAB` plus `SETUP_<ID>_N.CAB` | Current per-component route. |
| `MixedCabinetNames` | a mixture of named and extensionless sets | Structurally parseable custom or transitional media; retain the mixed route as evidence. |

`N` is a one-based contiguous part number. Duplicate parts, a missing first part, gaps, malformed cabinet headers, or oversized catalogs invalidate extraction.

Component IDs are converted to cabinet keys by uppercasing letters and replacing every non-alphanumeric character with `_`. The empty key identifies the global set. Files from the global set are available to every component; files from `SETUP_<ID>_N` are available only to the matching normalized component ID.

## Configuration XML layouts

The document root is `configurations`. Current documents store `configuration`, `component`, `embedfile`, `embedfolder`, `downloaddialog`, installed-check, and control nodes in authored order. Pre-2009 documents can group records under `components`, `embedfiles`, and `downloads`; the runtime reads those groups for backward compatibility.

```text
configurations
+-- schema                         editor/schema evidence
+-- fileattributes                output PE version-string values
+-- configuration type="install"
|   +-- component                 ordered install or uninstall action
|   |   +-- installedcheck...
|   |   +-- downloaddialog...
|   |   `-- embedfile/embedfolder...
|   +-- global embedfile/embedfolder...
|   +-- controls and checks
|   `-- complete_command[_basic|_silent]
`-- configuration type="reference"
    +-- configfile filename="..."
    `-- downloaddialog...
```

A reference configuration loads another XML document at runtime. `-ReferencedConfigurationPath` supplies trusted local candidates without network access. The parser follows only files selected by authored `configfile.filename` values, preserves global configuration indices and document provenance, parses each physical file once, rejects cycles and chains beyond the runtime's ten-level limit, and records missing, ambiguous, schema-conflicting, and unused inputs. `-ConfigurationPath` replaces the primary resource configuration and models the launcher's `/ConfigFile` route.

Historical aliases remain significant. Current `display_name`, `required_install`, `selected_install`, and `lcid_filter` values take precedence when authored; legacy `description`, `required`, `selected`, and `lcid` values are fallbacks. Missing `id` falls back to the resolved display name. Numeric `os_filter_greater` and `os_filter_smaller` are retained separately from current `os_filter_min` and `os_filter_max`.

## Component records and execution

Supported component types are `msi`, `msp`, `msu`, `exe`, `cmd`, and `openfile`. The `openfile` target is stored in the `file` attribute. Commands can refer to `#CABPATH`, download destinations, the application directory, temporary paths, or other runtime variables. `#CABPATH` resolves only against the component's embedded cabinet namespace; `#TEMPPATH`, `#APPPATH`, and `#STARTPATH` resolve only against explicit `-CompanionPath` files. Download declarations alone prove an intended destination, not that bytes were acquired.

For each command-bearing attribute, dotNetInstaller uses this UI selection order:

```text
Requested full:    full
Requested basic:   basic -> silent -> full
Requested silent:  silent -> basic -> full
```

The same fallback applies to uninstall attributes and post-install `complete_command`, `complete_command_basic`, and `complete_command_silent`. `wait_for_complete_command` controls whether the launcher waits for that command. The parser records the selected attribute, source mode, fallback state, and conservative unattended proof for every command. Static analysis retains post-install commands because they may launch the installed application even when all component installers completed unattended.

`msi`, `msp`, and `msu` components are normalized into their `msiexec.exe` or `wusa.exe` command lines. MSI and MSP uninstall routes follow `uninstall_package`, `uninstall_patch`, and `uninstall_cmdparameters*` with the runtime's empty-value fallback. EXE response-file, install-directory, uninstall-executable, execution-method, working-directory, reboot, progress, and error-policy attributes remain structured component evidence. `cmd` and `openfile` records preserve the authored command. Payload selection uses exact logical paths, resolved host-path suffixes, and finally a unique basename. Multiple basename matches remain explicit ambiguity.

Configuration controls are retained as inert typed attribute trees. Product installed checks are also projected into `InstalledProductChecks` with their product or upgrade identifier, property comparison, and owning component. These checks describe prerequisite or route detection and are never promoted automatically to the wrapper ProductCode.

## Runtime capability profile

The parser scans only non-resource PE sections for null-terminated command-line parameter tokens. This avoids scanning large embedded cabinet resources and remains valid when linker output replaces version strings. Exact schema/runtime-version confirmation uses the same bounded section set.

| Profile | Proven capabilities |
| --- | --- |
| `LegacyQuiet` | `/q`; later options are absent. |
| `BasicUI` | `/q` and `/qb`. |
| `SplashControl` | `/q`, `/qb`, and `/nosplash`. |
| `RebootControl` | `/q`, `/qb`, `/nosplash`, and `/noreboot`. |
| `Unknown` | The expected quiet token was not found; do not author unattended switches from family identity alone. |

Logging requires both `log` and `logfile` tokens before the parser suggests `/Log /LogFile "<LOGPATH>"`. `ComponentArgs` is reported as a capability but is not added automatically. It appends values to matching component commands and can break mixed `exe`, `cmd`, `msu`, and `openfile` chains when a blanket MSI argument is applied.

## Nested payload and ARP ownership

The dotNetInstaller launcher does not normally create the final visible Apps & Features row. The selected nested component owns it. The parser resolves each component command against that component's global and private cabinet entries or explicitly supplied companions, then extracts or directly opens only configured MSI payloads.

One physical MSI can appear in several locale or filter configurations and in all three UI modes. It is extracted or opened and parsed once. `SourceKind` identifies cabinet or companion ownership. `Occurrences`, `ConfigurationIndices`, component IDs, configuration and component LCID filters, and configuration and component architecture filters retain every command route that selects it.

When exactly one distinct nested MSI is present, its ProductCode, UpgradeCode, display metadata, installer builder, install-location property, architecture evidence, registry associations, and Apps & Features evidence can be projected to the wrapper. The nested MSI's `ARPSYSTEMCOMPONENT` and related table evidence determines `WritesAppsAndFeaturesEntry`; a hidden MSI is not emitted as a visible ARP row. Multiple distinct MSIs remain separate evidence because runtime configuration filters determine which one applies. `Get-DotNetInstallerNestedMsiSelection` implements the runtime's all-positive OR or all-negated exclusion grammar for processor architecture and LCID filters. Mixed positive and negated tokens are invalid, matching the runtime.

## Detection and malformed input

Normal detection requires a valid PE, exactly one `CUSTOM/RES_CONFIGURATION` resource, a bounded XML document rooted at `configurations`, and valid XML structure. The explicit `-ConfigurationPath` route accepts a missing embedded resource only when the supplied document is valid and compiled runtime capability tokens identify dotNetInstaller. Cabinet resources are not staged during ordinary `Test-DotNetInstaller`; full analysis and extraction validate their resource names, part continuity, cabinet catalogs, expanded sizes, and paths.

The parser limits each configuration document to 16 MiB, supplied reference XML to 64 MiB in aggregate, reference documents to 1,024, reference nesting to the runtime's ten levels, XML elements to 65,536 per document, configurations to 1,024 per document, components, downloads, and controls to 16,384 each, `RES_CAB_LIST` to 4 MiB, cabinet resources to 4,096 entries and 4 GiB total compressed input, each resource to 1 GiB, each cabinet set to 65,536 entries and 4 GiB catalog output, XML recursion to 32 levels, supplied companions to 4,096 files, and caller-selected extraction output to the requested bound. Shared cabinet and filesystem helpers enforce checksum, traversal, duplicate-path, and collision rules.

## Performance model

The PE resources and primary configuration XML are parsed once per top-level operation. Each selected reference document and physical companion MSI is parsed once. Runtime capabilities are searched only in non-resource sections. Each logical cabinet set is staged and enumerated once. Repeated configuration routes to one MSI share one extraction or direct open and one MSI database parse.

The 182,786,040-byte CodeMeter Runtime regression contains five locale configurations and fifteen mode-specific references to one MSI. The one-artifact path reduced local analysis from about 14.1 seconds to about 10.4 seconds while preserving all route occurrences.

## Known gaps

- File, directory, registry, WMI, OS, and product-state conditions are preserved as structured evidence; product checks receive a focused projection, but the parser does not pretend to know the target machine state.
- Embedded and explicitly supplied MSI metadata is parsed directly. Nested EXE, script, and open-file side effects require the corresponding payload parser or VM validation.
- Runtime command semantics are modeled for MSI, MSP, MSU, EXE, CMD, and open-file components. Arbitrary external executables, response-file transformations, and completion-command side effects remain opaque.
- Exact runtime releases are available only when a structured schema value agrees with compiled runtime evidence. Pre-schema media retain structural and capability generations because output version resources belong to the packaged application.

## Implementation and fixtures

- `Modules/PackageModule/Libraries/Installers/DotNetInstaller.psm1`
- `Modules/PackageModule/Libraries/Installers/Bootstrapper.psm1`
- `Modules/PackageModule/Tests/Installers/DotNetInstaller.Tests.ps1`
- Official 2.3 and 3.2.115 packaged samples cover the stable named per-component route.
- A historical 1.3-era bare launcher covers configuration-only media and the `LegacyQuiet` profile.
- `Wibu-Systems.CodeMeterRuntimeKit` 9.10 covers a large modern global-cabinet wrapper with repeated locale routes to one WiX MSI.

## Source references

- [dotNetInstaller repository](https://github.com/dotnetinstaller/dotnetinstaller)
- [InstallerLinker cabinet and resource writer](https://github.com/dotnetinstaller/dotnetinstaller/blob/master/InstallerLib/InstallerLinker.cs)
- [Native configuration loader](https://github.com/dotnetinstaller/dotnetinstaller/blob/master/dotNetInstaller/ConfigFileManager.cpp)
- [Cabinet extraction and component ownership](https://github.com/dotnetinstaller/dotnetinstaller/blob/master/dotNetInstallerLib/ExtractComponent.cpp)
- [UI mode command fallback](https://github.com/dotnetinstaller/dotnetinstaller/blob/master/dotNetInstallerLib/InstallUILevel.cpp)
- [Command-line parameter parser](https://github.com/dotnetinstaller/dotnetinstaller/blob/master/dotNetInstallerLib/InstallerCommandLineInfo.cpp)
