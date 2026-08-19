# QSetup parser internals

This reference supports parser implementation and review. For installer analysis and manifest authoring, use the [QSetup workflow](../../families/qsetup/workflow.md).

Read [binary notation](../../parser-development/binary-notation.md), [parser contracts](../../parser-development/contracts.md), and [performance guidance](../../parser-development/performance.md) before changing the parser.

## Supported formats and variants

The parser covers the structured QSetup variants documented below. Variant-specific evidence must pass the same content-based detection and bounds checks.

## Binary structure

QSetup appends a preamble and a sequence of length-framed zlib records to its PE launcher. Each decompressed record starts with a small pipe-delimited catalog header. Current media terminates the record table with a self-describing footer and can place Authenticode alignment and the PE certificate table after that footer.

```text
PE launcher
`-- overlay
    +-- 9-byte preamble header
    +-- UTF-8 preamble text
    +-- repeated records
    |   +-- CompressedLength, uint32 LE
    |   `-- zlib stream -> "|Name[*]?|Stamp|" + file bytes
    +-- QSetup footer
    +-- zero certificate-alignment padding, 0..7 bytes
    `-- PE certificate table, optional
```

```text
Base       Offset  Size  Field
---------  ------  ----  --------------------------------------------
[overlay]  0x00    4     FormatVersion, uint32 LE
[overlay]  0x04    1     CompressionFormat
[overlay]  0x05    4     PreambleLength, uint32 LE
[overlay]  0x09    N     UTF-8 preamble, must match |...exe|
[record]   0x00    4     CompressedLength, uint32 LE
[record]   0x04    N     zlib bytes
[decoded]  0x00    M     ASCII |Name[*]?|Stamp| header
[decoded]  ...     ...   record content
[footer]   0x00    4     FooterVersion, uint32 LE
[footer]   0x04    4     OverlayOffset, uint32 LE
[footer]   0x08    4     RecordCount, uint32 LE
[footer]   0x0C    4     Magic, uint32 LE: 0x4A3B2C1D
[footer]   0x10    4     Marker, uint32 LE: 1234
[footer]   ...     ...   Version-dependent footer fields
[footer]   end-4   4     FooterLength, uint32 LE
```

`*` marks a required record. `Setup.txt` directives are authoritative metadata after exact record framing. The footer repeats the overlay offset and record count; those values, both footer markers, the self-length, padding, certificate range, and parsed record endpoint must agree before the parser treats it as the package boundary. Dumplings bounds preamble size, footer size, record count, compressed/expanded bytes, header length, next offset, and output path. Metadata from complete leading records may be reported for a truncated download, but expansion requires a complete table.

## Execution Engine records

`SET_PERFORM_EXECUTE_OP` serializes three runtime-condition argument slots and six fixed execution-command slots. The parser preserves the runtime condition descriptors instead of evaluating host-dependent predicates, while projecting enabled commands and their three arguments into `ExecutionActions`. Process-launch commands such as `Run Executable`, `Run MSI File`, `Shell Execute`, and their wait variants are also returned through `ExecutedPayloads` with stage, conditionality, parameters, and display mode. A structurally valid custom action is review evidence rather than a parser warning; malformed or unsupported slot layouts remain warnings.

## Detection invariants

Accept the family only when the surrounding headers, ranges, counts, and relationships described above validate. Treat an isolated marker as a routing hint and preserve conditional values as unresolved evidence.

## Metadata projection

Project only structured metadata and explicit registry behavior into the shared parser result. Preserve conditional or unknown values as warnings or unresolved fields.

## Bounds and malformed input

Apply the shared parser bounds to every offset, size, count, decompressed range, destination path, and recursion boundary. Reject malformed input deterministically.

## Performance considerations

Open the installer once, reuse parsed layout evidence, and prefer bounded streams or selected-entry extraction over whole-file materialization.

## Known gaps

Unsupported variants and malformed conditional runtime behavior remain explicit warnings or unresolved evidence; they are not inferred from arbitrary strings.

## Implementation mapping

- Modules/PackageModule/Libraries/Installers/QSetup.psm1

## Representative fixtures

Use generated malformed fixtures, the official `Pantaray.QSetup` installer, and a signed action-heavy installer such as `AGTEK.Trackwork` for footer, certificate, extraction, and Execution Engine coverage.

## Source references

- [QSetup Execution Engine](https://www.pantaray.com/execute.html)
- [QSetup execution command reference](https://www.pantaray.com/execution_cmd.html)
