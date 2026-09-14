# Paquet Builder binary format

All integer fields described here are little-endian unless stated otherwise. Offsets are absolute file offsets unless a table labels them relative to a container.

## Common PE layer

```text
DOS header and PE headers
+-- section table
+-- RT_VERSION and RT_MANIFEST
+-- generation-specific RT_RCDATA
`-- overlay at max(SizeOfHeaders, section.RawOffset + section.RawSize)
```

The parser treats the certificate table and overlay as file ranges rather than mapped virtual addresses. PE identity must agree with a supported package structure before a Paquet route is accepted.

## Classic envelope

```text
Overlay-relative  Size  Meaning
----------------  ----  ------------------------------------------------------------
0x00                 1  EnvelopeVersion = 3
0x01                11  Observed prefix
0x0C                 4  PackedBlockSize, including the 12-byte GPacker header
0x10                 4  Observed trailer word
0x14                 4  Magic 40 47 44 47 ("@GDG")
0x18                 4  Uncompressed control size
0x1C                 4  Decoded control CRC32
0x20                 n  GPacker/LZHUF bytes, nominal n = PackedBlockSize - 12
0x14+PackedBlockSize  ... ZIP package
```

The GPacker decoder has a 4096-byte LZSS ring initialized with spaces, a 60-byte lookahead, threshold 2, 314 literal/length symbols, a 627-node adaptive Huffman tree, root node 626, and reconstruction at frequency `0x8000`. The historical bit reader may prefetch one byte from the following ZIP, so the declared package boundary remains authoritative.

## Packed Classic controller

The package ZIP contains one `SETUP*.EXE` and one `SETUP*.GAF`. The setup controller's overlay begins with `67 77 32 73 63 1C` (`gw2sc`, `0x1C`) and then repeats descriptors followed by RFC 1950 zlib members.

```text
Record-relative  Size  Meaning
---------------  ----  --------------------------------------------------
0x00                4  Observed tag
0x04                4  Compressed zlib-member size
0x08                4  Uncompressed record size
0x0C                4  Adler-32, repeated by the zlib trailer
0x10                n  Complete zlib member
```

The first expanded record is 494 bytes. Seven counts at offsets `0x1C0` through `0x1D8` identify directory, file, shortcut, unknown, registry, auxiliary-path, and execution records. License and description text sizes follow at `0x1DC` and `0x1E0`. Fixed Windows-1252 short-string fields at offsets 0, 64, 128, 192, 256, 320, and 384 contain setup title, application name, application title, copyright, product name, display version, and uninstall display name.

File records are 95 bytes: a 65-byte destination short string, eight observed timestamp bytes, seven observed attribute bytes, uncompressed and compressed uint32 sizes, Adler-32, and three observed flag bytes. Shortcut records are 356 bytes. Registry records are 438 bytes and contain a Win32 root-handle value, 128-byte key buffer, 48-byte value-name buffer, 256-byte data buffer, and two observed flag bytes. Execution records are 193 bytes with three 64-byte short strings followed by one observed flag byte.

## Classic GAF

```text
GAF file
+-- 0x00  6  47 41 46 6E 64 1C ("GAFnd", 0x1C)
+-- 0x06  4  complete GAF length
`-- one member per ordered controller file record
    +-- 4  47 41 46 1C ("GAF", 0x1C)
    `-- n  complete zlib member
```

Each member's compressed size, expanded size, and Adler-32 come from the matching controller file record. The GAF must end exactly after the final declared member.

## ISFX descriptor

```text
ISFX-relative  Size  Meaning
-------------  ----  -------------------------------------------------------
0x00              1  DescriptorVersion = 3
0x01              3  Magic 47 44 47 ("GDG")
0x04              4  Observed field
0x08              4  absolute PackageOffset
0x0C              4  absolute PayloadOffset
0x10              8  reserved, zero in verified media
```

Version 2.7 requires `MSCF` at `PayloadOffset` and uses the cabinet header's `cbCabinet` as the exact payload bound. The encoded configuration occupies `[PackageOffset, PayloadOffset)`.

## Package transform and named resources

The 2.7, 2.8, and 2.9 package configurations use the same byte transform before their generation-specific compression frame.

```text
state = 0xDE27
for each ciphertext byte c:
  plaintext = c XOR (state >> 8)
  state = ((state + c) * 0x75BA + 0xC78A) AND 0xFFFF
```

All three decoders produce the same bounded named-resource table.

```text
Offset  Size      Meaning
------  --------  -------------------------------------------------
0x00       8      marker 01 02 03 04 05 06 07 08
0x08       4      resource count
...        2      name length
...        n      Windows-1252 name
...        4      content length
...        m      content bytes
```

Names must be nonempty, unique case-insensitively, and free of null characters. The final resource must end exactly at the decoded buffer boundary. `GINFOS` is the package program; `GFICHS`, `GSTRINGS`, and `GTABLE` are exposed as text resources.

## `@GDG` LZHUF frame

```text
Configuration-relative  Size  Meaning
----------------------  ----  ----------------------------------
0x00                       4  40 47 44 47 ("@GDG")
0x04                       4  expanded resource-table size
0x08                       4  expanded CRC32
0x0C                       n  GPacker/LZHUF stream
```

The 2.7 decoder accepts at most one virtual zero byte at input EOF because that is how the historical reader completes its final bit request. The decoded size and CRC32 must both match.

## `AP32` frame

```text
Configuration-relative  Size  Meaning
----------------------  ----  ----------------------------------
0x00                       4  41 50 33 32 ("AP32")
0x04                       4  header size, exactly 24
0x08                       4  compressed size
0x0C                       4  compressed CRC32
0x10                       4  expanded size
0x14                       4  expanded CRC32
0x18                       n  aPLib token stream
```

The independent bounded decoder implements literal, long or reused match, short match or end marker, and tiny-distance tokens. It rejects missing termination, input overrun, invalid distances, integer overflow, output overrun, compressed-byte mismatch, and either CRC mismatch before the resource table is parsed.

## Outer 2.9 `GP` runtime

```text
ENG-relative  Size  Meaning
------------  ----  --------------------------------------------------------
0x00             2  47 50 ("GP")
0x02             4  expanded runtime PE size
0x06             4  encoded package-configuration size
0x0A             4  observed field
0x0E             5  raw-LZMA properties
0x13             n  raw-LZMA runtime stream
0x13+n           m  transformed inner GP package configuration
```

The runtime stream length is `ENG.Size - 19 - m`. Its output must have the declared length, start with `MZ`, and parse as a PE image.

## Inner 2.9 `GP` configuration

```text
Decoded-tail-relative  Size  Meaning
---------------------  ----  -----------------------------------------------
0x00                      2  47 50 ("GP")
0x02                      4  expanded named-resource-table size
0x06                      4  observed field; not assigned checksum semantics
0x0A                      5  raw-LZMA properties
0x0F                      n  raw-LZMA stream with known output size
```

The verified 2.9.1, 2.9.5, and 2.9.6 streams leave four final range-coder bytes unread after the declared output is complete. The parser allows at most eight such bytes, records the exact count, and validates the complete resource table. The observed header field and unread bytes do not equal CRC32 values over the tested encoded, compressed, or expanded ranges, so they remain unlabeled.

## UPX-packed Split3 launcher

Archived 3.0 and 3.2 launchers compress the mapped native image before the ordinary Split3 archives. The parser accepts the observed Win32 PE/LZMA route only; it does not execute the decompressor stub or implement a generic UPX unpacker.

```text
File-relative  Size  Meaning
-------------  ----  --------------------------------------------------------
header+0x00       4  55 50 58 21 ("UPX!")
header+0x04       1  pack-header version, observed 13
header+0x05       1  executable format, 9 for Win32 PE
header+0x06       1  compression method, 14 for UPX-style LZMA
header+0x07       1  compression level
header+0x08       4  expanded Adler-32, little-endian
header+0x0C       4  compressed Adler-32, little-endian
header+0x10       4  expanded image size
header+0x14       4  compressed image size
header+0x18       4  reconstructed file-backed PE size
header+0x1C       1  executable filter, observed 0x26
header+0x1D       1  filter marker byte
header+0x1E       1  filter state
header+0x1F       1  sum(bytes 0x04..0x1E) modulo 251
header+0x20       2  UPX LZMA properties: pb, lp, and lc
header+0x22       n  raw LZMA range stream
```

The final four expanded bytes point to a saved `PE\0\0` header. The saved section table maps virtual section bytes from expanded offset `Section.VirtualAddress - FirstSection.VirtualAddress` to each original file offset. Filter `0x26` converts marked big-endian `E8` and `E9` targets back to little-endian relative operands. Relocatable images append a delta-coded fixup stream: one-byte deltas below `0xF0`, three-byte deltas using the low nibble plus a little-endian `uint16`, a seven-byte extended form when that delta is zero, and a zero terminator. Each declared fixup converts a big-endian relative pointer to `ImageBase + FirstSection.VirtualAddress + relative`. These transformations restore the delay-import/IAT evidence required by the ordinary `PBCore.SetVar` scanner.

## Split 7z archives

Each overlay archive is validated from its 32-byte 7z start header, CRC, next-header offset, next-header size, and complete catalog. Runtime archives contain `pbfprop.dat` or `PBCore*.dll`; payload archives do not. `pbfprop.dat` uses repeated five-line records containing path, two observed fields, component-variable name, and decimal flags. `pblng.dat` repeats `[PBLang]`, language name, and LCID. `pbdlg.dat` contains bracketed dialog identifiers. `pbremove.dat` is an `MZ` uninstaller template in verified media.
