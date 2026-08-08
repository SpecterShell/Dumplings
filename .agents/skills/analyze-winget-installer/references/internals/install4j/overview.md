# install4j parser internals

This reference supports parser implementation and review. For installer analysis and manifest authoring, use the [install4j workflow](../../families/install4j/workflow.md).

Read [binary notation](../../parser-development/binary-notation.md), [parser contracts](../../parser-development/contracts.md), and [performance guidance](../../parser-development/performance.md) before changing the parser.

## Supported formats and variants

The parser covers the structured install4j variants documented below. Variant-specific evidence must pass the same content-based detection and bounds checks.

## Binary structure

Current launchers use a PE overlay configuration; older generations may expose an unextracted-file table. Java-style fields in these records are big-endian unless stated otherwise.

```text
PE launcher
`-- overlay
    +-- D5 13 E4 E8                launcher configuration magic
    +-- data version/flags
    +-- DataLength, int64
    +-- UTF-8 parameter map
    +-- UTF-16LE localized/nested maps
    +-- startup-file table
    `-- CRC32 of bounded configuration data

Legacy/unextracted data
+-- E8 E4 13 D5                    table magic
+-- Java DataInput-style records   big-endian lengths/integers
`-- 0.dat / config / runtime files raw or LZMA-compressed
```

The overlay magic is at the PE overlay base. Length-prefixed strings cannot cross the declared configuration end, and startup entries point to exact file ranges. The parser also recognizes `i4jparams.conf` XML and application-ID records after structural validation. LZMA output, parameter bytes, entry count, and scan candidates are bounded; marker text alone is not sufficient classification.

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

- Modules/PackageModule/Libraries/Installers/Install4j.psm1

## Representative fixtures

Use generated malformed fixtures and the behaviorally distinct real installers cited by the focused tests and family workflow.

## Source references

Use the source references in the mapped module headers and its focused tests. Add upstream references here when new behavior is grounded.
