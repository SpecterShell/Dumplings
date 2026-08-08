# QSetup parser internals

This reference supports parser implementation and review. For installer analysis and manifest authoring, use the [QSetup workflow](../../families/qsetup/workflow.md).

Read [binary notation](../../parser-development/binary-notation.md), [parser contracts](../../parser-development/contracts.md), and [performance guidance](../../parser-development/performance.md) before changing the parser.

## Supported formats and variants

The parser covers the structured QSetup variants documented below. Variant-specific evidence must pass the same content-based detection and bounds checks.

## Binary structure

QSetup appends a preamble and a sequence of length-framed zlib records to its PE launcher. Each decompressed record starts with a small pipe-delimited catalog header.

```text
PE launcher
`-- overlay
    +-- 9-byte preamble header
    +-- UTF-8 preamble text
    `-- repeated records
        +-- CompressedLength, uint32 LE
        `-- zlib stream -> "|Name[*]?|Stamp|" + file bytes
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
```

`*` marks a required record. `Setup.txt` directives are authoritative metadata after exact record framing. Dumplings bounds preamble size, record count, compressed/expanded bytes, header length, next offset, and output path. Metadata from complete leading records may be reported for a truncated download, but expansion requires a complete table.

## Detection invariants

Accept the family only when the surrounding headers, ranges, counts, and relationships described above validate. Treat an isolated marker as a routing hint and preserve conditional values as unresolved evidence.

## Metadata projection

Project only structured metadata and explicit registry behavior into the shared parser result. Preserve conditional or unknown values as warnings or unresolved fields.

## Bounds and malformed input

Apply the shared parser bounds to every offset, size, count, decompressed range, destination path, and recursion boundary. Reject malformed input deterministically.

## Performance considerations

Open the installer once, reuse parsed layout evidence, and prefer bounded streams or selected-entry extraction over whole-file materialization.

## Known gaps

Unsupported variants and conditional runtime behavior remain explicit warnings or unresolved evidence; they are not inferred from arbitrary strings.

## Implementation mapping

- Modules/PackageModule/Libraries/Installers/QSetup.psm1

## Representative fixtures

Use generated malformed fixtures and the behaviorally distinct real installers cited by the focused tests and family workflow.

## Source references

Use the source references in the mapped module headers and its focused tests. Add upstream references here when new behavior is grounded.
