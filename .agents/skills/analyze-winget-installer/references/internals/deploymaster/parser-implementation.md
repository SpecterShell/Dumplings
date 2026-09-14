# DeployMaster parser implementation

## Detection

Locator-based detection requires a seekable PE, bounded locator values at `0x80`, a matching package CRC, a valid logical-file or certificate ending, exactly one normalized control-header profile, complete runtime tuples, and DeployMaster runtime identity. Classic detection requires trusted DeployMaster PE identity, a `BZh9` overlay, a bounded BZip2 member expanding to a PE, the all-ones boundary, valid leading zlib metadata, and a filename catalog bound to the contiguous payload tail.

Marker strings, compression signatures, PE product strings, or one decodable record are insufficient. Detection fails closed when multiple profiles validate or a structural relationship is incomplete.

## One-pass ownership

`Get-DeployMasterInfo` resolves the source path and opens one read-only shared stream. Locator, header, runtime ranges, language, identity, file table, structured metadata, and runtime-switch evidence are derived from that stream. The resulting model is reused for ARP, associations, execution records, diagnostics, and public output.

Random-access helpers restore caller-owned stream positions. Bounded substreams and parser-owned memory streams are disposed in `finally`. The top-level parser closes its file stream after all detached evidence is composed.

## Structural dispatch

`DeployMasterFormatCatalog.psd1` stores data-only profile facts: header size, shift, file-table kind, registry route, association route, platform fields, uninstall-command route, observed release range, and evidence. Parser dispatch follows validated byte relationships. The outer PE version is never used as a route selector.

The classic catalog is separate because its compression, identity encoding, record framing, file table, install tree, and ARP semantics differ. Shared low-level binary, archive, PE, checksum, path, and collision helpers are reused without hiding family-specific rules.

## Extraction

`Expand-DeployMasterInstaller` expands runtime cores, metadata blocks, and package files to distinct safe namespaces. Omitting `Name` selects all entries. Public collision handling prompts only when a collision occurs; internal inspection uses `Rename`.

Each output path is resolved beneath the destination before writing. Partial files are removed when decompression, expanded-size, CRC, or total-output validation fails. Signed certificate data is never exported as package content.

## Optional runtime inspection

Some command support exists only in compressed runtime code. The parser expands one bounded preferred runtime core and searches its UTF-16 string table for exact slash-prefixed tokens. This establishes feature presence for `/noadmin` and conditionally `/portable`; it does not promote internal relaunch markers into public switches.

## Diagnostics

Raw results contain context-neutral structured `Diagnostics` and machine-readable `UnresolvedFields`. Classic partial behavior, opaque support-DLL effects, incomplete runtime-switch inspection, malformed optional metadata, dual-scope selection, time limitation, unresolved association targets, and portable-only ARP suppression each have stable diagnostic identities.

Structural corruption throws from strict parser entry points. Optional metadata failure preserves already validated identity and file evidence where the ownership boundary permits it. Workflow callers resolve severity for detection, full analysis, authoring, update, or extraction.

## Bounds and invariants

The parser bounds runtime expansion, metadata blocks, payload counts, candidate scans, recursion, text lengths, file-table size, total extraction, and output paths. It rejects incomplete architecture tuples, invalid LZMA properties, mismatched logical size, CRC failure, out-of-range timestamps or dates, duplicate or forward component requirements, invalid file indexes, ambiguous filename blocks, traversal, and malformed signed envelopes.

Classic scanning limits all-ones boundary candidates and zlib records before decompression. Auxiliary records require unique size and CRC matches. Ordinary payload offsets must equal the recovered chain, and behavior records must consume their bounded input exactly before they can project system effects.

## Implementation map

- `Modules/PackageModule/Libraries/Installers/DeployMaster.psm1` contains the structural parser, evidence projection, and extractor.
- `Modules/PackageModule/Libraries/Installers/DeployMasterFormatCatalog.psd1` contains the verified route profiles.
- `Modules/PackageModule/Libraries/Infrastructure/InstallerAnalyzer.psm1` performs provider-neutral candidate routing.
- `Modules/PackageModule/Libraries/WinGet/WinGetAnalysis.psm1` composes schema-valid WinGet suggestions from exact parser evidence.
- `Modules/PackageModule/Tests/Installers/DeployMaster.Tests.ps1` covers classic, archived locator, controlled builder, malformed, extraction, scope, architecture, ARP, and policy behavior.
