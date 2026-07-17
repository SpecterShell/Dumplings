# Parser Development Workflow

## Boundaries

`Modules/PackageModule` is MIT-licensed and is loaded in-process by Dumplings. It owns bridges, task-facing helpers, MSI/MSIX/Burn support, portable analysis, and parsers whose source permits MIT distribution.

`Modules/InstallerParsers` is an independently consumable GPL command-line submodule. `Cli.ps1` is the process boundary used by `InstallerBridge.psm1`. NSIS, Inno, Qt Installer Framework, and Setup Factory are GPL-3.0-or-later; Advanced Installer is GPL-2.0. Do not move GPL implementation details into PackageModule.

The two submodules carry byte-identical MIT infrastructure files:

- `Runtime.psm1`: deterministic C# and managed-assembly loading.
- `Binary.psm1`: bounded ranges, seekable spill streams, pattern search, CRC32, endian reads, and safe paths.
- `Compression.psm1`: LZMA, LZMA2, BZip2, Zlib, Deflate, and BCJ2 streams.
- `Archive.psm1`: SharpCompress archive entries and bounded export.
- `PE.psm1`: PE layout, resources, imports, CLR headers, and managed target-framework metadata.
- `RegistryAssociations.psm1`: protocol and file-extension evidence.
- `Assets/InstallerInfrastructure/*.cs`: auditable mechanical hot paths compiled once with `Add-Type`.

Pester compares mirrored source and pinned SharpCompress/ZstdSharp assets by SHA-256. Modify both copies in one patch.

## Loading

PackageModule `Index.ps1` and InstallerParsers `Cli.ps1` load infrastructure in this order:

1. `Runtime.psm1`
2. `Binary.psm1`
3. `Compression.psm1`
4. `Archive.psm1`
5. `PE.psm1`
6. `RegistryAssociations.psm1`
7. Format-specific modules

Format modules may call already-loaded module functions. Do not add parser-local `Import-Module` calls or duplicate dependency loaders.

## Stream Rules

- Public parser and bridge APIs stay path-based. One parser operation opens the installer once and passes its stream and parsed layout internally.
- Random-access helpers restore caller stream position. Caller-provided streams are never disposed.
- `Copy-BoundedStream` and `Expand-InstallerCompressedStream` are sequential and consume from the current position.
- Use `New-BoundedReadStream` for every embedded range. Never expose “offset to end of installer” when a format supplies an exact length.
- Use `New-InstallerSeekableStream` for non-seekable nested content. It keeps up to 16 MiB in memory by default, then spills to an automatically deleted temporary file.
- Apply format-specific limits in addition to shared outer limits. Declared sizes, actual output, entry count, paths, links, duplicate outputs, and CRC must all be validated.
- Do not use `ReadAllBytes` for installers. Small, explicitly bounded metadata records may be materialized as byte arrays.

## C# Criteria

Keep format interpretation in PowerShell. C# is appropriate for chunked pattern search, bounded stream adapters, CRC32, PEReader access, byte transforms, and other measured loops where PowerShell adds material CPU or allocation cost. Source must remain visible, narrowly scoped, licensed, and covered by PowerShell contract tests. Do not add opaque custom DLLs or a restore/build step.

## Output Contract

Parser results should retain stable properties used by tasks and the analyzer. Add evidence rather than replacing metadata fields:

- identity: `DisplayName`, `DisplayVersion`, `Publisher`, `ProductCode`, `UpgradeCode`
- installation: `Scope`, `SupportedScopes`, architecture evidence, switches
- ARP: `WritesAppsAndFeaturesEntry`, visible entry type, registry writes, `SystemComponent`
- wrappers: `ExtractedFiles`, `ExecutedPayloads`, nested payload type and arguments
- associations: `Protocols`, `FileExtensions`, `RegistryAssociationInfo`
- diagnostics: `Warnings`, `ParserVersionInfo`

## Adding A Parser

1. Add format detection from magic bytes or structured records, not extension or arbitrary product strings.
2. Reuse the shared stream, archive, PE, compression, and association APIs.
3. Implement `Get-*Info` first; add `Test-*`, `Expand-*`, and one-line `Read-*` helpers only when they clarify public behavior.
4. Bridge GPL parsers through a new `Cli.ps1` action and PackageModule wrapper. Keep the bridge generic.
5. Add malformed, traversal, output-limit, and at least three real-installer regressions where fixtures are stable.
6. Document family-only behavior and public commands in its focused page. Do not create a second central API inventory.

Run parity, parser contracts, ScriptAnalyzer, documentation validation, and `git diff --check`.

## Optimization Workflow

Optimize measured work rather than rewriting a parser wholesale:

1. Establish stable real fixtures and malformed synthetic fixtures. Record three or more fresh-process samples before changing code, then profile parser stages for elapsed time and cumulative managed allocation.
2. Reduce work before tuning loops. Probe the outer format once, rank structurally plausible parsers, stop after a validated match, and defer heavyweight assemblies until their family is selected.
3. Use one aggregate `Get-*Info` result. Do not call scalar `Read-*` helpers after `Get-*Info`, reopen the same database/archive for each field, or bridge the same GPL parser repeatedly.
4. Keep one installer stream and parsed binary context per operation. Parse payload catalogs before payload data, select exact architecture/name entries, and materialize only metadata or the nested payload that the bootstrapper invokes.
5. Prevent PowerShell output expansion. Return binary values as a non-enumerated `byte[]`; add a type regression test for every binary-returning helper. Avoid byte-array range expressions, pipeline filters in record loops, and `@(...)` around scalar results.
6. Parse scalar requests as scalars. Seek directly to a fixed-size indexed record instead of producing every record as `PSCustomObject[]`. Use typed collections only when the public contract genuinely returns multiple values.
7. Allocate from declared sizes when bounded and trustworthy. Avoid `List[byte]` growth plus `ToArray()` copies. Reuse or pool transfer buffers, spill seek-required content above the memory threshold, and keep decompressed-output limits separate from memory limits.
8. Move only measured mechanical hot loops to narrow, source-visible C#. Format interpretation, validation policy, and result construction stay in PowerShell.
9. Preserve semantic evidence while optimizing: hashes, CRCs, selected-entry identity, stream ownership, decoded-byte counts, file-open counts, parser invocation counts, limits, warnings, and malformed-input behavior.
10. Benchmark stream wrappers with the real decoder. A generic seekable bounded stream can be worse for a sequential decoder that performs many small reads because every wrapper seek becomes a file seek. When the format and decoder already accept an exact compressed-size bound, use a dedicated sequential file stream at the payload offset, pass that bound to the decoder, and verify both declared input and exact decoded output. Reject abstractions that improve code uniformity while regressing measured time or allocation.

Interpret metrics carefully. `GC.GetTotalAllocatedBytes()` measures cumulative allocation churn, not live memory; peak working set includes the PowerShell runtime and loaded assemblies. Report cold end-to-end time separately from parser-operation time. Solid compression can require decoding a large prefix before a small selected file, so catalog parsing may reduce metadata work without eliminating that format-imposed cost. Performance targets are review gates, not wall-clock CI assertions.

## Performance Validation

Use `Modules\PackageModule\Tests\Benchmark-InstallerParsers.ps1` with stable cached fixtures when changing binary I/O or decompression. Record elapsed time and peak working set as diagnostic evidence, never as flaky CI thresholds.

The 2026-07-11 stream-refactor sample used PowerShell 7.6.3 and fresh hidden processes:

| Parser | Fixture bytes | Elapsed ms | Peak working set bytes |
| --- | ---: | ---: | ---: |
| NSIS | 489,070,416 | 7,721 | 340,234,240 |
| Chromium Setup | 489,181,096 | 1,648 | 220,827,648 |
| Qt Installer Framework | 37,964,976 | 2,280 | 210,432,000 |
| install4j | 96,658,232 | 6,321 | 701,276,160 |

The available pre-refactor NSIS baseline used 639,787,008 peak bytes and 1,704 ms on the same CCFLink fixture. The parser traded CPU for roughly 47% lower peak working set, but the baseline predates semantic changes and is directional only.

The 2026-07-17 Inno targeted-extraction refactor used PowerShell 7.6.3 and medians from three fresh processes. The parser now reads one requested location record, allocates chunked metadata once, preserves `byte[]` values across PowerShell branches, reuses a pooled payload buffer, and performs the source-backed CALL/JMP transform in narrow GPL C#.

| Operation | Fixture bytes | Before ms | After ms | Time change | Before allocated MiB | After allocated MiB | Allocation change |
| --- | ---: | ---: | ---: | ---: | ---: | ---: | ---: |
| Kiro metadata | 170,403,336 | 797.46 | 674.53 | -15.4% | 67.48 | 66.98 | -0.8% |
| Kiro `Kiro.exe` extraction | 170,403,336 | 9,595.85 | 7,434.86 | -22.5% | 3,129.08 | 2,900.82 | -7.3% |
| WinSCP metadata | 12,317,368 | 686.35 | 697.02 | +1.6% | 70.08 | 69.45 | -0.9% |
| WinSCP `WinSCP.exe` extraction | 12,317,368 | 1,644.95 | 1,639.07 | -0.4% | 436.65 | 333.26 | -23.7% |
| BankLink metadata | 16,953,152 | 654.54 | 657.20 | +0.4% | 53.84 | 54.88 | +1.9% |
| BankLink `BK5WIN.EXE` extraction | 16,953,152 | 1,601.12 | 1,379.35 | -13.9% | 732.90 | 269.15 | -63.3% |

Kiro's target begins after a 308,164,848-byte solid LZMA prefix. SharpCompress must decode that prefix sequentially, so its cumulative allocation remains proportional to decoded output even though the parser no longer constructs all location objects or copies the solid payload.

The 2026-07-17 Chromium Setup refactor used medians from three fresh PowerShell 7.6.3 processes. It parses PE layout, resources, and certificate tags once; applies Chromium's `B7` > `BL` > `BN` setup precedence; and reads Omaha's offline manifest directly from the decoded TAR. A first implementation that spooled LZMA through a generic bounded stream was rejected after Brave rose to 15,592 ms and 9,529 MiB cumulative allocation. The retained implementation uses Omaha's declared compressed size with a dedicated sequential source and exact output checks.

| Fixture | Before ms | After ms | Before allocated MiB | After allocated MiB |
| --- | ---: | ---: | ---: | ---: |
| Chrome mini-installer | 261.98 | 260.65 | 38.19 | 38.87 |
| Chromium Updater | 276.94 | 264.90 | 40.96 | 41.06 |
| Legacy Omaha | 268.45 | 260.98 | 39.04 | 38.75 |
| Brave standalone Omaha | 10,191.68 | 10,676.68 | 64.38 | 59.70 |
| Vivaldi mini-installer | 262.29 | 259.83 | 37.81 | 38.27 |
| Edge WebView2 standalone Omaha | 13,778.45 | 13,764.01 | 65.62 | 60.71 |

The large Omaha fixtures reduced cumulative allocation by about 7.4%; elapsed time was neutral for Edge and 4.8% slower for Brave in this sample. Treat that Brave delta as a residual regression to watch, not as an improvement. The small-layout results mainly validate that one-pass PE parsing did not add meaningful cost.

```powershell
.\Modules\PackageModule\Tests\Benchmark-InstallerParsers.ps1 `
  -NSISPath <path> `
  -ChromiumPath <path> `
  -InnoPath <path> `
  -InnoExtractName <exact-payload-name> `
  -QtInstallerFrameworkPath <path> `
  -Install4jPath <path> `
  -OutputPath $env:TEMP\DumplingsParserBenchmarkResults.json
```
