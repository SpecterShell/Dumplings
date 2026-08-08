# MSI CFB and database internals

[Back to MSI and WiX parser internals](overview.md).

## Binary structure

```text
CFB document
+-- 512-byte CFB header
|   +-- D0 CF 11 E0 A1 B1 1A E1   signature
|   +-- sector shifts and FAT roots
|   `-- DIFAT entries
+-- FAT / DIFAT / mini-FAT sectors
+-- directory stream
|   `-- Root Entry + storage/stream records (UTF-16LE names)
`-- Windows Installer streams
    +-- _StringPool / _StringData
    +-- SummaryInformation
    +-- encoded table streams       Property, Directory, File, Component, ...
    `-- embedded Binary/Icon/cabinet streams
```

```text
CFB header
Offset  Size  Field
------  ----  -------------------------------------------------
0x00    8     Magic: D0 CF 11 E0 A1 B1 1A E1
0x08    16    CLSID (normally zero in header)
0x18    2     Minor version, uint16 LE
0x1A    2     Major version, uint16 LE
0x1C    2     Byte order: FE FF (little-endian)
0x1E    2     SectorShift, uint16 LE
0x20    2     MiniSectorShift, uint16 LE
...     ...   FAT, directory, mini-stream, and DIFAT locations/counts
```

The root directory CLSID distinguishes MSI-family documents: `{000C1084-0000-0000-C000-000000000046}` for installer databases, `{000C1086-0000-0000-C000-000000000046}` for patches, and `{000C1082-0000-0000-C000-000000000046}` for transforms.

## Parsing behavior

Dumplings queries decoded database tables through Windows Installer APIs and DTF. Resolve string-table references before interpreting `Property`, `Directory`, `File`, `Component`, `Registry`, `CustomAction`, and sequence records.

## Metadata projection

WiX, Advanced Installer, and InstallShield are authoring systems over the same MSI storage. Builder classification, architecture, product identity, upgrade identity, install location, and visible ARP behavior come from table and property evidence rather than a different outer magic.

## Limits and gaps

Validate CFB sector geometry, chain termination, directory records, stream sizes, string indexes, table schemas, and embedded stream ranges. Route MSP and MST CLSIDs separately; do not treat them as installable MSI packages.
