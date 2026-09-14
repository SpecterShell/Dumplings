# CreateInstall binary format

## Offset conventions

PE section offsets are absolute file offsets obtained from `PointerToRawData`. Launcher fields are relative to the physical setup file unless stated otherwise. GE object offsets are relative to the decoded GE program. GEA catalog and payload offsets are relative to the GEA volume or its logical multi-volume data space. All documented integers are little-endian except where a linked data format defines otherwise.

## PE and launcher

The supported setup contains exactly one `.gentee` section and one `Gentee Launcher\0` header in the bounded launcher search region.

```text
PE image
+-- headers and ordinary runtime sections
`-- .gentee
    +-- RuntimeSize bytes: linked Gentee launcher/runtime
    `-- ProgramRangeSize bytes: stored GE program or [ExpandedSize][LZGE data]
```

```text
Launcher-relative  Size  Field
-----------------  ----  -----------------------------------------
0x00                 15  `Gentee Launcher\0`
0x1A                  1  Packed flag
0x1D                  4  RuntimeSize, uint32
0x21                  4  ProgramRangeSize, uint32
0x2D                  4  recorded absolute launcher offset, uint32
```

The parser requires the recorded offset to equal the located header offset. `RuntimeSize` and `ProgramRangeSize` must fit the raw `.gentee` section. A packed program begins with a four-byte expanded size followed by LZGE data; a stored program begins directly with the GE header.

## GE header

```text
GE-relative  Size  Field
-----------  ----  -----------------------------------------------
0x00            4  magic `47 45 00 00` (`GE\0\0` as uint32 0x4547)
0x04            4  reserved or build field retained by the runtime
0x08            4  Gentee CRC32 over [0x0C, ProgramSize)
0x0C            4  HeaderSize, uint32
0x10            4  ProgramSize, uint32
0x14            1  major version, supported value 4
0x15            1  minor version
HeaderSize   ...   serialized object records through ProgramSize
```

Gentee seeds CRC with `0xFFFFFFFF` and does not apply a final inversion. The parser computes standard CRC32 over the same half-open range and XORs the result with `0xFFFFFFFF` before comparing it with the stored value.

## GE object records

```text
+----------------------+ object start
| Type                 | byte
+----------------------+
| Flags                | uint32 LE
+----------------------+
| RecordSize           | BWD
+----------------------+
| Name                 | optional UTF-8 NUL string when GHCOM_NAME
+----------------------+
| Type-specific body   | bounded by object start + RecordSize
+----------------------+ next object
```

`GHCOM_NAME` is `0x0001` and `GHCOM_PACK` is `0x0002`. Every observed CreateInstall object sets the packed-size form. The leading resource object has no VM object ID; later records receive sequential IDs beginning at 1024. The parser requires every object to end within `ProgramSize` and the final object to end exactly at it.

BWD values use one to five bytes. A lead from 0 through 187 is the value. Leads 188 through 253 read one following byte and compute `255 * (lead - 188) + next`. Lead 254 reads a following `uint16`; lead 255 reads a following `uint32`.

## Function bytecode and imports

Function records contain variable descriptors, parameter and local-variable groups, and commands. Generic operand widths come from Gentee's 218-entry command-shift table. Literal-load commands have explicit raw or BWD-delimited payloads. Object IDs at or above 1024 are direct calls to linked functions.

Imported libraries are object type 8 records. `GHIMP_LINK` (`0x0100`) introduces an embedded library byte range. External functions are object type 4 records; `GHEX_IMPORT` (`0x080000`) ends the record with an import object ID and original UTF-8 function name. The parser indexes these relationships but never loads a library.

## Project list framing

`MAINVAR` and operation lists live in an initialized Gentee `buf` and are referenced by bytecode offsets.

```text
+----------------------+ list-relative offset
| RowCount             | uint32 LE
+----------------------+
| Field 0              | UTF-8 NUL string
+----------------------+
| Field 1 ... N        | fixed count for the selected route
+----------------------+
| next row             | same field count
+----------------------+
```

Detection requires a two-field `MAINVAR` table with `progname`, `ver`, `compname`, `setuppath`, `uninstexe`, and `silentpar`. Other offsets are decoded only from a matching call route and fixed row schema; the parser does not scan arbitrary buffers for plausible strings.

## GEA header

```text
GEA-relative  Size  Field
------------  ----  -----------------------------------------------
0x00             4  `47 45 41 00` (`GEA\0`)
0x04             2  VolumeNumber, uint16
0x06             4  UniqueID, uint32
0x0A             1  MajorVersion: 1 or 2
0x0B             1  MinorVersion
0x14             4  Flags, uint32
0x18             2  VolumeCount, uint16
0x1A             4  HeaderSize, uint32
0x1E             8  SummarySize, int64
0x26             4  InfoSize, uint32
0x2A             8  ArchiveFileSize, int64
0x32             8  VolumeSize, int64
0x3A             8  LastVolumeSize, int64
0x42             4  MovedSize, uint32
0x46             3  memory, block, and solid multipliers
0x49           var  volume pattern, password table, and file catalog
```

The fixed packed prefix is 73 bytes. `GEAH_PASSWORD` adds password CRC records. `GEAH_COMPRESS` stores the descriptor table as LZGE data. File descriptors inherit selected attributes, group, password, and folder values from the preceding record according to flags.

## File and block records

GEA1 uses 32-bit packed and expanded sizes; GEA2 uses 64-bit sizes. A file descriptor also carries flags, FILETIME, Gentee CRC32, group ID, password ID, folder/name data, and block metadata.

```text
+----------------------+ block start
| Order                | byte
+----------------------+
| CompressedSize       | uint32 LE for GEA1, uint64 LE for GEA2
+----------------------+
| CompressedData       | CompressedSize bytes
+----------------------+ next block
```

After clearing protection bit `0x80`, the high nibble identifies Store (`0`), LZGE (`1`), or Gentee PPMd-I (`2`); the low nibble plus one is the order. Store writes its declared bytes. LZGE can retain the preceding dictionary only for order one. PPMd keeps its model across solid continuation blocks and starts a fresh range stream for each block. Expanded length and Gentee CRC32 are checked before an entry is accepted.

## Multi-volume address space

Each companion begins with `[GEA\0][VolumeNumber:uint16][UniqueID:uint32]`. The main header's printf-style pattern receives a one-based display number, while the companion field stores a zero-based volume number.

```text
logical payload stream
+-- ordinary main-volume data
+-- companion 1 body
+-- companion 2 body
+-- ...
`-- MovedSize bytes physically stored after the main variable header
```

The parser resolves a requested logical range into only the required physical slices. It validates companion path containment, magic, number, unique ID, declared size, order, and total logical coverage before opening payload streams.
