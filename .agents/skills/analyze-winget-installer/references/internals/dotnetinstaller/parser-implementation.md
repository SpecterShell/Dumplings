# dotNetInstaller parser implementation

## Detection

Normal detection requires a valid PE, exactly one bounded `CUSTOM/RES_CONFIGURATION` resource, a decodable XML document rooted at `configurations`, and valid structural limits. An explicit `-ConfigurationPath` can replace the primary document only when compiled dotNetInstaller runtime capabilities also identify the PE. Cabinet presence is not required for configuration-only media.

## Parse pipeline

1. Resolve and open the installer once.
2. Parse the PE layout and resource directory.
3. Decode the primary XML and resolve caller-supplied reference documents.
4. Classify cabinet resources into logical sets.
5. Project configurations, filters, components, commands, controls, checks, and downloads.
6. Resolve payload references against embedded and companion namespaces.
7. Extract and parse only configured nested MSI files.
8. Compose identity, modes, switches, ARP evidence, diagnostics, and unresolved fields.

`Open-DotNetInstallerContext` owns temporary cabinet staging and disposes it after the top-level operation. Detection skips staging. Information parsing and extraction enumerate each logical cabinet set once.

## Extraction

`Expand-DotNetInstaller` extracts one matching name or all embedded files. Omitted `-Name` means all files. Companion files are copied only when explicitly supplied. Shared filesystem helpers resolve source and destination paths, enforce safe relative output, and apply `Prompt`, `Error`, `Skip`, `Overwrite`, or `Rename` only when a collision occurs. Internal callers use `Rename`.

## Diagnostics

Configuration reference failures identify the affected identity and installability fields. Missing or ambiguous payloads affect ProductCode and Apps & Features evidence. Outer mode support with unproven nested routes affects `InstallModes` and `InstallerSwitches`. Silent completion commands are risk diagnostics. Raw parser results remain scenario-neutral; analyzer and manifest-update callers assign level and blocking policy.

## Bounds

| Input | Limit |
| --- | --- |
| one configuration document | 16 MiB |
| supplied reference XML aggregate | 64 MiB |
| reference documents | 1,024 |
| reference depth | 10 |
| XML elements per document | 65,536 |
| configurations per document | 1,024 |
| components, downloads, or controls | 16,384 each |
| `RES_CAB_LIST` | 4 MiB |
| cabinet resources | 4,096 |
| one cabinet resource | 1 GiB |
| total compressed cabinet input | 4 GiB |
| files per cabinet set | 65,536 |
| supplied companion files | 4,096 |

Shared PE, cabinet, archive, bounded-stream, and filesystem helpers add offset, size, checksum, traversal, duplicate-path, collision, and aggregate-output checks.

## Performance

PE resources and the primary XML are parsed once. Each selected reference document and companion MSI is parsed once. Runtime token scans exclude resource sections. Repeated locale or mode routes to one MSI share extraction and MSI database parsing. CodeMeter Runtime 9.10 contains fifteen command occurrences for one 182,786,040-byte MSI-bearing wrapper; the parser retains all occurrences while opening the MSI once.

