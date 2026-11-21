# NSIS binary format

[Back to NSIS internals](overview.md).

This page describes stock NSIS archive structures and the fork-specific fields used by Dumplings. Offsets are little-endian unless stated otherwise. The base of an offset is named explicitly because PE-relative, archive-relative, logical- header-relative, and data-block-relative offsets appear in the same file.

## Physical container

The usual output is a PE followed by an archive:

```text
0                                      PE file start
+------------------------------------+
| DOS header, PE headers, sections   |
| resources and executable stub      |
+------------------------------------+ 512-byte-aligned archive start
| firstheader                        |
+------------------------------------+
| packed logical header              |
+------------------------------------+
| payload data                       |
+------------------------------------+
| optional CRC32                     |
+------------------------------------+ declared archive end
```

The stock compiler pads the archive start to 512-byte alignment. A complete NSIS PE can also be embedded in another PE resource or wrapped by a launcher. In that case archive alignment can be relative to the embedded PE start. A bare magic search is unsafe because payload bytes can contain the same signature.

## First header

The first header begins at the NSIS archive base.

```text
Offset  Size  Type       Field
------  ----  ---------  ---------------------------------------------------
0x00       4  uint32 LE  `flags`, `FH_FLAGS_*`
0x04       4  uint32 LE  `siginfo` = 0xDEADBEEF
0x08       4  uint32 LE  `nsinst[0]` = 0x6C6C754E (`Null`)
0x0C       4  uint32 LE  `nsinst[1]` = 0x74666F73 (`soft`)
0x10       4  uint32 LE  `nsinst[2]` = 0x74736E49 (`Inst`)
0x14       4  int32 LE   decompressed logical-header length
0x18       4  int32 LE   all bytes from first header through archive end
```

Together, the three `nsinst` words are the byte string `NullsoftInst`. The standard structure is 28 bytes.

Standard low flag bits are:

| Bit | Meaning |
| --- | --- |
| `0x01` | Uninstaller data rather than installer data. |
| `0x02` | Script requested silent or silent-log startup. |
| `0x04` | CRC omitted. |
| `0x08` | CRC is mandatory and `/NCRC` cannot disable it. |

NSISBI extends the structure with data-block length fields:

```text
0x1C  4  uint32 LE  data-block length low word
0x20  4  uint32 LE  data-block length high word
```

The trailing words and high flags are route-dependent:

| Route | High flags | Trailing words |
| --- | --- | --- |
| NSISBI through 3.03 | No fork marker in `flags` | `datablock_lowpart` and `datablock_highpart`; bit `0x80000000` of the high word marks external data and the other 63 bits store its length. Both words are zero for all-in-one output. |
| Legacy NSISBI through 3.10 | `0x10` wide data offsets, `0x20` large source offsets, `0x40` external support, `0x80` external data present, `0x100` stub mode | One `uint64 LE` data-block length. |
| Compact NSISBI 3.12 | `0x10` NSISBI marker, `0x20` external data present, `0x40` stub mode | External segment count and nominal segment size in MiB; zero count means one file. |

NSISBI 3.03 cannot be identified from `flags` alone. At archive-relative `+0x1C`, stock NSIS must begin a valid packed-header record or recognized solid codec. The 3.03 route instead places its two data-block words there and begins the packed header at `+0x24`. A parser must validate those competing structures; testing only the high bit of bytes at `+0x20` misclassifies ordinary compressed stock headers.

The compact external route reads ordered `setup1.bin`, `setup2.bin`, and later segments as one logical stream. Legacy output normally uses `<installer>.nsisbin`. `EW_EXTRACTFILE` reads that external stream, while the fork-specific `EW_EXTRACTSTUBFILE` reads data retained in the executable.

## Packed logical header

The bytes after `firstheader` can begin with a packed-size field or directly with a solid codec stream. Its width is four bytes in stock NSIS and NSISBI 3.03, even though the latter already uses 64-bit payload offsets in command records. Later NSISBI routes can widen the packed size to eight bytes. For non-solid media, the top bit marks a compressed item and the remaining bits are the packed byte count.

```text
+-------------------------+
| PackedSizeAndFlag       | uint32 or uint64 LE
+-------------------------+
| codec properties        | codec-dependent
+-------------------------+
| compressed header bytes | packed size
+-------------------------+
| first payload record    |
+-------------------------+
```

For solid media, one codec stream contains the logical header followed by the data block. The first decompressed integer identifies the logical-header length; payload offsets refer to later positions in that decompressed stream.

Route selection must test these structures as competing candidates. A stock solid LZMA stream can begin with bytes that look like a high-bit-set packed-size field, such as `5D 00 00 80`. The parser accepts a route only after decoding the declared logical-header length and validating its complete block table.

## Compression framing

Stock NSIS formats differ from ordinary archive wrappers:

- zlib may appear as RFC 1950 zlib or raw DEFLATE framing;
- NSIS BZip2 omits the normal `BZh` prefix and standard stream CRC framing;
- LZMA stores five property bytes and can prefix an x86 BCJ filter flag;
- stored records contain no decoder state;
- some vendor forks use a raw LZMA2 property byte and LZMA2 chunks.

A parser cannot select a codec from file extension or entropy. It probes a bounded prefix, decodes to the exact declared header length, and validates the logical block table before accepting a candidate.

## NSISBI multithread wrapper

NSISBI can split a logical stream into independently compressed records. Compact 3.12 uses the same transport for a solid archive and inside each compressed non-solid item. Each MTW record is bounded by a three-byte length:

```text
Offset  Size            Field
------  --------------  --------------------------------------------
0x00    3               compressed size, unsigned uint24 LE
0x03    CompressedSize  zlib, BZip2, LZMA, or LZ4 record data
next    repeated        next record
...     3               00 00 00 end marker
```

The source block size depends on the codec: BZip2 uses 900,000 bytes, Deflate and LZ4 use 1 MiB, and LZMA uses 4 MiB. The last block can be shorter. Record order reconstructs the logical stream. A reader can decode only the prefix needed for the logical header, then continue records in order when selected payload offsets require more data.

NSISBI 3.12.3 LZ4 adds another framing layer inside each MTW record:

```text
Offset  Size            Field
------  --------------  --------------------------------------------
0x00    2               raw LZ4 block size, unsigned uint16 LE
0x02    BlockSize       raw LZ4 block
next    repeated        next inner block
...     2               00 00 end marker
```

References in an inner LZ4 block can address bytes emitted by earlier inner blocks. The decoder therefore retains the previous 65,535 output bytes as the dictionary until the enclosing MTW record ends.

## Common header and block table

After decompression, the logical stream begins with the common `header` structure. The first field is a flag word followed by block descriptors. A serialized block descriptor is:

```text
+----------------------+ 0
| Offset               | uint32 or uint64 LE, logical-header-relative
+----------------------+
| CountOrSize          | int32 LE
+----------------------+
```

Runtime source uses a pointer-sized offset because `loadHeaders` converts the serialized relative value into an in-memory address. Standard official stubs normally serialize these logical blocks:

| Index | Block | Descriptor second field |
| --- | --- | --- |
| 0 | Pages | Record count |
| 1 | Sections | Record count |
| 2 | Entries | Record count |
| 3 | Strings | Character count or bytes derived from it |
| 4 | Language tables | Language count |
| 5 | Control colors | Record count |
| 6 | Background font | Record count or presence |
| 7 | Data | Data-block offset/size metadata |

These indexes are configuration-dependent in source. A custom stub compiled without visible pages, background support, or another guarded feature can have a different header shape. Stock-profile readers must reject a block graph that does not consume the selected structure exactly.

## Page, section, and command records

Page and section layouts are fixed structures for a selected stub configuration. Their important cross-references are one-based command addresses.

Stock command records occupy 28 bytes:

```text
Offset  Size  Field
------  ----  ---------------------------------------------
0x00       4  opcode, uint32 LE
0x04       4  operand 0
0x08       4  operand 1
0x0C       4  operand 2
0x10       4  operand 3
0x14       4  operand 4
0x18       4  operand 5
```

NSISBI records occupy 36 bytes and add two operands. Its wide extraction command uses two words for a payload offset and stores a per-file CRC in the last word. Forks can insert commands, which shifts later opcode numbers without changing record width.

## String block

String offsets are measured in characters, not always bytes. ANSI uses one-byte code units; Unicode uses UTF-16LE code units. Strings are NUL-terminated and can contain control sequences for:

- predefined or user variables;
- shell-folder constants;
- language-table references;
- escaped literal control characters.

NSIS 2 ANSI, NSIS 3 ANSI/Unicode, and Jim Park Unicode use different control values and packed-number encodings. A readable NUL-terminated string is not proof that the selected control-code route is correct.

## Language tables

Each language table begins with a language identifier and dialog/font metadata, then contains string offsets. Negative string operands encode a language slot as `-(index + 1)`. The runtime selects one table and resolves that slot to a global string-block offset.

Language table size is stored in the common header. Every table must fit the language block exactly. Counts and offsets are untrusted even when the outer archive signature is valid.

## Non-solid payload records

For a standard non-solid data item:

```text
+-------------------------+
| PackedSizeAndFlag       | uint32 or uint64 LE
+-------------------------+
| compressed/stored body  | bounded packed length
+-------------------------+
```

An `EW_EXTRACTFILE` operand points to the record relative to the data-block base. The command also carries the output-name string, timestamps, overwrite behavior, and error policy. Decompressed size is not available for every compressed item, so extraction requires an independent output limit.

Compact NSISBI 3.12 keeps the outer `uint64` packed-size record. When its compression bit is set, the body is an MTW stream rather than one stock codec stream. The MTW `uint24` zero terminator must occur within the outer packed length.

## Solid payload records

Solid payload offsets identify positions in the decompressed stream. At each position, a width-matched integer gives the uncompressed file length followed by the file body. Selected files must be processed in increasing offset order; restarting the codec for every file wastes CPU and can make large archives quadratic.

## External NSISBI data

An NSISBI stub can keep executable and payload data in separate files. The compiled `VerifyExternalFile` command supplies a path. If it is not a valid path, the runtime derives `<installer-base>.nsisbin`. The sidecar is a second bounded data source, not bytes physically adjacent to the PE.

Compact 3.12 instead records a segment count and nominal segment size in the extended first header and resolves `setup1.bin`, `setup2.bin`, and later files. The ordered segments form one seekable address space; a payload can begin in one segment and end in another. They should be streamed through a segmented reader, not concatenated into one allocation.

The `.exe` and sidecar files must be treated as one fixture. Parsing only the stub can recover command and string evidence but cannot prove or extract the complete payload.

## Integrity

Stock NSIS appends a little-endian CRC32 when `FH_FLAGS_NO_CRC` is clear. Runtime coverage begins at `owning_stub_offset + 512`, includes the first header and archive data, and stops before the final four-byte checksum. The origin is relative to the PE stub that owns an embedded archive, not necessarily offset zero of an outer wrapper. `/NCRC` can disable a non-forced runtime check.

NSISBI checksum operands are ABI-specific. Controlled 3.03 output stores the CRC32 of the extracted file bytes. Compact 3.12 computes CRC32 over the serialized stored or compressed body and then the original packed-size field. This lets the runtime verify a record before decoding it. Codec-internal checks remain separate, especially for NSIS BZip2.

Range validation and successful decompression do not replace checksum validation. A parser should expose whether a checksum was present, what range it covered, and whether it was verified.

## Source references

- [NSIS serialized structures](https://github.com/NSIS-Dev/nsis/blob/master/Source/exehead/fileform.h)
- [NSIS archive loader](https://github.com/NSIS-Dev/nsis/blob/master/Source/exehead/fileform.c)
- [NSIS output writer](https://github.com/NSIS-Dev/nsis/blob/master/Source/build.cpp)
- [7-Zip NSIS format reader](https://github.com/ip7z/7zip/tree/main/CPP/7zip/Archive/Nsis)
- [NSISBI](https://sourceforge.net/projects/nsisbi/)
