# Notes for implementing an Inno format reader

Read the other pages in this directory first. They describe the producer and runtime that a reader is trying to reconstruct. This page records the small set of implementation consequences specific to Dumplings.

## Static-analysis boundary

A format reader can establish:

- the exact setup-data identity, edition, character mode, and container route;
- literal setup directives and declarative entry records;
- architecture admission and 64-bit-mode expressions;
- literal scope configuration and override capability;
- built-in ARP identity and values when their expressions can be resolved;
- file, registry, icon, INI, delete, and run records;
- payload locations, compression, integrity, and extracted files;
- names of Pascal Script callbacks, typed IFPS structure, direct calls, immediate constants, and conservative runtime-effect categories.

It cannot treat target-machine registry/environment state, branch-dependent `{code:...}` values, external DLL calls, child installers, or first-run application behavior as resolved literals. A `{code:...}` value may be projected only when the complete function is straight-line and returns one proven constant without calls or indirect state.

## Route selection

The reader uses the setup-data identity as a catalog key. One descriptor selects:

```text
edition and character mode
+-- loader route
+-- metadata framing route
+-- complete setup-header schema
+-- count schema and record schemas
+-- file-location schema and digest
+-- payload framing and compression capabilities
`-- executable call-transform route
```

This avoids version-threshold parsing. The catalog currently covers the layouts recorded by innounp from 1.3.21 through 6.7 and the official 7.0 structure. My Inno Setup Extensions and ResTools have explicit routes. ISX remains identifiable but unsupported without a complete structure specification.

## Required validation

Before exposing metadata, validate:

- PE/resource or legacy loader identity and table checksum;
- absolute offsets, sizes, and non-overflowing ranges;
- exact 64-byte setup identity;
- encryption-header and compressed-block integrity;
- bounded record counts and lengths;
- full record consumption under the selected schema;
- chunk and decompressed-output limits;
- file-location ranges and digest kind;
- destination paths before extraction;
- solid-stream reuse without unbounded materialization.

Unknown fields remain unknown. Do not infer a field from a nearby readable string after structural parsing fails.

## One analysis context

One top-level operation should open and parse the source once, then reuse:

```text
resolved path and PE layout
loader offset table
format descriptor
decoded setup header and entry arrays
file-location catalog
payload stream index
symbolic runtime state
```

Payload extraction should seek to selected bounded ranges. Solid compression should decode once in forward order for all requested files instead of restarting the stream for every file.

## Runtime projection

Built-in ARP evidence is reconstructed from Inno's rules, not from string probing:

- normalize expanded `AppId` and append `_is1` only for the built-in key;
- select HKLM/HKCU and registry view from proven install mode;
- retain separate conditional results for user and machine routes;
- expand known constants symbolically where final target state is not available;
- leave code, registry, environment, and external-call values unresolved;
- keep custom `[Registry]` ARP writes separate from the built-in entry.

Likewise, an architecture expression describes admission and install mode. It does not make the outer SetupLdr PE architecture the package architecture.

## Extraction and passwords

Metadata and payload decoding must remain bounded. Password-protected data requires the format's key derivation, password-test, nonce, and authenticated decryption rules. A missing password is a structured limitation, not malformed input.

External disk slices are supported when the required media files are available. The extractor reads `SlicesPerDisk`, reproduces the official numbered or letter-suffixed filename mapping, validates every `idska32`/`idskb32` header and declared file size, and presents only the catalogued compressed ranges as one bounded stream. Missing slices remain a deterministic missing-media error; their bytes cannot be synthesized.

Use `Expand-InnoInstaller -DiskSourcePath <path[]>` when slices are stored outside the setup executable directory. Each path can name a search directory or an explicit slice file. The default search includes the setup executable directory. The parser opens only the current slice and never concatenates complete media in memory.

## Regression evidence

Tests should cross format transitions rather than collect many installers with the same route. Useful boundaries include:

- fixed legacy loader versus resource table v1 and v2;
- legacy zlib, chunked32, and chunked64 metadata;
- ANSI and Unicode records;
- Adler32, CRC32, MD5, SHA-1, and SHA-256 file locations;
- each compression and executable-transform generation;
- official, My Inno Setup Extensions, and ResTools editions;
- `UseSetupLdr=no`, embedded payload, and disk-spanned layouts;
- literal, built-in-constant, registry/environment-constant, and code-constant values.

Generated malformed fixtures should target range overflow, excessive counts, truncated records, invalid checksums, expansion cycles, and decompression limits. Historical real fixtures should come from official archived builders or durable vendor installers and live in the shared fixture cache.

## Implementation locations

- GPL format implementation: `Modules/InstallerParsers/Libraries/Installers/Inno*.psm1`
- declarative layouts: `Modules/InstallerParsers/Libraries/Installers/InnoFormatCatalog.psd1`
- PackageModule process bridge: `Modules/PackageModule/Libraries/Installers/Inno.psm1`
- focused package workflow: [Inno Setup workflow](../../families/inno/workflow.md)
- general parser rules: [Parser development](../../parser-development/workflow.md)

## Source references

- [Official Inno Setup source](https://github.com/jrsoftware/issrc)
- [InnoUnpacker/innounp](https://github.com/jrathlev/InnoUnpacker-Windows-GUI)
