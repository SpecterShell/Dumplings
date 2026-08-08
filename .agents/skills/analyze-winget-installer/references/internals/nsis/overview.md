# NSIS parser internals

This reference supports parser implementation and review. For installer analysis and manifest authoring, use the [NSIS workflow](../../families/nsis/workflow.md).

Read [binary notation](../../parser-development/binary-notation.md), [parser contracts](../../parser-development/contracts.md), and [performance guidance](../../parser-development/performance.md) before changing the parser.

## Supported formats and variants

The parser covers the structured NSIS variants documented below. Variant-specific evidence must pass the same content-based detection and bounds checks.

## Binary structure

NSIS appends its archive to a PE stub at a 512-byte-aligned file offset. The first header frames a compressed logical header; that header contains block directories for compiled commands, strings, languages, and payload metadata.

```text
PE NSIS stub
`-- 512-byte-aligned archive start
    +-- first header (28 bytes; NSISBI extends it)
    +-- packed-header size word (uint32 or uint64 LE)
    +-- compressed logical header
    |   +-- common header
    |   +-- eight block descriptors
    |   +-- compiled command entries
    |   +-- string/language tables
    |   `-- data block metadata
    `-- compressed payload streams
```

NSISBI 3.10 multithreaded builds can wrap the solid stream in independently compressed records. Record offsets below are relative to the MTW stream. Each record expands to at most 2 MiB; a zero compressed size terminates the stream.

```text
Offset  Size            Field
------  --------------  ----------------------------------------------
0x00    3               CompressedBlockSize, unsigned uint24 LE
0x03    CompressedSize  Selected zlib/BZip2/LZMA/LZ4 codec stream
next    repeated        Next three-byte record header
...     3               00 00 00 terminator
```

```text
Base       Offset  Size  Field
---------  ------  ----  ---------------------------------------------
[archive]  0x00    4     Flags, uint32 LE
[archive]  0x04    16    EF BE AD DE + ASCII "NullsoftInst"
[archive]  0x14    4     DecompressedHeaderSize, uint32 LE
[archive]  0x18    4     ArchiveSize, uint32 LE
[archive]  0x1C    8     NSISBI data-block length, uint64 LE (variant)
```

For a non-solid block, the packed-size high bit marks compression and the remaining bits give the compressed byte count. A solid archive instead starts directly with its codec stream. Compression may be zlib, raw DEFLATE, BZip2, LZMA, or vendor LZMA2 framing consisting of a one-byte dictionary property followed by raw LZMA2 chunk records. NSISBI MTW builds add the record layer above; Unity installers use MTW-framed LZMA and can exceed 2 GiB, so the parser bounds the PE view separately from the 64-bit archive ranges. Dumplings currently decodes MTW zlib, BZip2, and LZMA records; an MTW LZ4 build remains explicit unsupported evidence rather than falling through to another codec. Standard compiled command entries are 28 bytes; NSISBI uses 36-byte entries/64-bit data offsets. NSIS 2, NSIS 3 Unicode, Park Unicode, and log-enabled builds shift opcode layouts, so Dumplings normalizes the command table before interpreting `EW_WRITEREG`. It validates nearby PE structure, alignment, flags, header/archive sizes, codec record sizes, block counts, string offsets, execution steps, decompressed output, and watchdog time before accepting registry evidence.

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

- Modules/PackageModule/Libraries/Installers/NSIS.psm1
- Modules/InstallerParsers/Libraries/Installers/NSIS.psm1

## Representative fixtures

Use generated malformed fixtures and the behaviorally distinct real installers cited by the focused tests and family workflow.

## Source references

- [NSIS](https://github.com/NSIS-Dev/nsis)
- [NSISBI](https://sourceforge.net/projects/nsisbi/)
- [7-Zip](https://github.com/ip7z/7zip)
- [Komac](https://github.com/russellbanks/Komac)
- [electron-builder](https://github.com/electron-userland/electron-builder)
- [Tauri NSIS bundler](https://github.com/tauri-apps/tauri/tree/dev/crates/tauri-bundler/src/bundle/windows/nsis)
- [NsisMultiUser](https://github.com/Drizin/NsisMultiUser)
