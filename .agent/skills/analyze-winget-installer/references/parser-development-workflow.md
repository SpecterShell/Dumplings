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

```powershell
.\Modules\PackageModule\Tests\Benchmark-InstallerParsers.ps1 `
  -NSISPath <path> `
  -ChromiumPath <path> `
  -QtInstallerFrameworkPath <path> `
  -Install4jPath <path> `
  -OutputPath $env:TEMP\DumplingsParserBenchmarkResults.json
```
