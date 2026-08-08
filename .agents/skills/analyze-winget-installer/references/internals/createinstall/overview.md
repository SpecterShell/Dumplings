# CreateInstall parser internals

This reference supports parser implementation and review. For installer analysis and manifest authoring, use the [CreateInstall workflow](../../families/createinstall/workflow.md).

Read [binary notation](../../parser-development/binary-notation.md), [parser contracts](../../parser-development/contracts.md), and [performance guidance](../../parser-development/performance.md) before changing the parser.

## Supported formats and variants

The parser covers the structured CreateInstall variants documented below. Variant-specific evidence must pass the same content-based detection and bounds checks.

## Binary structure

CreateInstall appends a Gentee GEA container to its PE launcher. Dumplings searches for the aligned container magic and validates the full header before trusting any payload size.

```text
PE setup stub
`-- GEA container at [overlay]
    +-- 73-byte GEA v1/v2 header
    +-- NUL-terminated UTF-8 volume pattern
    +-- optional password records
    +-- metadata/catalog (stored or LZGE)
    `-- ordinary and moved file-data regions
```

```text
Base       Offset  Size  Field
---------  ------  ----  ---------------------------------------------
[overlay]  0x00    4     Magic: 47 45 41 00 ("GEA\0")
[overlay]  0x04    2     VolumeNumber, uint16 LE
[overlay]  0x06    4     UniqueID, uint32 LE
[overlay]  0x0A    1     MajorVersion
[overlay]  0x0B    1     MinorVersion
[overlay]  0x14    4     Flags, uint32 LE
[overlay]  0x18    2     VolumeCount, uint16 LE
[overlay]  0x1A    4     HeaderSize, uint32 LE
[overlay]  0x1E    8     SummarySize, int64 LE
[overlay]  0x26    4     InfoSize, uint32 LE
[overlay]  0x2A    8     ArchiveFileSize, int64 LE
[overlay]  0x32    8     VolumeSize, int64 LE
[overlay]  0x3A    8     LastVolumeSize, int64 LE
[overlay]  0x42    4     MovedSize, uint32 LE
[overlay]  0x46    3     Memory/Block/Solid multipliers
```

GEA v2 file records begin with flags (2), FILETIME (8), size (8), compressed size (8), and CRC32 (4); v1 uses 32-bit sizes. Each file block is `[order:1][compressed-size:8]` in v2 or `[order:1][compressed-size:4]` in v1. The stored order byte has this layout:

```text
bit 7       protection marker retained by the container
bits 6..4   compression type: 0=Store, 1=LZGE, 2=Gentee PPMd-I
bits 3..0   compression order minus one
```

For PPMd, an order greater than one initializes the model and order one continues the preceding model after starting a new range-coded block. Every PPMd block ends with an explicit PPMd end marker. Dumplings therefore walks preceding archive entries in physical order even when only a later file is selected, but writes only selected files. Expanded file length and Gentee's unfinalized CRC32 are verified.

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

- Modules/PackageModule/Libraries/Installers/CreateInstall.psm1

## Representative fixtures

Use generated malformed fixtures and the behaviorally distinct real installers cited by the focused tests and family workflow.

## Source references

Use the source references in the mapped module headers and its focused tests. Add upstream references here when new behavior is grounded.
