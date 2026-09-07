# Actual Installer parser implementation

## Module boundaries

Actual Installer is implemented in `Modules/PackageModule/Libraries/Installers/ActualInstaller.psm1`. Physical route data is isolated in `ActualInstallerFormatCatalog.psd1`. Generic PE, binary search, bounded-range copying, ZIP handling, cabinet extraction, path safety, collision behavior, INI decoding, registry association projection, and structured diagnostics remain in shared infrastructure.

The family parser owns only Actual Installer semantics: which container is metadata, how physical entries map to `[Files]`, which setup keys represent identity and scope, and when built-in ARP evidence is valid.

## One-pass analysis context

Every top-level information or extraction operation builds one logical layout.

```text
Get-ActualInstallerLayout
+-- resolve source path
+-- validate PE and obtain overlay boundary
+-- discover bounded CAB sequence; otherwise discover bounded ZIP ranges
+-- locate exactly one metadata configuration
+-- select physical route
+-- decode configuration once
+-- parse [Files] once
`-- join logical records to physical payload entries
```

The resulting context contains resolved path, file length, PE layout, overlay offset, selected route, ordered containers, metadata container and entry, parsed configuration, file records, and payload catalog. Callers reuse it instead of reopening and reparsing every layer for each metadata field.

## Detection route

Detection is strict and content-first.

1. Resolve the filesystem path before managed code opens it.
2. Require a valid PE layout.
3. Search from the PE overlay for complete CAB candidates. If none survive, enumerate complete embedded ZIP ranges.
4. Require exactly one accepted container to contain `setup.ini` or `aisetup.ini`.
5. Match container kind, metadata name, and metadata position to one catalog route.
6. Decode the bounded configuration.
7. Require a `[Setup]` section with literal nonempty `AppName`.
8. Require at least one valid numeric `[Files]` row.
9. Build the physical/logical payload map under count and range limits.

`Test-ActualInstaller` returns false on any failed invariant. `Get-ActualInstallerInfo` and extraction operations throw because a caller explicitly selected this family.

PE version resources and marker strings do not satisfy detection. They can remain weak analyzer hints, but the parser must reject an ordinary PE containing `aisetup.ini` as text.

## Route dispatch

The format catalog maps physical evidence to `Cabinet3`, `Cabinet4`, `Cabinet5`, `Zip6Plus`, or `ZipExternalData`. The configured builder major version is checked only after selection. A mismatch emits `ActualInstaller.Format.VersionRouteMismatch`; the parser keeps the structural route because applying a version-selected decoder could reinterpret unrelated bytes.

This design makes future extension explicit. A new metadata position, archive type, or payload identity requires a new route record and fixtures. A new INI key within an existing physical route usually belongs to metadata interpretation instead.

## Cabinet discovery

Cabinet discovery searches for `MSCF` after the PE overlay boundary with a fixed maximum candidate count. For each candidate it validates the 36-byte header, version, complete length, CFFILE table offset, file count, each 16-byte record, filename terminator, and decoded nonempty filename. `AcceptedEnd` prevents an `MSCF` byte sequence inside a validated cabinet from becoming another top-level archive.

The parser reads only catalog metadata at discovery time. It materializes one exact cabinet range into a temporary file only when the shared cabinet decoder needs a path for metadata or selected payload extraction. Temporary roots are removed in `finally`.

## ZIP discovery

ZIP discovery delegates exact range derivation to `Get-EmbeddedZipArchiveRange` and opens each range through shared archive infrastructure. It enumerates central-directory entries, rejects empty or excessive archives, and closes every context in `finally`. A malformed candidate is skipped during discovery; once a route is selected, disappearance or corruption of a previously validated selected entry is an error.

## Configuration parsing

The parser enforces a 4 MiB configuration limit. ZIP metadata is read directly into a bounded byte array. Cabinet metadata is selected into a temporary file. Both paths use the same INI semantics: encoding detection, merged repeated sections, last duplicate key, and comment exclusion.

`Get-ActualInstallerDictionaryValue` provides explicit key precedence. New aliases should be added only when observed media proves they have the same meaning. A missing key is different from a present empty key.

## Information projection

`Get-ActualInstallerInfo` composes the common parser contract from the layout and decoded tables. It returns:

- Common identity, ARP, scope, path, and diagnostic properties.
- Structural route and builder-version evidence.
- The parsed configuration, embedded `PayloadCatalog`, optional `CompanionPayloadCatalog`, and combined `InstalledPayloadCatalog`, all stripped of live archive objects.
- Bounded container summaries.
- Registry operations, statically projectable registry writes, custom ARP groups, protocols, typed file extensions and shortcuts, bounded command conditions, command applicability, and variables.
- Compiled setup policy, requirements, media sources, documented setup switches, and the complete documented exit-code evidence map.
- Selective architecture and dependency evidence from the configured main executable and bounded adjacent sidecars.

The parser keeps raw facts provider-neutral. WinGet-specific default suppression and manifest suggestions belong to `Get-WinGetInstallerAnalysis`, not the raw family result.

## Extraction route

Normal extraction filters available payload records by the optional wildcard `Name`. Omission means all available installed files. Each destination goes through the shared safe target resolver and reserves its case-insensitive output identity before writing.

Selections are grouped by physical container. A ZIP range is opened and enumerated once before all exact source-name selections are exported. A cabinet range is materialized once and passed to one cabinet selection operation. Aggregate expanded bytes are checked before writing, and destination order remains the logical selection order.

`CollisionAction` supports `Prompt`, `Error`, `Skip`, `Overwrite`, and `Rename`. `Prompt` asks only after an actual collision. Internal parser callers use `Rename` to avoid interaction.

Raw mode copies validated physical ranges under `_actual`. It applies the same wildcard, collision, and output bounds but does not decompress their contents.

Metadata-entry mode selects entries from the already validated metadata container and writes them under `_actual\metadata`. Setup EXE + Data analysis and extraction accept an explicit local `CompanionFile`, validate the compiled filename and size, require a SevenZip archive, reject links, encryption, duplicates, and unsafe paths, and map the source tree below the extraction root. Neither path performs network discovery.

`CommandApplicability` projects published gates: timing, Launch-on-OS selection, `-nocmdifsilent`, and `-nocmdifupdate`. A bounded evaluator resolves simple `IF` comparisons when both operands are literals or deterministic installer variables. It leaves runtime operands, unsupported grammar, and `IFMSG` as unknown and never reads host state. `ExternalArchivePlans` recognizes documented `ZIP:` commands and the observed download-plus-7za sequence while leaving execution and network retrieval to the runtime.

Generated outputs are route capabilities. Cabinet5 and numbered-ZIP generated uninstallers use `ExactCopy` because installed 5.2, 8.0, and 8.4 binaries matched their metadata helpers byte for byte. Extraction writes those helpers to the configured uninstaller destination. No equivalent claim is made for generated updater helpers or older routes.

If no selected file survives availability and wildcard filtering, extraction throws instead of reporting an empty successful operation.

## Diagnostics

Raw parser diagnostics are context-neutral. Current family diagnostics include:

| ID | Meaning |
| --- | --- |
| `ActualInstaller.Metadata.DynamicVersion` | `AppVersion` is an unresolved build/runtime expression |
| `ActualInstaller.Format.VersionRouteMismatch` | Builder-version evidence conflicts with the validated physical route |
| `ActualInstaller.ARP.LegacyKeyUnresolved` | Visible ARP intent exists but the supported legacy configuration does not expose key identity |
| `ActualInstaller.ARP.MultipleCustomEntries` | More than one complete custom uninstall key prevents selection of one ProductCode |
| `ActualInstaller.Architecture.UnknownConfiguration` | An explicit architecture enum is not source-backed and remains unresolved |
| `ActualInstaller.Configuration.EncodedCommandsDecoded` | Guarded XOR-2 decoding recovered recognized command fields |
| `ActualInstaller.Registry.RuntimeExpression` | Registry operations with runtime-only keys or values were retained but excluded from static projection |
| `ActualInstaller.Commands.RuntimeCondition` | Command conditions require runtime or interactive evidence |
| `ActualInstaller.Installability.SilentDisabled` | Compiled setup policy rejects `/S` |
| `ActualInstaller.Extraction.CompanionDataRequired` | The setup expects a caller-supplied 7z data file |
| `ActualInstaller.Extraction.CompanionDataAnalyzed` | A caller-supplied companion archive contributed bounded payload evidence |
| `ActualInstaller.Extraction.RuntimeDownload` | Runtime commands or variables fetch payload data that static parsing will not download |
| `ActualInstaller.Extraction.GeneratedHelperExactCopy` | A generated uninstaller can be reconstructed as a verified exact helper copy |
| `ActualInstaller.Extraction.GeneratedTemplateOutput` | A helper exists, but final bytes are not established for that output kind or route |
| `ActualInstaller.Extraction.MissingPayload` | A logical row has neither a direct payload nor a unique helper template |
| `ActualInstaller.Payload.MainExecutableUnresolved` | The configured main executable cannot be selected uniquely from installed payloads |
| `ActualInstaller.Payload.AnalysisLimit` | The bounded architecture/dependency sidecar selection exceeded its analysis limit |
| `ActualInstaller.Payload.ArchitectureAnalysisFailed` | PE architecture analysis failed for a selected payload file |
| `ActualInstaller.Payload.DependencyAnalysisFailed` | dependency analysis failed for a selected payload file |

Registry association helpers can add their own structured diagnostics. Scenario policy is applied later by full analysis, manifest authoring, manifest update, or extraction workflows.

## Bounds

| Resource | Current bound or rule |
| --- | --- |
| Configuration | 4 MiB |
| CAB candidates | 4096 |
| Logical/archive entries | 65536 |
| Embedded ZIP archives | 64 during discovery |
| CAB filename | 4096 bytes before NUL required |
| Extraction output | 16 GiB default aggregate, caller-reducible |
| Selective payload analysis | 32 files and 64 MiB aggregate |
| Companion catalog | 65536 entries and 16 GiB declared output by default |
| Paths | Shared traversal, root, reserved-name, and duplicate checks |

The shared archive and cabinet layers can impose stricter secondary bounds. Family limits do not weaken them.

## Stream and object ownership

The parser opens streams in the smallest helper that owns them and disposes them in `finally`. Embedded ZIP and explicit companion contexts remain open only across one batched selection or one top-level analysis pass. Public payload catalogs remove native archive entries and live container handles. Temporary files exist only for cabinet APIs requiring filesystem paths and selective PE analysis.

## Performance rules

- Do not read the complete setup into a byte array.
- Search only the overlay region for CAB signatures.
- Parse the configuration and file table once per top-level operation.
- Open each selected ZIP range once per operation, regardless of selected entry count.
- Materialize each selected CAB once per operation.
- Keep large payload bytes out of PowerShell object arrays.
- Return serializable evidence instead of archive objects or open streams.

The diagnostic benchmark harness accepts `-ActualInstallerPath` and optional `-ActualInstallerCompanionFile`. On PowerShell 7.6.5, the 11.9 MB fixed 9.6 fixture completed warm parser analysis in about 1.15 seconds with 109 MB allocated and full extraction in about 0.99 seconds with 104 MB allocated. The controlled 9.6 hybrid plus companion completed analysis in about 0.93 seconds and extraction in about 0.75 seconds. Peak process working set was about 311-320 MB because each isolated benchmark process includes the complete PackageModule import; these measurements are evidence, not CI thresholds.

## Extension checklist

Before adding support for another generation:

1. Cache a durable artifact and record its hash and provenance outside the repository.
2. Prove the exact container sequence and metadata entry.
3. Compare configuration grammar with existing routes.
4. Add a catalog route only for a physical change.
5. Add synthetic malformed-range coverage and a real fixture assertion.
6. Validate metadata and ARP against a checkpointed VM when static semantics affect package matching.
7. Keep unresolved dynamic behavior diagnostic rather than inventing a fallback.

## Implementation references

- `Modules/PackageModule/Libraries/Installers/ActualInstaller.psm1`
- `Modules/PackageModule/Libraries/Installers/ActualInstallerFormatCatalog.psd1`
- `Modules/PackageModule/Tests/Installers/ActualInstaller.Tests.ps1`
