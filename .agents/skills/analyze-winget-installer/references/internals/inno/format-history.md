# Inno Setup format history and editions

Inno Setup's file format evolved incrementally. The setup-data signature identifies a serialized structure generation, not just a marketing release. Loader placement, metadata framing, record fields, payload compression, checksums, and executable transforms changed on separate schedules.

## How to read a structure identity

The first 64 bytes of setup-0 contain a NUL-padded ASCII identity such as:

```text
Inno Setup Setup Data (5.6.1) (u)
Inno Setup Setup Data (7.0.0.3)
My Inno Setup Extensions Setup Data (3.0.6.1)
```

The numeric portion is the internal structure version. It can differ from the compiler's product version and can remain unchanged across releases. Historical Unicode builds commonly add `(u)`. Third-party variants can alter the prefix or append another edition marker.

The identity determines a coordinated set of layouts. It should not be reduced to a decimal threshold because two adjacent identities can differ in only one record family, and ANSI/Unicode editions of the same number can serialize strings differently.

## Major eras

| Era | Loader/data characteristics | Notable model changes |
| --- | --- | --- |
| 1.3.21 to 1.3.25 | fixed legacy loader table, zlib metadata, Adler32 payload records | small header, ten entry counts, minimal file records |
| 2.0.x | legacy loader, zlib and later BZip2 capability | components and richer file selection appear |
| 3.0.x | legacy loader revisions | broader header and entry records; My Inno Setup Extensions has a separate identity |
| 4.0.0 to 4.0.8 | legacy loader S04/S05, legacy zlib metadata | official structures add compiled Pascal Script; languages and more condition fields mature |
| 4.0.9 onward | chunk-framed setup metadata | independent compressed blocks replace the legacy metadata stream |
| 4.1.x | loader S06/S07, more conditions and permissions | LZMA becomes available late in this line |
| 4.2 through early 5.x | modern count set, MD5 payload locations | richer callbacks, uninstall, architecture, and UI fields |
| 5.1.5 onward | PE `RCDATA #11111` offset table v1 | loader discovery moves into a normal PE resource |
| 5.2.5 onward | ANSI and Unicode structure lines coexist | Unicode strings and ANSI byte fields must be distinguished |
| 5.3.9 onward | SHA-1 locations, LZMA2, new call transform | stronger hashes and current-style executable filtering |
| 5.5/5.6 | late ANSI/Unicode records | ResTools variants use distinct layouts for selected versions |
| 6.0 through 6.4 | official builds are Unicode | architecture expressions, UI, signing, and runtime records continue evolving |
| 6.5 | offset table v2 and signed 64-bit offsets | structures can address installers beyond 4 GiB safely |
| 6.7 | 64-bit compressed-block sizes | setup metadata blocks move beyond 32-bit stored-size framing |
| 7.0 | structure ID `7.0.0.3` | current metadata records and encryption framing |

This table is a map, not a substitute for the exact descriptor associated with one `SetupID`.

## Loader generations

Early installers use a fixed marker near absolute offset `0x30` and one of several table layouts. The route names conventionally used for these layouts are S02, S04, S05, S06, and S07. Changes include added compressed setup-engine location, size, integrity, and setup-data offsets.

Later installers store `TSetupLdrOffsetTable` in PE resource `RT_RCDATA/#11111`:

- version 1 uses 32-bit total-size and offset fields;
- version 2 uses 64-bit total-size and offset fields and retains a CRC over the table prefix.

The legacy and resource routes are container differences. They do not by themselves define record layout, payload checksum, or character mode.

## Metadata framing generations

### Legacy zlib stream

The earliest setup header and tables are carried in a legacy zlib-framed stream. The exact framing includes historical integrity and size fields. Record counts and strings are read according to the selected structure identity.

### 32-bit chunked blocks

Beginning with the 4.0.9 structure line, setup metadata uses independent compressed blocks with a 32-bit stored-size header. Blocks are internally split into bounded CRC-framed chunks. The setup-header/table block and file-location block are separate streams.

### 64-bit chunked blocks

The 6.7 structure line changes the outer stored-size field to a signed 64-bit value. Chunk integrity and decompression semantics remain separately selected. A reader that assumes all post-4.0.9 blocks begin with `uint32` will misalign 6.7 and 7.x data.

## Header count growth

The number of entry arrays in the header grew as sections were added:

| Count layout | First represented structures | Added families |
| --- | --- | --- |
| legacy 10 | 1.3.x | core files, directories, icons, INI, registry, delete, run data |
| components 13 | 2.0.7 | types, components, and tasks |
| language 14 | 4.0.0 | languages and related localization records |
| permissions 15 | 4.1.0 | permission records |
| modern 16 | 4.2.1 | custom messages and the long-lived modern section set |
| signature 17 | 6.5 | ISSig key records |

Counts are bounds-sensitive. They determine how many variable-size records follow the setup header and in what order.

## File-entry growth

`TSetupFileEntry` began with source/destination and flags, then gained condition selectors and hooks over time:

| Layout family | String fields represented |
| --- | --- |
| legacy | source, destination name, font name |
| components | component/task selectors join the file record |
| check | `Check` expression is added |
| languages | language selector is added |
| hooks | `BeforeInstall` and `AfterInstall` are added |
| assembly | strong-name/assembly-related metadata is added |
| download | external-source/download metadata is added in current lines |

Some strings remain ANSI byte fields even in Unicode structures when they contain hashes, bytecode, or data with a format-defined encoding. Character mode cannot be applied blindly to every variable-length field.

## Payload checksum history

File-location records changed their digest algorithm independently of metadata compression:

| Structure range | Digest family |
| --- | --- |
| 1.3.21 through 4.0.0 | Adler32 |
| 4.0.1 through 4.1.8 | CRC32 |
| 4.2.0 through 5.3.8 | MD5 |
| 5.3.9 through 6.3 | SHA-1 |
| 6.4 onward | SHA-256 |

The digest verifies the logical extracted file data described by a location record. Chunk framing can carry its own CRC in addition to the location digest.

## Compression history

Supported payload compression expanded over time:

```text
1.x/early 2.x     Zlib
2.0.17+           Zlib, BZip2
4.1.5+            Zlib, BZip2, LZMA
4.2.5+            Stored, Zlib, BZip2, LZMA
5.3.9+            Stored, Zlib, BZip2, LZMA, LZMA2
```

Compiler settings select one supported method for a build. Solid compression can place many logical files in one stream. A file location therefore refers to a slice of a decompressed stream rather than necessarily owning a standalone compressed member.

## Executable call transforms

Inno can transform relative `CALL` instructions before compression to improve compression ratio, then reverse the transform while extracting. Three broad generations occur:

- the legacy stream transform;
- a relative 24-bit transform used from the 5.2 line;
- a revised relative 24-bit transform used from the 5.3.9 line onward.

The transform applies only when the file record and compiler determine it is appropriate. It is part of payload reconstruction, not PE loading.

## ANSI and Unicode lines

Official Inno historically shipped ANSI and Unicode compilers in parallel. Unicode became the official line in Inno 6.

Differences extend beyond string decoding:

- setup-data identity commonly carries `(u)` in historical Unicode versions;
- serialized `String` fields use the edition's character mode;
- explicitly declared `AnsiString` fields remain byte strings;
- loader and setup-engine binaries differ;
- compiled Pascal Script and selected hashes/data retain their format-defined byte representation;
- record schemas can diverge between ANSI and Unicode variants at the same nominal structure version.

BOM guessing is inappropriate for setup-data records. The selected structure identity defines encoding.

## My Inno Setup Extensions

My Inno Setup Extensions identifies itself with:

```text
My Inno Setup Extensions Setup Data (3.0.6.1)
```

It is an ANSI derivative with its own record route. Its 3.0.6.1 structure includes compiled Pascal Script before official Inno added `CompiledCodeText` in 4.0. The distinct prefix is structural evidence; treating it as ordinary official 3.0.6 can shift later fields even when many records resemble upstream Inno.

## ResTools editions

ResTools-derived builds are observed around 5.4.2 Unicode and 5.5.0 ANSI/Unicode structures. Their setup identity can resemble official Inno while package metadata and record deltas establish a separate edition route.

Edition evidence must come from bounded package/version information and a compatible full layout. A product-name string anywhere in the executable is not enough to reclassify the format.

## ISX

InstallShield Express extensions for Inno, commonly called ISX in historical tools, are a separate derivative. They can be identified, but innounp does not provide a trustworthy complete record specification for supported decoding. Identification and structural support are separate claims.

An identified ISX installer should retain its edition evidence and report unsupported records rather than falling through to a nearby official Inno schema.

## Unknown future structures

A future `SetupID` can resemble the latest known version while adding fields to the middle of a record. Prefix parsing would then produce plausible but shifted values.

A conservative compatibility attempt is valid only when all of these remain consistent:

- edition and character mode;
- loader family;
- count values and limits;
- exact record consumption;
- offsets and stream boundaries;
- compressed chunk integrity;
- location digests and payload boundaries.

Failure of any invariant means the layout is unknown. Recovering a few readable strings is not evidence that the structure is compatible.

## Sources for historical layouts

The official repository describes the current structure and retains source history. Official archived builders provide producer-grounded samples. InnoUnpacker/innounp's `StructList` records the practical compatibility identities needed for old installers.

Historical validation should use at least one installer built by the relevant producer generation. Version resources and filenames alone cannot prove that a structure transition was exercised.

## Source references

- [Official Inno Setup source](https://github.com/jrsoftware/issrc)
- [Official archived releases](https://files.jrsoftware.org/is/)
- [InnoUnpacker/innounp](https://github.com/jrathlev/InnoUnpacker-Windows-GUI)
- [Inno Setup version history](https://jrsoftware.org/files/is6-whatsnew.htm)
