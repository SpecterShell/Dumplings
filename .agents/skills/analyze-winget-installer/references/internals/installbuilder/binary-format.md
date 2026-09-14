# InstallBuilder binary format

## Offset conventions

Absolute offsets are measured from the first byte of the distributed executable. Metakit positions are relative to the selected Metakit header. CookFS file blocks refer to decoded page-relative offsets. CookFS tail offsets are derived backward from the accepted `CFS0002` marker. Multibyte Metakit header and commit fields are big-endian unless a table says otherwise; Metakit integer-column byte order is selected by the `JL` or `LJ` signature. CookFS multibyte integers are unsigned big-endian. LZMA properties and lengths use the little-endian LZMA-alone representation consumed by the runtime handler.

## Outer PE

Every supported Windows installer is a valid PE containing a TclKit-derived runtime. The mapped PE sections do not define the complete installer because Metakit and CookFS records can occupy appended ranges, and Authenticode data can follow the logical payload.

```text
absolute file layout

0x00000000  DOS header and PE image
            mapped section data and Tcl/Tk runtime
            one or more Metakit VFS databases
            optional alignment and runtime-owned records
            optional CookFS page store and CFS0002 tail
logical end optional Authenticode certificate or bounded trailing data
```

The parser searches for candidate structural markers, then validates complete ranges. A `project.xml`, `JL`, `LJ`, `CFS2.200`, or `CFS0002` byte sequence alone does not establish the family.

## Metakit database header

InstallBuilder uses the TclKit VFS schema stored in a Metakit database. The parser accepts the two current Metakit signatures and uses the signature to select integer-column byte order.

```text
Metakit header, relative to database start

Offset  Size  Field
------  ----  ---------------------------------------------------------
0x00       4  4A 4C 1A 00, "JL\x1A\0", little-endian integer columns
             or 4C 4A 1A 00, "LJ\x1A\0", big-endian integer columns
0x04       4  database logical length, uint32 BE
```

The declared logical length must be at least 24 bytes and remain inside the installer. It ends at the second commit mark rather than necessarily at the physical end of the executable.

## Metakit commit tail

The final 16 bytes contain two eight-byte commit marks. Dumplings does not assign semantics to fields that are unnecessary for VFS recovery; it validates the observed first mark and uses the second mark as the root descriptor locator.

```text
Metakit logical end minus 16 bytes

Offset  Size  Field
------  ----  ---------------------------------------------------------
0x00       1  first commit marker, observed 0x9x or empty-tail 0x80 form
0x01       3  first commit observed length/status, uint24 BE
0x04       4  first commit position/status, uint32 BE, must be nonzero
0x08       1  root commit marker, exactly 0x80
0x09       3  root descriptor length, uint24 BE
0x0C       4  root descriptor position, uint32 BE, Metakit-relative
```

The root descriptor must be nonempty and fully contained in the declared database. Invalid commit marks, overflowed ranges, and root positions that cross the logical end reject that Metakit candidate.

## Metakit adaptive values and locations

Descriptors use adaptive signed integers of one through six bytes. Each byte contributes seven bits in most-significant-group-first order. Bit `0x80` marks the final byte. A value beginning with zero uses the complemented negative form. The parser rejects unterminated or longer encodings.

```text
adaptive value

+-------------------+-------------------+-----+-------------------+
| 0xxxxxxx          | 0xxxxxxx          | ... | 1xxxxxxx          |
+-------------------+-------------------+-----+-------------------+
  high-order group                              final group
```

A descriptor location stores `Size` followed by `Position` only when `Size` is nonzero. Both are adaptive values. Positions are relative to the Metakit header, and every range must fit within the declared database.

```text
location := AdaptiveSize [ AdaptivePosition when Size > 0 ]
```

## Metakit VFS descriptors

The accepted root schema is exact:

```text
dirs[name:S,parent:I,files[name:S,size:I,date:I,contents:B]]
```

The root descriptor and referenced sequence descriptors form this hierarchy:

```text
root descriptor
+-- format code = 0
+-- schema byte length
+-- exact UTF-8 schema
+-- root row count = 1
`-- directory-sequence location

directory-sequence descriptor
+-- format code = 0
+-- directory count
+-- directory name byte column
+-- parent integer-column location
`-- file-subview descriptor-column location

one file sequence per directory
+-- format code = 0
+-- file count
+-- file name byte column
+-- logical size integer-column location
+-- modification date integer-column location
`-- contents byte column
```

String and byte columns are represented by an inline data location, an optional size-vector location when inline data is nonempty, and a memo-table location. The size vector must consume the inline data exactly. Memo records contain a row delta followed by a location and replace the corresponding inline range.

```text
byte column descriptor
+-- data location
+-- size-vector location, present when data size is nonzero
`-- memo-table location

memo table
`-- repeated: AdaptiveRowDelta, Location
```

Integer columns use widths of 0, 1, 2, 4, 8, 16, or 32 bits selected from row count and column byte length according to Metakit's adaptive column rules. Sub-byte fields are packed least-significant-bit first within a byte. Eight-bit, 16-bit, and 32-bit fields are signed; multibyte order follows the database signature.

The directory graph must have exactly one `<root>` row with parent `-1`. Every other parent must reference a valid directory, cycles are rejected, and path components cannot be empty, `.` or `..`, contain a NUL, or contain a path separator.

## Legacy Metakit payload records

Legacy media keeps application payload bytes in `contents:B`. The parser identifies the directory named by the `origindist` control record, maps its descendants through compiled folder destinations, and excludes Tcl/Tk runtime files stored elsewhere in the VFS.

```text
one VFS file row

name:S       validated UTF-8 path component
size:I       declared expanded length
date:I       Unix modification time used as file metadata
contents:B   inline or memo-owned byte range
```

When stored length equals logical length, `contents` is copied as stored data. A shorter record is accepted as zlib only when its RFC 1950 CMF/FLG bytes are valid and the preset-dictionary flag is clear. Expanded output must equal the declared logical size.

## Project XML record

The preferred `project.xml` route reads the exact Metakit-owned entry. Legacy InstallBuilder stores that entry as zlib-compressed UTF-8 XML. The decompressed content must contain a complete `<project>...</project>` document within the project-size limit.

If no readable VFS catalog is available, the metadata-only fallback examines bounded RFC 1950 candidates using the valid headers `78 01`, `78 5E`, `78 9C`, and `78 DA`. It accepts only strict UTF-8 containing a complete project root. This fallback proves project metadata but not payload ownership.

## CookFS2 physical tail

CookFS2 stores data pages before a fixed tail. The 16-byte page hash and four-byte stored-size records are repeated once for every page. `IndexSize` includes the compressed index record, including its one-byte compression handler.

```text
CookFS2 logical range

+-------------------------------+ PageDataStart
| stored page 0                 | PageSizes[0]
+-------------------------------+
| stored page 1                 | PageSizes[1]
+-------------------------------+
| ...                           |
+-------------------------------+ IndexOffset
| page integrity record 0       | 16 bytes
| ...                           | PageCount * 16
+-------------------------------+ SizeOffset
| stored page size 0, uint32 BE | 4 bytes
| ...                           | PageCount * 4
+-------------------------------+ StoredIndexOffset
| compressed file index         | IndexSize bytes
+-------------------------------+ EndOffset - 16
| IndexSize, uint32 BE           |
| PageCount, uint32 BE           |
| Index compression ID, uint8   |
| 43 46 53 30 30 30 32          | ASCII "CFS0002"
+-------------------------------+ EndOffset
```

The parser derives `IndexOffset = EndOffset - 16 - IndexSize - PageCount * 20`, reads stored sizes, subtracts their sum to obtain `PageDataStart`, and then reconstructs every page offset forward. All arithmetic is checked before allocation or reading. The footer compression identifier must equal the first byte of the stored index record.

## CookFS compression records

Every stored page and stored index begins with a one-byte handler identifier.

| ID | Framing after ID | Decoder | Support |
| --- | --- | --- | --- |
| `0` | raw bytes | stored copy | Supported |
| `1` | raw Deflate stream | Deflate | Supported |
| `2` | four-byte observed CookFS length prefix followed by BZip2 data | BZip2 | Supported |
| `255` | five-byte LZMA properties, eight-byte little-endian expanded length, compressed bytes | LZMA | Supported only for the validated unencrypted InstallBuilder form |
| Other | handler-defined | custom | Unsupported |

```text
stored or Deflate record
+--------+------------------------------+
| ID     | stored bytes or Deflate data |
+--------+------------------------------+
  1 byte

BZip2 record
+--------+----------------+------------------+
| 0x02   | observed u32   | BZip2 data       |
+--------+----------------+------------------+
  1 byte   4 bytes BE

InstallBuilder LZMA record
+--------+------------+----------------------+------------------+
| 0xFF   | properties | expanded length      | LZMA data        |
+--------+------------+----------------------+------------------+
  1 byte   5 bytes      int64 LE
```

For LZMA, the dictionary size encoded in the properties must be nonzero and within the configured dictionary limit, and the declared output length must be nonnegative and bounded. Handler `255` can also represent project-specific encryption or custom compression; a record that does not satisfy the validated unencrypted framing remains unsupported.

## CookFS page integrity

The default 16-byte integrity record is the MD5 digest of the expanded page. When index metadata sets `cookfs.pagehash` to `crc32`, CookFS uses this record instead:

```text
CRC32 page record

Offset  Size  Field
------  ----  -----------------------------------
0x00       8  zero prefix
0x08       4  expanded page length, uint32 BE
0x0C       4  CRC32 of expanded page, uint32 BE
```

The parser verifies each page after decompression and before copying file blocks. Unknown page-hash algorithms prevent verified extraction rather than silently accepting bytes.

## CookFS file index

The expanded file index begins with `CFS2.200` and contains one recursive root directory node. Every path component is UTF-8 and NUL-terminated. File records map logical byte ranges to one or more expanded pages.

```text
expanded index

+-----------------------------+
| 43 46 53 32 2E 32 30 30     | ASCII "CFS2.200"
+-----------------------------+
| root directory node         | recursive
+-----------------------------+
| optional metadata table     |
+-----------------------------+
```

```text
directory node and item, all integers BE

uint32 ItemCount
repeat ItemCount times:
  uint8  NameLength
  byte   Name[NameLength], strict UTF-8
  uint8  NulTerminator, must be 0
  uint64 ModificationTimeUnixSeconds
  uint32 BlockCount
  if BlockCount == 0xFFFFFFFF:
    DirectoryNode Child
  else:
    repeat BlockCount times:
      uint32 Page
      uint32 OffsetWithinExpandedPage
      uint32 Length
```

Each block must reference an existing page, and `Offset + Length` must fit the expanded page. A file can span pages and can share page bytes with another file. Directory names cannot contain separators or traversal tokens.

## CookFS index metadata

Older indexes end immediately after the root directory. Current indexes append a counted metadata table.

```text
uint32 MetadataCount
repeat MetadataCount times:
  uint32 RecordSize
  byte   Key[]
  uint8  NulTerminator
  byte   Value[remaining RecordSize bytes]
```

Keys are strict UTF-8. Values are decoded as UTF-8 when possible. Values whose keys indicate passwords, passphrases, secrets, tokens, credentials, or private keys are returned only as `<redacted>` plus length metadata.

## Split logical files

InstallBuilder can split one large logical file into consecutive physical records named `Name___bitrockBigFile1`, `Name___bitrockBigFile2`, and so on. The base record starts the logical file; contiguous numbered records are concatenated in order. A numbered record without a base is not promoted to an independent installed path.

```text
physical entries                       logical output

payload/setup.bin                 +--+
payload/setup.bin___bitrockBigFile1  +--> payload/setup.bin
payload/setup.bin___bitrockBigFile2 +--+
```

## Installed-path projection

CookFS and legacy VFS paths are storage identities. The compiled component and folder records map a storage prefix to an installation destination. Paths below `${installdir}` become relative output paths. Other destination roots are isolated below `_destinations` so extraction never writes into host system directories. Duplicate projected paths are also isolated rather than resolved by extraction order.

## Structural invariants

The full supported format requires a valid PE, a bounded project-owning Metakit VFS, an exact and parseable project XML record, and either a valid legacy `origindist` payload tree or a valid CookFS2 tail. Metadata-only `ProjectRecord` recovery is intentionally weaker and does not establish extraction support.

The parser rejects out-of-range roots, excessive counts, duplicate VFS paths, cyclic directory graphs, invalid UTF-8 names, unsafe paths, malformed compression framing, unsupported custom handlers, page size mismatches, integrity failures, block ranges outside decoded pages, and trailing bytes after a declared CookFS metadata table.

## Source references

- [Metakit format overview](https://www.equi4.com/metakit/format.html)
- [Metakit source repository](https://github.com/jcw/metakit)
- [CookFS source repository](https://github.com/chpock/cookfs)
- [MIT CookFS extraction research](https://github.com/vpetrigo/bitrock-unpacker)
- [InstallBuilder payload extraction research](https://gist.github.com/NyaMisty/3d3b9a39fca463ca9e16628e96877b5c)
