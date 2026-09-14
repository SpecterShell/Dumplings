# CreateInstall parser implementation

## Structural detection

`Test-CreateInstall` resolves the source path, validates the PE, decodes the one `.gentee` program, verifies its GE header CRC and object table, and requires a referenced `MAINVAR` table with the source-consumed project keys. It intentionally does not require a GEA archive because valid setup and uninstaller programs can contain no packaged files.

`Get-InstallerStructuralExeFamilyCandidate` uses this bounded test as high-confidence evidence. This route prevents no-payload CreateInstall programs from falling through to portable PE analysis and avoids depending on `CreateInstall`, `Novostrim`, or `.ciq` strings. Text markers remain low-confidence routing hints and are rejected when the structural parser does not validate.

## One-pass ownership

`Get-CreateInstallInfo` decodes the GE program once and reuses its object table, command cache, function index, external-import index, project variables, and list buffer for every operation analyzer. The GEA layout is parsed once. Block headers are enumerated without expanding payloads, and selected files are materialized only when architecture or dependency analysis needs filesystem paths.

Helpers accept the parsed `Program`, `ProjectVariableEvidence`, or `Layout` object when one already exists. Adding a new route must follow the same ownership model rather than calling `Get-CreateInstallInfo` or reopening the complete installer from an inner function.

## Route selection

`CreateInstallFormatCatalog.psd1` contains independent descriptors for GE programs, GEA widths, Add/Remove profiles, install-group profiles, and operation profiles. Handlers select a route from structural facts such as argument count, required and forbidden literals, native imports, direct call targets, and validated list field counts.

Object IDs and linked function names are not stable after Gentee linking and dead-code elimination. A new handler must not route by an observed object number or a package-specific function name. Use an exact source-backed fingerprint and reject multiple matches.

## Condition handling

`Resolve-CreateInstallCondition` evaluates the source-defined literal and project-macro subset. Unknown `@function` routes remain unknown. `Get-CreateInstallGenteeExpressionEvidence` provides bounded commands, literals, callees, variable candidates, context, and affected fields for review.

An operation with a false condition is excluded. An operation with an unknown condition remains typed conditional evidence and contributes a structured diagnostic. Do not merge a conditional registry value into deterministic ARP state or select a conditional payload as the only architecture witness.

## Archive discovery and extraction

`Get-CreateInstallArchiveLayout` locates candidate `GEA\0` signatures, validates header and catalog bounds, resolves the profile by major version, verifies volume identity and logical length, and accepts one complete layout. It supports archive data inside the setup, standalone synthetic GEA fixtures for lower-level tests, and companion volumes selected from the compiled pattern.

`Expand-CreateInstallInstaller` resolves source and destination paths, extracts every catalog entry when `-Name` is omitted, and applies shared safe-path and collision handling. Interactive calls default to prompting only on an actual collision; internal analysis passes `Rename`. Store and LZGE blocks use bounded managed readers. Gentee PPMd-I uses the source-shipped managed provider because the standard SharpCompress PPMd model is wire-incompatible.

Every selected file is checked against its declared expanded size and Gentee CRC. Traversal, duplicate output paths, missing or mismatched volumes, truncated block ranges, unsupported compression, password protection, and aggregate output limits fail closed.

## Diagnostics

Raw parser diagnostics are context-neutral. They identify source, kind, affected areas, affected manifest fields, and bounded evidence. Detection, full analysis, manifest authoring, manifest update, and extraction assign severity through the shared scenario policy.

Expected incomplete conditions include missing companion volumes, unresolved macros, dynamic predicates, external downloads, opaque DLL effects, encrypted entries, unrecognized environment mutation routines, and nested archives not recursively projected. Current `globappend` and `globdel` routines are separated by their exact source-backed GE4 literal sequences; an altered sequence remains `AppendOrRemove` rather than being guessed. Invalid offsets, CRC failures, impossible counts, malformed records, unsafe paths, and inconsistent volumes are format errors rather than ordinary warnings.

`UnresolvedFields` is reserved for fields whose value cannot be returned safely. Diagnostics can be broader than that collection because a package may have an authoritative ProductCode while a separate conditional registry operation remains relevant to protocols or other metadata.

## Performance and memory

The parser bounds the decoded GE program at 64 MiB and individual archive metadata or blocks at their family limits. It streams archive ranges and opens companion files only when a logical slice crosses them. It does not concatenate spanned media or expand the complete payload for metadata analysis.

Typed lists and hash sets accumulate parser results without repeated PowerShell array growth. PE analysis uses the shortest selected application set and related native libraries. Temporary analysis files are removed in `finally` blocks.

The Boolean detector avoids GEA enumeration and payload decompression. Its extra structural call in generic EXE routing is acceptable because `.gentee` rejection occurs before GE decoding for unrelated PEs and prevents a much more expensive incorrect portable or wrapper path for valid no-payload media.

## Extending the parser

Add a catalog route only after a source or controlled fixture establishes the record grammar. Add valid, truncated, oversized, and competing-fingerprint tests. For operation routes, verify source field count, runtime parameter count, literals or native imports, condition position, and output semantics. For archive changes, verify full extraction CRCs on a distinct real fixture.

Changes affecting ProductCode, scope, silent behavior, uninstaller commands, or child installability need VM installed-state evidence. Changes that only expose bounded raw evidence do not become manifest fields until their runtime meaning is proven.
