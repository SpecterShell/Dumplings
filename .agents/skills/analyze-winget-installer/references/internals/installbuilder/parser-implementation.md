# InstallBuilder parser implementation

## Module boundaries

The Apache-2.0 implementation lives in `Modules/PackageModule/Libraries/Installers/InstallBuilder.psm1`. Its schema-specific Metakit reader lives in `Modules/PackageModule/Assets/Source/InstallBuilder/InstallBuilderMetakitReader.cs`. Shared PE, binary, compression, archive, path-safety, collision, dependency, association, condition, and diagnostic mechanics remain in their focused infrastructure modules.

The managed reader implements only the exact TclKit VFS schema used by verified InstallBuilder media. It does not load Metakit, Tcl, TclKit, or installer code. The PowerShell module owns project interpretation, CookFS2, payload mapping, runtime evidence, ARP reconstruction, extraction, and public result composition.

## Public API

| Function | Purpose |
| --- | --- |
| `Test-InstallBuilder` | Strict structural family detection without executing the installer |
| `Get-InstallBuilderInfo` | One-pass metadata, payload, ARP, action, requirement, and diagnostic analysis |
| `Expand-InstallBuilderInstaller` | Bounded extraction of `project.xml` and selected or all logical payload files |
| `Read-ProductVersionFromInstallBuilder` | Compatibility field reader over the full information result |
| `Read-ProductNameFromInstallBuilder` | Compatibility field reader over the full information result |
| `Read-PublisherFromInstallBuilder` | Compatibility field reader over the full information result |
| `Read-ProductCodeFromInstallBuilder` | Compatibility field reader over the full information result |
| `Read-ScopeFromInstallBuilder` | Compatibility field reader over the full information result |
| `Read-ProtocolsFromInstallBuilder` | Compatibility field reader over the full information result |
| `Read-FileExtensionsFromInstallBuilder` | Compatibility field reader over the full information result |

Prefer one `Get-InstallBuilderInfo` call. Individual readers exist for established API compatibility and should not be chained because each can repeat parsing.

## Analysis context

One top-level information call constructs and reuses these objects:

```text
resolved source file
+-- PE layout and requested execution level
+-- project record and parsed XML
+-- deterministic project context and variables
+-- all validated Metakit layouts
+-- optional CookFS2 layout and page cache
+-- physical and logical payload catalogs
+-- ordered actions and registry state
+-- associations, system effects, executions, and requirements
+-- ARP reconstruction
`-- merged structured diagnostics and unresolved fields
```

The project XML is parsed once. Each accepted Metakit archive is opened only for catalog or entry access and is disposed after use. The CookFS layout stores page offsets and sizes, not expanded page arrays. Expanded pages enter a bounded FIFO cache only when read.

## Detection route

Detection is content-first and intentionally stronger than branding:

1. Resolve the path and require a valid PE.
2. Require at least one `project.xml` marker as a bounded search anchor.
3. Locate candidate `JL 1A 00 00` and `LJ 1A 00 00` Metakit headers.
4. Validate the database length, commit tail, root descriptor, exact VFS schema, directory graph, and file catalog.
5. Select a VFS that owns an exact `project.xml` entry and parse that XML.
6. Probe for a structurally valid CookFS2 tail; its absence selects legacy payload handling when `origindist` is available.
7. Use bounded zlib project recovery only as a metadata-only fallback when no catalog can be decoded.

Product strings, PE company fields, switch strings, TclKit markers, and a bare `CFS0002` are hints only. Ordinary TclKit applications and marker-only files must fail strict detection.

## Multiple Metakit databases

An installer can contain more than one valid Metakit VFS. InstallBuilder 8.2.0 builder media contains two. The parser opens each candidate independently and selects ownership by exact required entry:

```text
project route -> VFS containing exact project.xml
legacy payload route -> VFS containing exact origindist control record
```

Physical order is not authority. If no single candidate owns the required entry, the route remains incomplete rather than using the first readable database.

## Project fallback

Old packed runtimes can contain thousands of incidental zlib-like bytes. The fallback first scans a bounded region around each `project.xml` marker for valid RFC 1950 CMF/FLG pairs, deduplicates offsets, and stops at the candidate limit. A whole-file bounded scan is used only when the local search finds nothing.

Each candidate is independently decompressed under the project limit, decoded with strict UTF-8, and accepted only when it contains a complete `<project>` root. The fallback returns `FormatGeneration: ProjectRecord`, which must not be treated as extraction support.

## Route dispatch

| Route | Selection | Metadata | Payload |
| --- | --- | --- | --- |
| `LegacyMetakit` | Valid project-owning VFS, no accepted CookFS2, readable `origindist` | Exact Metakit `project.xml` | VFS files below the origin directory, stored or zlib |
| `CookFS2` | Valid project-owning VFS plus accepted `CFS0002` tail and `CFS2.200` index | Exact Metakit `project.xml` | Page-backed CookFS logical entries |
| `ProjectRecord` | Valid bounded project XML but no readable owning VFS | Recovered project only | Unsupported |

Unknown compression or integrity handlers are represented in the CookFS result and diagnostics. They do not trigger a speculative route.

## Legacy payload projection

The managed Metakit reader returns validated VFS entry objects with path, logical size, stored size, absolute content offset, compression classification, and modification time. PowerShell reads `origindist`, identifies the package source subtree, joins physical paths to project folder mappings, and classifies default, conditional, and excluded files.

Duplicate installed destinations are moved under `_destinations` rather than silently overwritten. The extractor streams each entry through the managed `CopyEntry` method and verifies exact expanded length.

## CookFS parsing

The CookFS parser searches backward for at most 32 `CFS0002` markers. For each candidate it derives all table boundaries from `IndexSize`, `PageCount`, and stored page sizes; rejects inconsistent arithmetic; expands the index; requires `CFS2.200`; decodes the recursive directory; and consumes the optional metadata table exactly.

The result retains:

| Property | Meaning |
| --- | --- |
| `EndOffset` | First byte after the accepted `CFS0002` marker |
| `IndexOffset` | Start of the page integrity table |
| `PageDataOffset` | Start of stored page zero |
| `PageCount` | Number of page, hash, and size records |
| `IndexSize` | Stored index record length |
| `CompressionIds` and `CompressionTypes` | Distinct observed page handlers |
| `PageHashAlgorithm` | `md5`, `crc32`, or unsupported metadata value |
| `IndexMetadata` | Decoded, redacted key/value records |
| `Entries` | Logical physical paths, block lists, lengths, and timestamps |

Index compression is checked against the footer. Page compression is classified from each stored page header without expanding all pages during metadata analysis.

## Page cache and integrity

Pages can contain blocks for several files, so repeated extraction would otherwise decompress the same page multiple times. `Get-InstallBuilderCookfsPage` uses an in-memory FIFO cache limited to 16 pages and 64 MiB. Oversized pages are returned to the caller but not cached.

Every decoded page is checked against the configured MD5 or CookFS CRC32 record before block bytes are copied. Integrity validation is part of extraction correctness and cannot be disabled by a collision option.

## Logical payload projection

`Get-InstallBuilderCookfsLogicalEntry` performs two transformations:

1. Reassemble `___bitrockBigFileN` physical segments into one ordered logical file.
2. Replace component and folder storage prefixes with compiled destinations.

The result keeps both `Path` and `PhysicalPath`, total length, modification time, segments, condition state, and inherited conditions. Mapping only applies when the physical prefix and project folder identity match. Duplicate logical destinations are isolated under `_destinations`.

## Metadata and effects pipeline

After container parsing, `Get-InstallBuilderInfo` processes semantic evidence in this order:

```text
project context and recursive identity resolution
component/folder payload map and condition states
phase-aware ProjectActions
ordered registry operations and effective registry state
native and registry-derived associations
system effects, shortcuts, and execution candidates
runtime requirements
built-in plus custom ARP reconstruction
optional primary executable analysis
diagnostic and unresolved-field composition
```

This order lets later consumers reuse resolved variables and preserves the runtime ordering needed by registry deletes and post-uninstaller ARP changes.

## Primary executable analysis

`-AnalyzePrimaryExecutables` is opt-in. The parser selects at most four source-referenced executables, adds at most 64 relevant adjacent DLL, `.deps.json`, and `.runtimeconfig.json` sidecars per executable, and enforces one aggregate materialization budget. Files are extracted to a unique temporary directory, analyzed with shared PE and dependency functions, and removed in `finally`.

The result reports inspected logical paths, architecture evidence, recommended WinGet architectures, dependency evidence, and field-scoped diagnostics. It never executes or loads a payload assembly.

## Extraction API

`Expand-InstallBuilderInstaller` resolves source and destination paths before managed access. `-Name` defaults to `*`, so omission extracts `project.xml` and every packaged logical payload supported by the route. Wildcards match logical paths. Internal callers pass `CollisionAction Rename`; direct calls default to `Prompt` and prompt only after a real collision.

| Collision action | Behavior |
| --- | --- |
| `Prompt` | Ask only when the resolved output path already exists or was reserved by this extraction |
| `Error` | Stop at the first collision |
| `Skip` | Leave the existing file and continue |
| `Overwrite` | Replace the destination |
| `Rename` | Add a deterministic suffix and preserve both files |

All output paths pass through shared safe extraction and reserved-path handling. The cumulative expanded-byte limit applies across project and payload outputs. A failed integrity or decompression check removes the incomplete file.

## Diagnostics

Raw parser diagnostics are context-neutral. They carry stable ID, source, message, kind, areas, affected fields, and evidence. Callers resolve severity for detection, full analysis, manifest authoring, manifest update, or extraction.

Representative diagnostic families include:

| Prefix | Meaning |
| --- | --- |
| `InstallBuilder.Metadata.*` | Identity or project values remain dynamic |
| `InstallBuilder.ARP.*` | Built-in, custom, hidden, conditional, or deleted uninstall evidence |
| `InstallBuilder.Registry.*` | Ordered registry conditions or values remain unresolved |
| `InstallBuilder.Association.*` | Association identity, conditions, or values are incomplete |
| `InstallBuilder.Payload.*` | Selection, compression, hash, architecture, dependency, or extraction limitations |
| `InstallBuilder.Execution.*` | Nested installer or child-process review |
| `InstallBuilder.Project.DynamicLogic` | Exact rule, expression, or script source requires review |
| `InstallBuilder.Requirement.*` | Java or .NET requirement evidence |

`UnresolvedFields` remains machine-readable. Diagnostics explain why a field is unresolved and retain the relevant evidence. Presentation-only dynamic logic does not mark ProductCode or installer switches unresolved because it cannot change installation ownership.

## Bounds

| Limit | Current value | Protects |
| --- | --- | --- |
| zlib candidates | 4,096 | Incidental compressed-stream markers in packed launchers |
| project XML | 16 MiB | Project decompression and XML allocation |
| marker search radius | 16 MiB | Local project candidate search |
| CookFS index | 64 MiB | Expanded index allocation |
| CookFS pages | 1,000,000 | Hash, size, and offset arrays |
| one CookFS page | 512 MiB | Page decompression allocation |
| CookFS entries | 200,000 | Recursive file and metadata catalogs |
| Metakit metadata | 64 MiB | Descriptor and column reads |
| CookFS cache | 16 pages and 64 MiB | Reused expanded pages |
| LZMA dictionary | 128 MiB | Decoder memory |
| dynamic logic records | 4,096 | Source-evidence output |
| default primary analysis | 512 MiB | Temporary selected payload files |
| extractor output | 16 GiB | Total materialized project and payload data |

User-facing size parameters may lower or raise selected operation limits where the public API permits it. Structural counts and format-specific safeguards remain enforced independently.

## Stream and object ownership

Public path APIs resolve absolute paths and own their file streams. Helpers that receive a caller-owned stream may seek but must not dispose it unless their contract explicitly says otherwise. Managed Metakit archive objects own one read-only shared file stream and must be disposed. Extractor destination streams are always disposed in `finally`.

Returned arrays are detached metadata. The result does not retain open streams, XML readers, temporary files, or decoder instances. The internal CookFS page cache exists only during the operation that owns its layout.

## Performance rules

- Parse `project.xml`, PE layout, conditions, actions, and payload catalogs once per top-level information call.
- Keep metadata-only analysis independent from payload expansion.
- Read table headers and page prefixes before decoding page bodies.
- Use typed lists and dictionaries for large catalogs rather than repeated PowerShell array concatenation.
- Stream extraction directly to files and enforce one cumulative output counter.
- Reuse expanded shared pages only inside a bounded cache.
- Select source-referenced primary executables instead of recursively analyzing every packaged PE.
- Never invoke an external extractor, builder, Tcl runtime, or installer from the production parser.

## Extension checklist

When a new fixture fails, determine which layer differs before adding code:

1. Confirm the PE and exact project-owning Metakit VFS.
2. Record the Metakit schema, commit form, column framing, and payload ownership.
3. If CookFS exists, record footer, index signature, handler ID, hash algorithm, and metadata keys.
4. Compare the compiled project node or action with published builder semantics or controlled output.
5. Decide whether the change needs a new structural route, a compression handler, a condition/action interpretation, or only a capability boundary.
6. Add malformed and negative cases for every new offset, count, decompression, or path rule.
7. Check metadata, extraction, analyzer projection, manifest update, and scenario-resolved diagnostics.
8. Validate structurally distinct real media and use a VM only for runtime behavior unavailable from static evidence.
9. Update [format history](format-history.md), [binary format](binary-format.md), [coverage](coverage.md), and the family workflow.

## Implementation references

- [InstallBuilder parser module](../../../../../../Modules/PackageModule/Libraries/Installers/InstallBuilder.psm1)
- [InstallBuilder Metakit reader](../../../../../../Modules/PackageModule/Assets/Source/InstallBuilder/InstallBuilderMetakitReader.cs)
- [Parser development workflow](../../parser-development/workflow.md)
- [Parser performance guidance](../../parser-development/performance.md)
- [Parser contracts](../../parser-development/contracts.md)
