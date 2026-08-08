# Inno Setup parser internals

This reference supports parser implementation and review. For installer analysis and manifest authoring, use the [Inno Setup workflow](../../families/inno/workflow.md).

Read [binary notation](../../parser-development/binary-notation.md), [parser contracts](../../parser-development/contracts.md), and [performance guidance](../../parser-development/performance.md) before changing the parser.

## Supported formats and variants

The parser covers the structured Inno Setup variants documented below. Variant-specific evidence must pass the same content-based detection and bounds checks.

## Binary structure

Inno stores an offset table in PE `RCDATA` resource ID `11111`. That table points to compressed setup metadata and file data elsewhere in the executable. Offsets are absolute file offsets after the resource record is decoded.

```text
PE setup loader
+-- .rsrc/RCDATA/#11111             offset table
`-- setup data
    +-- Offset0 -> 64-byte setup signature
    |   +-- optional encryption header
    |   `-- chunk-framed compressed setup header/tables
    `-- Offset1 -> file-data streams
        `-- 7A 6C 62 1A ("zlb" 1A) + compressed chunks
```

```text
Offset-table resource (v1, 44 bytes)
Base        Offset  Size  Field
----------  ------  ----  -------------------------------------------
[resource]  0x00    12    Magic: 72 44 6C 50 74 53 CD E6 D7 7B 0B 2A
[resource]  0x0C    4     Table version, uint32 LE
[resource]  0x10    4     TotalSize, uint32 LE
[resource]  0x20    4     Offset0, uint32 LE -> [abs]
[resource]  0x24    4     Offset1, uint32 LE -> [abs]
[resource]  0x28    4     CRC32 of bytes 0x00..0x27

Offset-table resource (v2, 64 bytes)
[resource]  0x10    8     TotalSize, int64 LE
[resource]  0x28    8     Offset0, int64 LE -> [abs]
[resource]  0x30    8     Offset1, int64 LE -> [abs]
[resource]  0x3C    4     CRC32 of bytes 0x00..0x3B
```

Before Inno 6.7 a compressed-block header stores `[StoredSize:uint32 LE][Compressed:byte]`; 6.7+ uses an `int64 LE` size. `StoredSize` frames repeated `[CRC32:uint32 LE][data:up to 4096 bytes]` chunks. The reassembled payload is stored bytes or raw LZMA with five property bytes. Setup-header and file-location records are version-dependent; the parser chooses layouts from the source-defined setup version, validates every pointer/range/CRC, and does not scan arbitrary strings for ARP values.

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

- Modules/PackageModule/Libraries/Installers/Inno.psm1
- Modules/InstallerParsers/Libraries/Installers/Inno.psm1

## Representative fixtures

Use generated malformed fixtures and the behaviorally distinct real installers cited by the focused tests and family workflow.

## Source references

- [Inno Setup](https://github.com/jrsoftware/issrc)
- [InnoUnpacker/innounp](https://github.com/jrathlev/InnoUnpacker-Windows-GUI)
- [Komac](https://github.com/russellbanks/Komac)
