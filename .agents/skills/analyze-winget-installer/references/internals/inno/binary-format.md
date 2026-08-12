# Inno Setup binary format

This page describes the on-disk structures shared by the Inno compiler, SetupLdr, setup engine, and uninstaller. Current structures come from `Shared.Struct.pas`; historical differences are summarized in [format history](format-history.md).

Integers are little-endian unless stated otherwise. `absolute` means relative to the beginning of the current file. Other offset bases are labeled.

## Normal single-file container

The offset table, rather than physical adjacency, defines the container:

```text
Setup.exe
+-- SetupLdr PE image
|   `-- .rsrc / RT_RCDATA / #11111
|       `-- TSetupLdrOffsetTable
+-- setup-1 payload at Offset1
+-- setup-0 metadata at Offset0
`-- compressed setup engine at OffsetEXE
```

Current compiler output can place payload bytes before setup-0 and the setup engine. Do not model the file as a simple `PE + metadata + payload` overlay.

## `TSetupLdrOffsetTable` v2

The current resource table is 64 bytes. Delphi aligns the 64-bit fields naturally, but the declared field order and offsets below match the persisted record used by current 32-bit and 64-bit loaders.

```text
Base: start of RCDATA resource #11111

Offset  Size  Type       Field
------  ----  ---------  -----------------------------------------------
0x00      12  bytes      ID = 72 44 6C 50 74 53 CD E6 D7 7B 0B 2A
0x0C       4  uint32 LE  Version = 2
0x10       8  int64 LE   TotalSize, minimum expected Setup.exe size
0x18       8  int64 LE   OffsetEXE, compressed Setup.e32/e64
0x20       4  uint32 LE  UncompressedSizeEXE
0x24       4  int32 LE   CRCEXE of restored setup engine
0x28       8  int64 LE   Offset0, embedded setup-0
0x30       8  int64 LE   Offset1, embedded setup-1; 0 for disk spanning
0x38       4  uint32 LE  ReservedPadding
0x3C       4  int32 LE   TableCRC over bytes 0x00 through 0x3B
```

Printable bytes in the ID are `rDlPtS`; the remaining six bytes prevent a casual text collision.

SetupLdr validates the table version, CRC, expected total size, engine range, setup-data ranges, and restored engine CRC before execution.

## Resource table v1

The previous resource layout is 44 bytes and uses 32-bit values:

```text
Offset  Size  Type       Field
------  ----  ---------  -----------------------------------------------
0x00      12  bytes      offset-table ID
0x0C       4  uint32 LE  Version = 1
0x10       4  uint32 LE  TotalSize
0x14       4  uint32 LE  OffsetEXE
0x18       4  uint32 LE  UncompressedSizeEXE
0x1C       4  int32 LE   CRCEXE
0x20       4  uint32 LE  Offset0
0x24       4  uint32 LE  Offset1
0x28       4  int32 LE   TableCRC over bytes 0x00 through 0x27
```

Historical readers must use the exact versioned record. Interpreting v1 as the first 44 bytes of v2 shifts every offset after `TotalSize`.

## Legacy loader pointer and tables

Before the PE resource route, the outer loader kept an `Inno` pointer record at absolute file offset `0x30`:

```text
Base: absolute 0x30

Offset  Size  Type       Field
------  ----  ---------  -----------------------------------------------
0x00       4  uint32 LE  0x6F6E6E49, bytes 49 6E 6E 6F ("Inno")
0x04       4  uint32 LE  absolute offset-table pointer
0x08       4  uint32 LE  one's complement of pointer
```

The pointed table identifies one of the historical `rDlPtS02`, `S04`, `S05`, `S06`, or `S07` layouts. Field locations vary:

| Layout | Bytes | `TotalSize` | `Offset0` | `Offset1` | CRC |
| --- | ---: | ---: | ---: | ---: | --- |
| S02 | 44 | `+0x0C` | `+0x24` | `+0x28` | None |
| S04 | 40 | `+0x0C` | `+0x20` | `+0x24` | None |
| S05 | 40 | `+0x0C` | `+0x20` | `+0x24` | None |
| S06 | 44 | `+0x0C` | `+0x20` | `+0x24` | at `+0x28`, covers 40 bytes |
| S07 | 40 | `+0x0C` | `+0x1C` | `+0x20` | at `+0x24`, covers 36 bytes |

These older tables also carried setup-engine location information in version-specific positions. A metadata-only reader can stop after validating the fields needed to locate setup-0, but a complete loader model must retain the setup-engine location and integrity fields.

## Embedded setup engine

`OffsetEXE` points to an internally compressed setup-engine PE image. Current SetupLdr:

1. seeks to `OffsetEXE`;
2. uses the small LZMA decompressor built into SetupLdr;
3. restores the compiler's CALL-instruction transform;
4. checks the restored byte count against `UncompressedSizeEXE`;
5. checks `CRCEXE`;
6. writes the image to a protected temporary path;
7. executes it with `/SL5=`.

The setup engine is distinct from package files described by `TSetupFileLocationEntry`.

## Setup-0 top-level layout

`Offset0` points to setup metadata:

```text
Base: absolute Offset0

+-------------------------------+ 0x00
| SetupID                       | 64 bytes
+-------------------------------+ 0x40
| EncryptionHeaderCRC           | int32 LE
+-------------------------------+ 0x44
| TSetupEncryptionHeader        | 49 packed bytes in current format
+-------------------------------+
| Compressed block 1            | setup header, records, resources
+-------------------------------+
| Compressed block 2            | file-location entries
+-------------------------------+
```

Older formats predate the current encryption header. Its presence is structure-version dependent.

## `SetupID`

`SetupID` is an array of 64 ANSI characters. The current identity is:

```text
Inno Setup Setup Data (7.0.0.3)
```

The remainder of the field is zero padding. The setup engine compares all 64 bytes with the identity compiled into that runtime. This is a binary compatibility check between the metadata producer and consumer.

Historical ANSI/Unicode and third-party editions use other identities. `(u)` appears in many Unicode-era IDs but is absent from recent Unicode-only formats.

## `TSetupEncryptionHeader`

Current packed payload size is 49 bytes:

```text
Record-relative

Offset  Size  Type       Field
------  ----  ---------  -----------------------------------------------
0x00       1  enum       EncryptionUse: None, Files, Full
0x01      16  bytes      KDFSalt
0x11       4  int32 LE   KDFIterations
0x15      24  bytes      BaseNonce / stream-position state
0x2D       4  int32 LE   PasswordTest
```

`BaseNonce` is itself a packed runtime record containing a random XOR start offset, first slice, and remaining random state. Separate stream-context constants prevent the same base state from being reused identically for metadata block 1, metadata block 2, and file chunks.

The preceding CRC detects a malformed header; it is not password authentication. Setup derives a key from the supplied password, salt, and iteration count, then checks `PasswordTest`.

## Compressed block framing

Current metadata blocks use a CRC-protected header and CRC-protected pieces:

```text
+-------------------------------+
| HeaderCRC                     | int32 LE
+-------------------------------+
| StoredSize                    | int64 LE in 6.7+/7; uint32 in prior route
+-------------------------------+
| Compressed                    | byte
+-------------------------------+
| PieceCRC                      | uint32 LE
+-------------------------------+
| PieceData                     | up to 4096 bytes
+-------------------------------+
| PieceCRC + PieceData          | repeated until StoredSize consumed
+-------------------------------+
```

`StoredSize` includes each four-byte piece CRC. The header CRC covers only the serialized size and compressed flag. Block 1 and block 2 are separate compressor streams.

Earlier routes use:

- the same chunk concept with a 32-bit stored size and Zlib;
- a legacy header containing signed compressed and uncompressed sizes, where compressed size `-1` means stored;
- Zlib before LZMA became the internal metadata compressor.

## Record serialization

`SECompressedBlockWrite` serializes a shared record as:

```text
for each String field:
  int32 byte length
  encoded bytes

for each AnsiString field:
  int32 byte length
  ANSI bytes

packed fixed tail:
  bytes after all in-memory string-pointer slots
```

For current Unicode structures, ordinary `String` bytes are UTF-16LE. `AnsiString` fields remain byte-oriented. Fixed-tail size depends on the record definition, but the serialized tail does not include live pointer values.

No per-record length wraps the whole record. A reader must know the exact string counts and fixed-tail size for that `SetupID`.

## Compressed block 1 order

Current compiler order is:

```text
TSetupHeader
TSetupLanguageEntry[]
TSetupCustomMessageEntry[]
TSetupPermissionEntry[]
TSetupTypeEntry[]
TSetupComponentEntry[]
TSetupTaskEntry[]
TSetupDirEntry[]
TSetupISSigKeyEntry[]
TSetupFileEntry[]
TSetupIconEntry[]
TSetupIniEntry[]
TSetupRegistryEntry[]
TSetupDeleteEntry[]        [InstallDelete]
TSetupDeleteEntry[]        [UninstallDelete]
TSetupRunEntry[]           [Run]
TSetupRunEntry[]           [UninstallRun]
wizard-image streams
dynamic-dark image streams
optional decompressor DLL stream
optional 7-Zip DLL stream
```

Every table count is stored in `TSetupHeader`. Image/resource streams use their own count and size framing after the logical entry tables.

## Compressed block 2

Block 2 is a flat array of `TSetupFileLocationEntry` records. Current entries contain no strings:

```text
Offset  Size  Field
------  ----  ----------------------------------------------------------
0x00       4  FirstSlice, int32
0x04       4  LastSlice, int32
0x08       8  StartOffset, int64
0x10       8  ChunkSuboffset, int64
0x18       8  OriginalSize, int64
0x20       8  ChunkCompressedSize, int64
0x28      32  SHA256Sum
0x48       8  FILETIME timestamp
0x50       4  FileVersionMS
0x54       4  FileVersionLS
0x58       n  packed flags/set representation for current structure
```

The exact final size follows Delphi packed-set representation and format version. Historical records use other integer widths, timestamps, digests, and flag sets.

`StartOffset` is relative to the first relevant payload data set, not setup-0. `ChunkSuboffset` is relative to the decompressed chunk.

## Payload chunks and disk slices

Payload compression chunks start with:

```text
7A 6C 62 1A     ASCII "zlb" followed by 0x1A
```

The chunk header and compressor properties vary by historical payload route. Files can be Stored, Zlib, BZip2, LZMA, or LZMA2 according to the setup header and location flags.

For solid compression:

```text
one compressed chunk
`-- decompressed stream
    +-- file A at suboffset A
    +-- file B at suboffset B
    `-- file C at suboffset C
```

Each file location carries its own original size, digest, timestamp, and version even when it shares the compressed stream.

A standalone disk slice uses one of two source-defined headers:

```text
Before structure 6.5.2
Offset  Size  Field
------  ----  ---------------------------------------
0x00       8  69 64 73 6B 61 33 32 1A: "idska32" SUB
0x08       4  TotalSize, uint32 LE

Structure 6.5.2 and later
Offset  Size  Field
------  ----  ---------------------------------------
0x00       8  69 64 73 6B 62 33 32 1A: "idskb32" SUB
0x08       8  TotalSize, int64 LE
```

Disk spanning was introduced in Inno Setup 4.0. Structures before 4.0 do not
serialize `SlicesPerDisk`; Setup treats them as single-slice media and their
file-location records cannot route into external `Setup-*.bin` payloads.

`TotalSize` must equal the physical file length. `FirstSlice` and `LastSlice` are zero-based logical indexes. `SlicesPerDisk=1` maps index 0 to `Setup-1.bin`, index 1 to `Setup-2.bin`, and so on. Larger values use letter suffixes: with `SlicesPerDisk=2`, indexes 0 and 1 are `Setup-1a.bin` and `Setup-1b.bin`, while index 2 is `Setup-2a.bin`.

`StartOffset` is relative to the first physical slice and points to the `zlb 1A` marker. Compressed bytes begin four bytes later. When a chunk crosses a slice boundary, reading resumes immediately after the next slice header; headers are framing and are not part of the compressed stream.

## Uninstaller mode marker

The setup-engine PE header reuses absolute offset `0x30` as a mode field when it is prepared as an uninstaller or RegSvr helper:

```text
0x6E556E49  SetupExeModeUninstaller
0x53526E49  SetupExeModeRegSvr
```

This field belongs to the extracted/prepared setup engine, not the normal SetupLdr pointer scheme used by old outer installers.

## Uninstall data format

The uninstaller data file begins with `TUninstallLogHeader`, kept under 512 bytes for atomic-sector update behavior:

```text
TUninstallLogHeader
+-- ID[64], distinguishes 32-bit and 64-bit install mode
+-- AppId[128] and AppName[128], safe ANSI representation
+-- Version, NumRecs, EndOffset, Flags
+-- reserved fields
`-- header CRC

Repeated uninstall records
+-- TUninstallFileRec
|   +-- Typ
|   +-- ExtraData
|   `-- DataSize
+-- encoded string/data payload
`-- CRC framing
```

The uninstall log is designed for backward compatibility across setup updates. Appearance settings that should come from the latest installer are stored separately in the messages file rather than added as non-sticky uninstall-header fields.

See [uninstaller and ARP](uninstaller-and-arp.md) for semantics.

## Source references

- [Shared.Struct.pas](https://github.com/jrsoftware/issrc/blob/main/Projects/Src/Shared.Struct.pas)
- [Shared.SetupEntFunc.pas](https://github.com/jrsoftware/issrc/blob/main/Projects/Src/Shared.SetupEntFunc.pas)
- [SetupLdr.dpr](https://github.com/jrsoftware/issrc/blob/main/Projects/SetupLdr.dpr)
- [Setup.UninstallLog.pas](https://github.com/jrsoftware/issrc/blob/main/Projects/Src/Setup.UninstallLog.pas)
