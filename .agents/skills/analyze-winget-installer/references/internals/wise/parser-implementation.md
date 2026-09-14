# Wise parser implementation

## Detection order

`Get-WiseStructuralContext` opens one caller-owned stream and tries routes from strongest to weakest structure. It first parses a PE and checks for a validated `.WISE` MSI record, then a direct WiseScript overlay, then bounded nested PE candidates in `.rsrc`. If the file is MZ but not PE, it checks for a valid NE header and asks the bounded NE model for a Wise overlay offset. A candidate is accepted only after its required WiseScript member decompresses and passes CRC validation.

This order prevents common `Wise` strings, an incidental `.WISE` section name, CFB magic in arbitrary data, or an MZ sequence in resources from classifying a non-Wise executable.

## Stream ownership

Public functions resolve the filesystem path before managed access. Internal helpers accept readable, seekable streams and preserve caller ownership. Bounded views isolate nested PEs, compressed members, CFB candidates, and payload records. Temporary files are used only when an existing MSI or PE parser requires a path and are removed in `finally`.

## Bounds and integrity

The parser enforces a 64 MiB script-member limit and a 4 GiB per-MSI or per-payload limit. Header lengths, member lengths, overlay offsets, payload-relative ranges, PE section ranges, resource ranges, and certificate boundaries are checked before reading or allocating. Every Wise raw-Deflate member used by the parser must match its trailer CRC32. Payload records also match the catalog CRC32 when it is nonzero. `.WISE` MSI records require the MSI CFB root CLSID and the record CRC32.

Optional overlay size slots in some Wise 9 prerequisite wrappers do not describe physical members. The parser attempts a bounded decode at the current position and records `Wise.Extraction.HeaderSlotNotPhysical` when a non-required slot fails. It does not advance the member cursor on that path.

## Managed WiseScript reader

The parser loads pinned MIT builds of `SabreTools.IO` and `SabreTools.Serialization` through the shared race-safe managed-assembly loader. The Serialization assembly is rebuilt with two unconditional console diagnostics removed; public types and parsing behavior are unchanged. Dumplings does not execute WiseUnpacker or another external extractor.

SabreTools supplies NE and WiseScript object models. Dumplings owns all trust-boundary checks, metadata authority decisions, extraction, diagnostics, and WinGet projection. A reader exception after a valid header and checksummed script member becomes `Wise.Metadata.ScriptModelUnsupported` rather than triggering arbitrary string recovery.

## Detection versus full parsing

`Test-WiseInstaller` performs structural context parsing and does not parse nested MSI tables. `Get-WiseInfo` additionally extracts the exact nested MSI when present and calls `Get-MsiInstallerInfo` once. The parser reuses that MSI result for product identity, scope, architecture, associations, installation location, and ARP metadata.

## Diagnostic policy

Raw Wise results return context-neutral diagnostics. The analyzer or manifest workflow assigns scenario-specific levels. Notable identifiers are:

| Id | Meaning |
| --- | --- |
| `Wise.Metadata.NestedMsiAuthority` | an exact validated MSI supplies installed-product identity |
| `Wise.Installability.NestedMsiInteractiveOnly` | the wrapper route does not prove unattended nested installation |
| `Wise.Metadata.ScopeUnresolved` | nested MSI evidence does not prove one scope |
| `Wise.Metadata.ScriptModelUnsupported` | physical WiseScript is valid but its state dialect is unsupported |
| `Wise.Metadata.ExternalDllEffectsOpaque` | an external DLL can produce unmodeled effects |
| `Wise.Metadata.MultipleArpEntries` | multiple literal custom uninstall identities exist |
| `Wise.Metadata.ScriptArpConditionsRequireValidation` | one custom row exists but its active branch is not proven |

## Performance

The outer installer is opened once per top-level parser operation. Header and state members are bounded and decompressed once. Nested MSI discovery materializes at most 16 executable payload candidates and stops at the first structurally valid `.WISE` MSI record. Large payloads stream to disk rather than becoming PowerShell byte arrays. The WiseScript state member is capped and represented through typed managed objects to avoid pipeline materialization of binary data.
