# InstallShield outer-container internals

[Back to InstallShield parser internals](overview.md).

## Binary structure

InstallShield has several incompatible generations. Dumplings first separates the PE launcher from its overlay, then decodes only the supported stream/catalog variants. A nested MSI is selected from decoded metadata rather than from a recursive `*.msi` wildcard. Older Basic MSI media can instead keep `Setup.ini` and the MSI beside `setup.exe`; that sibling relationship is metadata, not an embedded overlay.

```text
PE setup launcher
+-- overlay
|   +-- PackageForTheWeb preamble
|   |   `-- Microsoft Cabinet extending exactly to end of file
|   |       +-- Setup.exe / Setup.ini / setup.inx
|   |       `-- data*.cab and project media
|   +-- optional "NB10" debug prefix
|   +-- encoded stream form
|   |   +-- "InstallShield" or "ISSetupStream" header (46 bytes)
|   |   +-- repeated old (0x138-byte) or stream attributes
|   |   `-- transformed/zlib payload ranges
|   `-- plain form
|       +-- ANSI or UTF-16 record headers
|       `-- adjacent bounded file ranges
`-- optional legacy external media
    +-- Setup.ini
    |   +-- [Startup] PackageName -> package section
    |   `-- [PackageName] Location -> exact media-relative MSI path
    `-- selected sibling MSI
```

PackageForTheWeb is a distinct outer generation. Dumplings searches only the bounded PE overlay, requires a complete Cabinet 1.3 header whose declared size ends at installer EOF, and then uses its bounded cabinet API to enumerate or extract only selected entries. An incidental `MSCF` string is not sufficient.

```text
Embedded PackageForTheWeb Cabinet (absolute installer offsets)
Offset  Size  Field
------  ----  --------------------------------------------------
+0x00      4  Magic: 4D 53 43 46 ("MSCF")
+0x08      4  Cabinet length, uint32 LE; candidate + length = EOF
+0x10      4  CFFILE table offset, uint32 LE
+0x18      2  Version 1.3 (minor byte, major byte)
+0x1A      2  Folder count, uint16 LE
+0x1C      2  File count, uint16 LE; bounded to 4096
+0x1E      2  Flags; previous/next-cabinet bits must be clear
...           CFFOLDER and compressed CFDATA blocks
...           CFFILE catalog, including media-root-relative names
```

```text
Decoded stream header (record-relative)
Offset  Size      Field
------  --------  ---------------------------------------------
0x00    14        NUL-padded ASCII "InstallShield"/"ISSetupStream"
0x0E    2         FileCount, uint16 LE
0x10    4         AttributeType, uint32 LE (supported: 0..4)
0x14    26        Reserved/observed header bytes

Legacy attribute (0x138 bytes)
0x00    260       NUL-terminated file name bytes
0x104   4         EncodedFlags, uint32 LE
0x10C   4         FileLength, uint32 LE
0x118   2         Unicode-launcher evidence, uint16 LE
0x138   FileLen   adjacent encoded file payload

ISSetupStream attribute
0x00    4         FileNameLength, uint32 LE
0x04    4         EncodedFlags, uint32 LE
0x0A    4         FileLength, uint32 LE
0x16    2         Unicode-launcher evidence, uint16 LE
0x18    24        optional extra record when AttributeType == 4
...     N         UTF-16LE file name
...     FileLen   adjacent encoded file payload
```

## Parsing behavior

Apply the payload transform only to the declared file range and require a valid decoded zlib prefix before decompression. Select sibling or embedded MSI files from `Setup.ini` and catalog metadata rather than a recursive wildcard.

## Metadata projection

Use the decoded catalog and nested payload evidence to classify Basic MSI, InstallScript MSI, InstallScript-only, and Advanced UI media. Preserve the outer container, selected payload, and visible ARP owner as separate evidence.

## Limits and gaps

Bound header count, name length, file length, next-record position, decoded output, and safe destination paths. A shared InstallShield marker does not prove a specific variant.
