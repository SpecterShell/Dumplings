# InstallShield outer-container internals

[Back to InstallShield internals](overview.md).

This page covers storage and delivery layers. It does not decide which nested package owns ARP, whether InstallScript is silent-capable, or which builder release created the media. Those decisions happen after extraction.

## Binary structure

Classic InstallShield 3 media uses a footer catalog rather than `ISc(`. A PE self-extractor can store archive members in named `FILE` resources; the first four resource bytes belong to the launcher and are excluded before footer parsing. InstallShield also distributed `setup32.exe` as a reusable engine with no package resources or footer. That engine is not an empty package: its project files and payload archives were distributed separately as Setup30 media.

```text
Setup30 archive (.Z, _SETUP.LIB, Setup.pkg, or numbered part)
+-- TTCOMP member streams at catalog DataOffset values
`-- footer records within the final 2048 bytes
    +-- -0x1B  uint32 LE ExpandedSize
    +-- -0x17  uint32 LE CompressedSize
    +-- -0x13  uint32 LE DataOffset
    +-- -0x0F  uint32 LE CRC-or-stamp (preserved, not asserted)
    +-- -0x0B  uint32 LE FlagsA
    +-- -0x07  uint32 LE FlagsB
    +-- -0x03  uint16 LE DirectoryIndex
    +-- -0x01  uint8 NameLength
    `-- +0x00  NUL-terminated ASCII member name

TTCOMP member
+-- 0x00 uint8 LiteralMode (0=binary, 1=ASCII)
+-- 0x01 uint8 DictionaryBits (4, 5, or 6)
`-- 0x02 variable PKWARE-implode bitstream
```

The package archive, compiled `setup.ins`, and reusable engine are independent layers. A media set can contain the first two while using a shared copy of the third.

InstallShield has several incompatible container generations. The PE launcher, overlay stream, proprietary media, and external sibling files remain separate physical layers. Older Basic MSI media can keep `Setup.ini` and the MSI beside `setup.exe`; that sibling relationship is configuration, not an embedded overlay.

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
`-- optional external media (separate physical files)
    +-- Setup.ini
    |   +-- [Startup] EngineVersion / ProductGUID
    |   +-- [Startup] PackageName -> package section
    |   `-- [PackageName] Location -> exact media-relative MSI path
    +-- setup.inx / setup.ins -> compiled InstallScript
    +-- dataN.hdr -> ISc( cabinet catalog
    +-- dataN.cab -> split payload volumes
    `-- exact configured sibling MSI, when present
```

PackageForTheWeb is a distinct outer generation. Its Microsoft Cabinet 1.3 payload occupies the tail of the launcher and declares a size that ends at EOF. An incidental `MSCF` string elsewhere in a PE is not a PackageForTheWeb container.

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

## Offset bases and ownership

The container readers use several coordinate systems. Confusing them is a common source of apparently valid out-of-range records.

| Structure | Offset base |
| --- | --- |
| PE overlay start | Absolute file offset returned by the shared PE reader. |
| PackageForTheWeb fields | Relative to the embedded `MSCF` cabinet candidate, except the candidate's absolute `Offset`. |
| Legacy and stream attributes | Relative to the decoded overlay stream or current record, as shown in the layout. |
| Adjacent payload bytes | Current record cursor immediately after the complete attribute and file name. |
| Setup30 catalog `DataOffset` | Relative to the beginning of the current archive part. |
| `Setup.ini` package `Location` | Relative to the media root containing the accepted `Setup.ini`. |

The PE certificate table is not an overlay. The shared PE layout accounts for the certificate range before returning the true overlay boundary.

## Container-family discrimination

The physical layers can be distinguished in this order without assigning package semantics prematurely:

1. Read the PE layout and overlay offset.
2. Probe for a complete PackageForTheWeb cabinet in the bounded overlay.
3. Attempt the structured InstallShield overlay readers, including an optional NB10 prefix.
4. Recognize a classic Setup30 package only when its footer and member ranges validate.
5. Treat a payload-free executable as a launcher only when direct external-media sidecars establish the relationship.
6. Keep the reusable InstallShield 3 engine separate from package media.

The tests are intentionally narrow. A shared `InstallShield` string, PE version resource, or archive marker does not make unrelated bytes one of these formats.

## Overlay transforms

Encoded overlay records store flags and lengths separately from payload bytes. The InstallShield block transform applies only to the declared range. Some records then contain zlib-compressed data. Bytes outside that range belong to other records or layers and must not be transformed with it.

ISx historically calls this route `extract_encrypted_files`, but the implemented operation is a deterministic nibble-swap, XOR, and complement transform keyed by the record name or stream seed. It does not authenticate a user password. Dumplings implements the transform as a bounded streaming view and independently probes the transformed prefix before applying zlib decompression.

Plain ANSI and UTF-16 records place a terminated name before the following size field and adjacent payload. A plausible name without a valid adjacent payload range is not a complete record.

## PackageForTheWeb validation

The `MSCF` search is restricted to the PE overlay. A candidate is accepted only when all of these conditions hold:

- The cabinet header and fixed fields fit inside the source.
- The version bytes are Cabinet 1.3.
- The declared cabinet length is nonzero and ends at installer EOF.
- Previous-cabinet and next-cabinet flags are clear.
- Folder and file counts fit the declared cabinet structures.
- Folder, CFDATA, and CFFILE ranges remain inside the declared cabinet.

This distinguishes PackageForTheWeb from a PE that merely contains the text `MSCF` or bundles a cabinet as an unrelated payload.

PackageForTheWeb configuration separates the outer self-extractor from the nested launcher and final payload. A configured nested command line belongs to its recorded stage; it is not automatically a valid switch for the outer executable.

## External-media acceptance

Some InstallShield launchers contain no application payload. Their media is a set of sibling files, which may also be distributed across disk directories. The launcher and sibling media belong together when:

- The launcher has trusted InstallShield runtime identity.
- Exactly one direct, bounded `Setup.ini` is available at the media root.
- At least one direct compiled script, structurally valid `data*.hdr`, or exact configured package proves that the sidecars belong to the launcher.
- Every referenced path resolves under the media root.

InstallShield resolves canonical sidecars and configured locations relative to the media root. A recursive search of the surrounding download directory does not reproduce this behavior and can select unrelated files.

## Exact MSI selection

InstallShield media may contain product, prerequisite, language, and architecture-specific MSIs. Filename enumeration is not execution evidence.

The selection chain is:

```text
Setup.ini [Startup] PackageName
  -> section named by PackageName
  -> Location value
  -> normalized media-relative path
  -> exact extracted or external sibling MSI
```

An external sibling MSI is selected from the exact configured location. If that path is missing, choosing another `*.msi` by architecture, name, or catalog order does not match InstallShield's launch behavior.

## Extraction semantics

Each catalog entry owns a declared byte range, transform flags, compression state, and output name. Extraction applies those operations to that entry only. Duplicate names can exist in different media directories or language variants, so flattening the catalog can lose information or overwrite a payload.

## Identity boundaries

The container identifies storage and launch relationships. Basic MSI, InstallScript MSI, InstallScript-only, and Advanced UI identity belongs to the selected nested package or runtime model, not to the overlay header itself.

Container metadata can establish extracted paths, a launch chain, project defaults from `Setup.ini`, and candidate nested payloads. It does not by itself establish a visible ProductCode. That value comes from the selected MSI, the Advanced UI suite, or InstallScript registration behavior.

## Validation invariants

Header counts, name lengths, file lengths, next-record positions, transformed output, and destination paths must remain inside their containing structures. A shared InstallShield marker does not prove a specific variant.

An incomplete external-media download can contain a valid launcher while lacking the package sidecars needed to reconstruct installation behavior.

To localize a malformed container, inspect these values in order:

1. PE overlay offset and source length.
2. Candidate absolute offset and declared container length.
3. Header format and record count.
4. Per-record name, flags, payload length, and next cursor.
5. Decoded compression prefix and expected expanded length.
6. Destination path and duplicate-name relationship.

A failure at step 2 concerns container framing. A failure at step 5 concerns the entry transform or compression profile. They are different format failures.
