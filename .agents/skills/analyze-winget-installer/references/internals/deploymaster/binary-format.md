# DeployMaster binary format

## Locator-based package

DeployMaster 6 and later keeps a fixed absolute locator in the PE stub. Integers are little-endian and offsets are absolute unless a layout says otherwise.

```text
Base   Offset  Size  Field
-----  ------  ----  -----------------------------------------------
[abs]  0x80       4  PackageOffset, uint32 -> PE overlay
[abs]  0x84       4  IntegrityLength, uint32
[abs]  0x88       4  ExpectedCRC32, uint32
[abs]  0x8C       8  ExpectedFileSize, uint64
[abs]  0x94       4  Reserved/observed
```

`PackageOffset + IntegrityLength` is the protected package-control boundary and `ExpectedCRC32` covers exactly that range. `ExpectedFileSize` is the logical package ending. Signed media may add zero alignment through the next eight-byte boundary followed by the exact PE certificate-table range; any other physical-size disagreement is invalid.

```text
PE setup stub
+-- locator at absolute 0x80
`-- package at PackageOffset
    +-- 66-, 70-, or 74-byte control header
    +-- raw-LZMA runtime core(s)
    +-- optional UTF-16LE expiration message
    +-- language data block
    +-- identity data block
    +-- Header74 package settings and optional portable-folder block
    +-- auxiliary metadata-resident payloads
    +-- component block
    +-- CRLF filename block
    +-- parallel file catalog
    +-- installation-tree block
    +-- registry block
    +-- file-association block
    +-- prerequisite, completion, uninstall, and update tail
    +-- application payload ranges
    +-- optional zero alignment
    `-- optional WIN_CERTIFICATE table
```

## Control-header profiles

All profiles start with five raw-LZMA property bytes. Let `Shift` be `-8` for Header66, `-4` for Header70, and `0` for Header74.

```text
Base       Offset            Size  Field
---------  ----------------  ----  ------------------------------------------------------
[package]  0x00                 5  raw-LZMA properties
[package]  0x05                 8  platform flags, uint64
[package]  0x0C                 1  bit 7 permits future Windows versions
[package]  0x0D                 4  Windows 10 min/max uint16 pair, Header70/74
[package]  0x11                 4  Windows 11 min/max uint16 pair, Header74
[package]  0x15 + Shift         1  scope selector
[package]  0x16 + Shift        12  x86 core offset/stored/expanded tuple
[package]  0x22 + Shift        12  x64 core offset/stored/expanded tuple
[package]  0x2E + Shift         4  language-block absolute offset
[package]  0x32 + Shift         6  expiration year/month/day, uint16 values
[package]  0x38 + Shift         4  expiration-message absolute offset
[package]  0x3C + Shift         2  expiration-message UTF-16 code-unit count
```

Core offset zero means absent. The x64 offset can be `0xFFFFFFFF` for x86-only-on-x86 media. A core tuple is indivisible: offset, stored size, and expanded size must be consistently present, bounded by the integrity region, and expand to the declared size. At least one core is required, and the language block must begin after the final core.

## Size-prefixed data block

```text
Offset  Size  Field
------  ----  --------------------------------------------------------------
+0x00      4  Size, int32
              0 = empty block
             <0 = stored bytes; byte count is -Size and data starts at +0x04
             >0 = expanded byte count; CompressedSize follows
+0x04      4  CompressedSize, int32, only when Size > 0
+0x08      n  raw-LZMA bytes using package-level properties
```

The decoder receives the next structural boundary and a maximum expanded size. A positive block must produce exactly `Size` bytes. A stored block cannot negate `Int32.MinValue`, exceed the caller limit, or consume the next record.

## File catalog

The CRLF-delimited UTF-8 filename block ends no more than a small reserved gap before the file table. The parser selects the uniquely nearest valid name block. Identity-carried readme, license, and support-DLL aliases are integrated before ordinary names; duplicate architecture-specific support-DLL names remain distinct physical entries.

Current tables serialize six parallel columns per entry: absolute offset, expanded size, stored size, OLE Automation timestamp, attributes, and CRC32. The first five values use 64 bits and CRC32 uses 32 bits, producing `44 * FileCount` bytes. Earlier locator media may keep auxiliary payloads before `PackageDataOffset`; those offsets are reconstructed only from a unique stored-size and expanded-size record matching the table.

Equal stored and expanded sizes select direct copying. Other file entries are raw-LZMA. Extraction verifies the declared expanded size and CRC32 before preserving output.

## Classic 2.5 overlay

```text
PE raw-image end
+-- BZh9...                                  BZip2 runtime member
+-- FF FF FF FF                              member boundary
+-- Length:u32 + zlib language record
+-- Length:u32 + zlib Windows-1252 identity record
+-- UI/configuration, auxiliary, and component records
+-- Length:u32 + zlib CRLF filename list
+-- parallel classic catalog columns
+-- recursive destination forests and item streams
+-- registry and file-association records
+-- unresolved prerequisite/completion records
+-- contiguous Length:u32 + zlib payload records
+-- optional zero alignment
`-- optional certificate table
```

The BZip2 boundary is accepted only when the next record begins with a valid RFC 1950 header and the member expands within 64 MiB to a valid PE. The parser walks backward from physical EOF or a validated pre-certificate ending to find a contiguous zlib payload chain, then binds the nearest safe filename record with exactly one name per ordinary payload.

Classic catalog entries contain parallel offset, observed, expanded-size, and CRC columns. Auxiliary icon, readme, license, and support-DLL records use `0xFFFFFFFF` offsets and are found by unique expanded-size and CRC pairs. Ordinary offsets must exactly match the recovered trailing record chain.

## Classic destination and behavior records

A destination forest follows each component. A byte below `0xFE` is a Windows-1252 folder-name length. `0xFE` attaches a length-prefixed zlib item stream to the current folder and closes its node list; `0xFF` closes a list without an item stream. Nested names append to the parent destination.

Flat file items use an `0x80`-family opcode and a 16-bit file index. `0x40` records describe shortcuts with a target index, three byte-length strings, flags, and a reference. `0x20` records describe URL shortcuts. Registry records begin with opcode `0x01` and a NUL-terminated `HKEY_*` root; implemented branch opcodes cover child keys, selected value names, strings, DWORD values, separators, and branch termination. Classic associations use form-feed text plus x86 icon, executable, and parameter records.

## Signed envelope

The certificate table is outside DeployMaster's logical package. Detection and expansion use the PE security directory only to validate the aligned suffix. Certificate bytes are never scanned as metadata or payload records.
