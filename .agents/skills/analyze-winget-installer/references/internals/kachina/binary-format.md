# Kachina binary format

## Layer map

```text
Kachina executable
+-- DOS header and stub
|   `-- optional !KachinaInstaller! pre-index
+-- PE image
|   +-- host code and resources
|   `-- final mapped section boundary
`-- TLV stream
    +-- configuration JSON
    +-- optional image
    +-- optional compact index
    +-- optional metadata JSON
    +-- one Zstandard record per unique payload hash
    +-- optional HDiff patch records
    `-- optional raw runtime-installer records
```

All TLV offsets in parser results are absolute file offsets. Pre-index offsets are file-relative. Index offsets are relative to the validated TLV record start.

## DOS pre-index

```text
Offset from marker  Size  Field
------------------  ----  ----------------------------------------
0x00                  18  ASCII !KachinaInstaller!
0x12                   4  record-stream base offset, UInt32 BE
0x16                   4  control length 1, UInt32 BE
0x1A                   4  control length 2, UInt32 BE
0x1E                   4  control length 3, UInt32 BE
0x22                   4  control length 4, UInt32 BE
```

The four lengths use early or current field order according to the first control record. Five zero UInt32 values identify config-only media. The marker alone is not detection evidence.

## TLV framing

```text
+----------------------+ record start
| Magic                | 4 bytes: !INS or !IN\0
+----------------------+
| NameLength           | UInt32 BE
+----------------------+
| Name                 | UTF-8, NameLength bytes
+----------------------+
| ContentLength        | UInt64 BE
+----------------------+
| Content              | ContentLength bytes
+----------------------+ next record
```

Legacy media uses `!INS`; indexed media uses `!IN\0`. Name length, content length, record count, and every checked addition are bounded before allocation or seeking. JSON records must decode as strict UTF-8.

## Control record names

| Legacy | Indexed | Content |
| --- | --- | --- |
| `.config.json` | `\0CONFIG` | project configuration JSON |
| `.image` | `\0IMAGE` | optional UI image |
| absent | `\0INDEX` | compact record index |
| `.metadata.json` | `\0META` | release metadata JSON |

## Compact index

The index content is a sequence of name, size, and relative-offset tuples. Each tuple must match a TLV name, absolute data offset, and content size observed by sequential parsing. The parser retains entries omitted from the index because prerequisites can be appended later.

## Payload records

Normal application records are complete Zstandard frames named by the metadata hash. `metadata.hashed` maps each installed path to a hash and decompressed size. Several paths can point to one record. The parser streams decompression, checks the declared size, then validates MD5 or XXH3-128.

Patch record names combine old and new identities and carry HDiff data. They are catalogued but not applied. Runtime package records use package identifiers such as `Microsoft.DotNet.DesktopRuntime.8` and contain raw nested installer bytes rather than Zstandard application files.

## Generated executables

The installed updater and uninstaller consist of the source PE prefix through configuration and optional image records. Their pre-index fields are cleared so the installed tool does not treat itself as embedded installation media. The original installer remains the source; no payload executable is launched during reconstruction.

