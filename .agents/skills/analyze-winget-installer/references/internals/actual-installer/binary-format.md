# Actual Installer binary format

## Offset conventions

Unless a table says otherwise, file offsets are absolute, CAB multibyte integers are unsigned little-endian, and ZIP fields follow the ZIP specification. A container-relative offset begins at that container's first signature byte. INI values are text and use their own record delimiters rather than fixed-width binary fields.

## Outer PE and logical data region

Every supported setup is a valid Windows PE. The first byte after the mapped PE sections is only the start of the overlay search region. Alignment bytes, runtime-owned records, and signing data can exist around the Actual Installer containers.

```text
absolute file layout

0x00000000  DOS header and PE image
            section raw data
overlay     optional alignment/runtime data
            validated Actual Installer container sequence
logical end optional Authenticode certificate or other bounded trailing data
```

The parser does not define the Actual Installer payload as "all bytes after the PE." It discovers candidate CAB or ZIP ranges, validates each range independently, orders accepted containers by absolute offset, and identifies exactly one metadata container. Bytes inside an accepted range are never rescanned as new top-level containers.

## Microsoft Cabinet route

Actual Installer 3.x through 5.x use ordinary Microsoft Cabinet files concatenated in the executable. Every accepted range starts with `MSCF`; `cbCabinet` supplies its exact physical length.

```text
CFHEADER, relative to CAB start

Offset  Size  Field
------  ----  ----------------------------------------------------
0x00       4  signature 4D 53 43 46, ASCII "MSCF"
0x04       4  reserved
0x08       4  cbCabinet, complete CAB length
0x0C       4  reserved
0x10       4  coffFiles, offset of first CFFILE record
0x14       4  reserved
0x18       1  versionMinor, expected 3
0x19       1  versionMajor, expected 1
0x1A       2  cFolders
0x1C       2  cFiles
0x1E       2  flags
0x20       2  setID
0x22       2  iCabinet
```

The parser requires at least the fixed 36-byte header, a bounded `cbCabinet`, `coffFiles` inside the range, and `cFiles` within the configured entry limit. It reads enough of the CFFILE table to validate entry names and expanded lengths before accepting the container.

```text
CFFILE, relative to one CFFILE record

Offset  Size  Field
------  ----  ----------------------------------------------------
0x00       4  cbFile, expanded file size
0x04       4  uoffFolderStart, uncompressed folder offset
0x08       2  iFolder, folder index or special continuation value
0x0A       2  date, DOS date
0x0C       2  time, DOS time
0x0E       2  attribs; bit 0x80 selects UTF-8 filename decoding
0x10       N  NUL-terminated filename
```

Names without bit `0x80` are decoded with the legacy single-byte route. A missing terminator, empty name, table crossing the cabinet boundary, or entry count above the limit rejects the candidate. Actual decompression is delegated to the shared cabinet layer after the exact range has been materialized.

### Cabinet3 and Cabinet4 ordering

```text
container 0        metadata CAB
                    +-- setup.ini or aisetup.ini
                    `-- language/helper resources
container 1        payload CAB for first ordered [Files] row
container 2        payload CAB for second ordered [Files] row
...
```

Payload identity is positional because payload CAB entry names are not the installed destination. The parser sorts numeric `[Files]` rows, removes the metadata CAB, and pairs each available payload CAB with the corresponding logical row.

### Cabinet5 ordering

```text
container 0..N-1   one-file payload CABs
container N        metadata CAB containing aisetup.ini
```

The same positional pairing applies after removing the last metadata CAB. A logical row without a physical CAB remains unavailable unless another mapped row already supplies the same destination. The parser does not shift later rows or use a metadata helper file to fill the gap.

## ZIP route

Actual Installer 6.x and later append one or more standard ZIP ranges. A self-extracting ZIP cannot be bounded from its first local-header signature alone because local data can contain the same bytes. The parser uses the central directory and end-of-central-directory record to derive each exact archive range.

```text
one embedded ZIP range

+------------------------------+ archive start
| local file headers and data  |
+------------------------------+
| central directory entries    |
+------------------------------+
| 50 4B 05 06 EOCD             |
+------------------------------+ archive end
```

Central-directory offsets are stored relative to the embedded ZIP start, not the containing PE. The shared embedded-ZIP reader rebases them and rejects a range whose local records, central directory, EOCD, counts, or lengths escape the file.

The metadata ZIP is the unique accepted range containing `aisetup.ini`. Other accepted ranges are payload ZIPs. Payload entry names are decimal logical indexes.

```text
[Files]
42=<InstallDir>\bin\Example.dll?11

logical identity       integer 42
physical identity      ZIP entry with leaf name "42"
installed destination  <InstallDir>\bin\Example.dll
```

Archive order is not identity. Multiple payload ZIPs are permitted if decimal indexes remain unique. Duplicate physical indexes require conservative handling; a later duplicate is not silently substituted for the first accepted mapping.

## Metadata container

The metadata container must expose exactly one supported configuration entry.

| Route | Required entry | Required position |
| --- | --- | --- |
| `Cabinet3` | `setup.ini` | first accepted CAB |
| `Cabinet4` | `aisetup.ini` | first accepted CAB |
| `Cabinet5` | `aisetup.ini` | last accepted CAB |
| `Zip6Plus` | `aisetup.ini` | last accepted ZIP |
| `ZipExternalData` | `aisetup.ini` | the only accepted ZIP; compiled `DataFileName` must name companion media |

Metadata archives can also include `*ai.lng` language resources, bitmaps, fonts, icons, uninstaller/updater templates, and runtime helpers. Their presence does not make them installed files.

## Setup EXE + Data route

Published builder behavior archives the configured source directory into a separate 7z file using LZMA and preserves that directory tree below `<InstallDir>`. The setup executable retains the compiled `aisetup.ini` metadata. The parser accepts this as `ZipExternalData` only when a metadata-only ZIP route also declares a nonempty `DataFileName`.

```text
setup.exe                                 companion data file
+-- PE runtime                           +-- 7z signature and streams
`-- metadata ZIP                         +-- source-relative file A
    +-- aisetup.ini                      +-- source-relative directory B
    `-- language/helper entries          `-- file B\C

companion path A     -> <InstallDir>\A
companion path B\C   -> <InstallDir>\B\C
```

The extractor requires an explicit local `-CompanionFile`, validates a literal compiled filename when available, requires a SevenZip archive, and applies the shared entry-count, expansion, traversal, duplicate-path, and collision limits. It does not search parent directories or fetch a URL.

## Logical file records

The `[Files]` section is an ordered dictionary keyed by a non-negative decimal integer. Its value is a delimiter-separated record whose first field is the authored destination.

```text
key = Destination ? Field1 ? Field2 ? ...

key          logical file index
Destination  variable-bearing installed path
Field1...    generation-dependent fields preserved verbatim
```

Observed real media across cabinet and ZIP generations uses bare `?` in `[Files]`. Synthetic and adjacent table grammars can use `*?`; the parser accepts the explicit compound delimiter first and then the bare delimiter on file rows. It exposes all fields plus `RecordValue`, the second field, without assigning one meaning across generations.

In old cabinet media the second field correlates with the physical payload-CAB length. In ZIP media it is a control value. It is not a general expanded-size field.

## Installed-path projection

Destinations rooted at `<InstallDir>` map directly below the extraction root. Other variable roots are isolated so extraction cannot write to host system locations.

```text
<InstallDir>\bin\A.exe       -> bin\A.exe
<System>\A.dll               -> _destinations\System\A.dll
C:\literal\A.dat            -> _destinations\Literal\literal\A.dat
```

The destination mapper normalizes separators, strips a drive prefix only inside the isolated literal namespace, and passes the result through shared safe-path and collision handling. It never expands `%ProgramFiles%`, `%WINDIR%`, or another resolved manifest path into a real host destination.

## Raw extraction

Raw mode exports validated physical ranges rather than installed files.

```text
_actual\container-0000.cab
_actual\container-0001.cab
...

or

_actual\container-0000.zip
_actual\container-0001.zip
...
```

The bytes are copied from the exact absolute offset and length already validated during layout discovery. Raw mode is useful for research and does not imply that every entry is part of installed state.

Metadata-entry mode decompresses selected files from the unique metadata container under `_actual\metadata`. This mode is the safe way to inspect language resources and uninstaller/updater templates without labeling them as installed payloads.

## Structural invariants

The supported format requires all of the following:

- A valid PE image.
- At least one complete accepted CAB sequence or embedded ZIP range.
- Exactly one `setup.ini` or `aisetup.ini` candidate.
- A route-compatible metadata position.
- A parsed `[Setup]` section with a nonempty `AppName`.
- A nonempty numeric `[Files]` table, or a metadata-only route with a nonempty compiled `DataFileName`.
- Bounded and uniquely mapped physical payload records where bytes are available.

An isolated `MSCF`, ZIP signature, `aisetup.ini` string, or "Actual Installer" version resource is insufficient.

## Source references

- [Microsoft Cabinet SDK structures](https://learn.microsoft.com/en-us/previous-versions/bb417343(v=msdn.10))
- [Actual Installer files and folders](https://www.actualinstaller.com/help/files-and-folders.html)
