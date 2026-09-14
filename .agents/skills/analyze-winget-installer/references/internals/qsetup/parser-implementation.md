# QSetup parser implementation

## Structural detection

The parser treats preamble, records, terminal structure, and `Setup.txt` as one chain.

```text
candidate PE
+-- locate physical overlay
+-- select exactly one preamble grammar
+-- bind optional split descriptor to an exact companion
+-- enumerate adjacent bounded zlib records
|   `-- validate every decoded |Name[*]?|Stamp| NUL header
+-- stop at exact EOF or a validated footer and certificate boundary
+-- bind footer overlay offset and count to the enumerated stream
`-- require Setup.txt with SET_COMPOSER_BUILD directly or in a bounded nested setup
```

No individual marker, PE version field, record name, or producer string is sufficient. `FormatGeneration` follows the validated preamble and terminal routes, not claimed version text.

## Stream ownership and performance

`Get-QSetupInfo` opens the source once. Layout enumeration inflates only the small record header, while `Setup.txt`, selective PE analysis, and requested extraction read complete bodies. One bounded zlib stream owns one declared record and cannot consume the next record or footer.

Caller-owned seekable streams stay open and restore required positions. Parser-owned streams and reconstructed temporary media are disposed in `finally`. Returned catalogs are detached from temporary spanned or nested files.

## Media routing

Single-file media reads records from the PE overlay. Split media requires a caller-supplied companion whose descriptor identity and length match the kernel. Spanned media concatenates explicitly supplied `.001`, `.002`, and later parts in strict numeric order. External payload descriptors resolve only from explicit files or directories. Nested QSetup wrappers recurse under a fixed depth limit.

The parser never guesses adjacent files by wildcard. Missing parts, duplicate names, ambiguous candidates, and unauthenticated companions fail the owning media route.

## Extraction

Default extraction follows the installed payload catalog, removes numeric physical prefixes, and writes paths relative to the application root. Other deterministic roots are isolated below `_destinations`; unresolved destinations go below `_unresolved`. `-RawRecords` exports physical records below `_qsetup\records` without following a nested wrapper.

Omitted `Name` means every mapped installed file. Selection accepts installed path or leaf name. Source and destination paths are resolved before managed I/O. Shared collision handling prompts only when a conflict occurs; internal calls use `Rename`.

## Diagnostics and bounds

Malformed execution arrays, host-dependent conditions, external companions, downloads, external DLLs, unresolved paths, and blank-name uninstaller gaps produce structured diagnostics. Proven structural mismatches and unsafe extraction conditions fail.

The parser bounds preamble and descriptor bytes, record count, compressed member size, decoded header length, `Setup.txt` bytes, certificate bytes, recursion, selective analysis, reconstructed media, and aggregate extraction. It rejects arithmetic overflow, path traversal, duplicate destinations, malformed zlib data, count mismatch, footer mismatch, invalid certificate envelopes, and trailing bytes outside a supported route.

## Implementation map

- `Modules/PackageModule/Libraries/Installers/QSetup.psm1`: structural parsing, directive semantics, analysis, and extraction.
- `Modules/PackageModule/Libraries/Installers/QSetupFormatCatalog.psd1`: verified route and uninstaller-formula catalog.
- `Modules/PackageModule/Libraries/Infrastructure/InstallerAnalyzer.psm1`: provider-neutral detection and orchestration.
- `Modules/PackageModule/Libraries/WinGet/WinGetAnalysis.psm1`: WinGet suggestion projection.
