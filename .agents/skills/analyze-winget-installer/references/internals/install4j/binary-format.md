# install4j Windows binary format

[Back to install4j internals](overview.md).

All launcher offsets in this page are absolute file offsets unless stated otherwise. Launcher integers are little-endian. ContentCollector integers use Java `DataInput` big-endian order.

## Layered layout

```text
PE image
`-- overlay at the end of mapped PE data
    +-- D5 13 E4 E8 launcher magic
    +-- generation-specific parameter block
    +-- XOR-88 startup-file records
    +-- E8 E4 13 D5 ContentCollector catalog, when used
    `-- contiguous catalog payloads
        `-- stored data or LZMA stream containing a ZIP
```

The PE certificate table is not mapped image data and can be physically placed after other file content. Overlay discovery must use PE layout rules rather than assuming that the last section ends at the last byte before a signature.

## Legacy parameter block

Generations 3 and 4 begin directly after the common magic:

```text
Offset  Size      Field
------  --------  ---------------------------------------------
0x00    4         D5 13 E4 E8
0x04    variable  ANSI parameter map
...     variable  UTF-16LE localized parameter map
...     repeated  startup file length and XOR-88 bytes
```

Each map starts with an `int32 LE` count. Every item contains an `int32 LE` numeric key, an `int32 LE` byte length, and the encoded value. Parameter `2003` lists startup-file names in physical order.

Generation 3 prefixes startup files with `int32 LE` lengths. Generation 4 uses `int64 LE`. Generation 3 normally carries `content.zip` as a startup file; generation 4 moves application content into a catalogued `.000` entry.

## Modern parameter block

Generations 5 through 13 use a bounded, checksummed block:

```text
Offset  Size      Field
------  --------  ---------------------------------------------
0x00    4         D5 13 E4 E8
0x04    4         flags, uint32 LE
0x08    4         expected CRC32, uint32 LE
0x0C    8         DataLength, int64 LE
0x14    variable  ANSI parameter map
...     variable  UTF-16LE localized parameter map
...     4         nested-map count, int32 LE
...     variable  named UTF-16LE parameter maps
...     repeated  int64 LE startup length + XOR-88 bytes
```

CRC32 covers exactly `DataLength` bytes beginning at `0x14`. The startup-file sequence must end at the declared data boundary. A valid modern block can omit the generation marker in parameter `2000`; in that route, a decoded and structurally valid `i4jparams.conf` supplies the builder generation.

## Parameter roles

Only parameters with observed structural roles should be named:

| Parameter | Role |
| --- | --- |
| `2000` | Optional launcher marker used by many builder and vendor media. |
| `2003` | Semicolon-separated startup-file order. |

Other numeric parameters include launcher behavior and localized messages. Their meaning can vary by launcher generation or context, so a reader should retain them as maps until a source-backed use is needed.

## Startup transform

Each startup payload byte is XORed with `0x88`. This is an encoding transform, not encryption. The decoded payload length is unchanged.

```text
stored byte  -- XOR 0x88 -->  decoded byte
```

Typical entries are `i4jruntime.jar`, `i4jparams.conf`, icons, images, and small launcher resources. Their order comes from parameter `2003`, not from scanning the transformed bytes.

## ContentCollector catalog

```text
Offset  Size      Field
------  --------  ---------------------------------------------
0x00    4         E8 E4 13 D5
0x04    4         EntryCount, int32 BE
0x08    repeated  entry descriptors
...     variable  entry payloads in descriptor order
```

Each descriptor contains:

```text
+------------------------+
| NameLength, uint16 BE  |
+------------------------+
| Name, modified UTF-8   |
+------------------------+
| PayloadLength, int64 BE|
+------------------------+
```

Payload offsets are cumulative and begin after the complete descriptor list. Modified UTF-8 differs from ordinary UTF-8 for NUL and supplementary values, so Java `DataInput` rules apply.

## Application archives

Generation 3 `content.zip` becomes a ZIP after the XOR transform. Generation 4 `.000` and modern `0.dat` commonly use the LZMA-alone framing:

```text
Offset  Size  Field
------  ----  --------------------------------------
0x00       1  LZMA properties
0x01       4  dictionary size, uint32 LE
0x05       8  uncompressed size, int64 LE
0x0D     ...  range-coded payload
```

The decoded bytes form a ZIP containing application files, generated launchers, JARs, and possibly a Java runtime. Pack200-era media may contain packed Java members inside that archive. External or downloadable content has no local byte range to recover.

## Integrity and rejection

A structural reader must validate the PE overlay, magic, counts, lengths, startup order, CRC, complete record consumption, catalog names, cumulative ranges, LZMA limits, ZIP paths, and total output before extraction. Marker text or `i4jparams.conf` text outside these records is only candidate evidence.
