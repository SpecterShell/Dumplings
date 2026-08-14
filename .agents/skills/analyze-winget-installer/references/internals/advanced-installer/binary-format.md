# Binary format

## Container map

```text
Advanced Installer setup.exe
+-- PE image
|   +-- native bootstrap code
|   +-- version, icon, and manifest resources
|   `-- optional Authenticode certificate table
+-- payload ranges at absolute offsets
|   +-- bootstrapper INI
|   +-- MSI/MSIX/CAB/DLL/prerequisite entries
|   `-- nested 7z/LZMA archives
+-- variable catalog at TablePointer
|   +-- EmbeddedFileCount * (20-byte v0 or 24-byte v1 record + encoded name)
|   `-- ExternalFileCount * (8-byte sibling record + encoded name)
`-- 74-byte footer at PhysicalFooterOffset
    `-- ADVINSTSFX at +0x40
```

The footer may precede a PE certificate tail. Search backward for the signature, then validate the complete footer and catalog. Do not assume the footer is at EOF.

## Footer v1

All integers are unsigned 32-bit little-endian. Offsets are absolute file offsets.

```text
Offset  Size  Field
------  ----  ----------------------------------------------------
0x00       4  ExternalFileCount
0x04       4  EmbeddedCatalogEnd, also the external table start
0x08       4  EmbeddedFileCount
0x0C       4  StructureVersion, observed classic value 100
0x10       4  PhysicalFooterOffset, must equal the footer start
0x14       4  TablePointer, first catalog record
0x18       4  FileDataStart, beginning of payload storage
0x1C      32  Per-build bootstrapper UUID, ASCII RFC 4122 version-4 GUID in N format
0x3C       4  Flags or unknown bootstrapper state
0x40      10  ASCII "ADVINSTSFX"
```

When `ExternalFileCount` is zero, `EmbeddedCatalogEnd` equals `PhysicalFooterOffset`. External media places exactly `ExternalFileCount` sibling records between those offsets. The two bytes commonly observed after the signature are outside the validated 74-byte structure.

## Catalog record v0

Advanced Installer 6.3 and 6.4 controlled builds establish the historical 20-byte record. The character encoding changed at 6.4 while the integer layout remained the same.

```text
Offset  Size  Field
------  ----  ----------------------------------------------------
0x00       4  SelectorType
0x04       4  SelectorGroup
0x08       4  PayloadSize
0x0C       4  PayloadOffset, absolute
0x10       4  NameLength, bytes on ANSI media and characters on Unicode media
0x14       N  Name bytes, Windows-1252 through 6.3 or UTF-16LE from 6.4
```

This route has no transform word. Its payloads are stored plainly, including nested 7z streams whose catalog names can end in `.msi`.

## Catalog record v1

```text
Offset  Size  Field
------  ----  ----------------------------------------------------
0x00       4  SelectorType
0x04       4  SelectorGroup
0x08       4  TransformFlag
0x0C       4  PayloadSize
0x10       4  PayloadOffset, absolute
0x14       4  NameLength, characters or bytes according to route
0x18       N  Name bytes
```

The 24-byte route is established by a controlled Advanced Installer 8.6 build and later real media. It stores `NameLength * 2` UTF-16LE bytes. Every record must fit before `EmbeddedCatalogEnd`, every embedded payload must finish before `TablePointer`, and parsing must consume the declared embedded catalog exactly.

## External resource record v1

```text
Offset  Size  Field
------  ----  ----------------------------------------------------
0x00       4  Role
0x04       4  NameLength
0x08       N  Sibling filename, Windows-1252 or UTF-16LE by media generation
```

Observed role `3` identifies the bootstrapper INI, `6` identifies the application `FILES.7z`, and `7` identifies the compressed main package. Names resolve relative to the directory containing `setup.exe`; rooted paths and traversal are rejected. The table carries no payload sizes, so extraction obtains each size from the corresponding sibling file. A missing sibling leaves the outer format identifiable but produces incomplete-media warnings.

## Known selector tuples

| Type | Group | Observed role |
| ---: | ---: | --- |
| 0 | 3 | Bootstrapper INI configuration. |
| 1 | 0 | Main MSI stored directly. |
| 1 | 18 | MSIX/AppX payload selected by the mixed platform bootstrapper on supported Windows versions. |
| 3 | 7 | Compressed main archive whose package path is derived from the archive name. |
| 7 or 1 | 1 | Cabinet resources. |
| 5 | 11 or 12 | Bootstrapper DLL resources. |
| 2 | 8 | Decoder helper. |
| 3 or 8 | 6 | Application `FILES.7z`, normally not the MSI database archive. |
| 1 | 13 | Advanced Installer UI resource. |
| 100+ | 4 | Uncompressed embedded prerequisite payload. |
| 100+ | 9 | LZMA-compressed embedded prerequisite payload. |

Selector meanings are runtime classes, not filename extensions. Unknown tuples remain catalog entries and do not acquire guessed semantics.

The 32 characters at footer offset `0x1C` are not a checksum. Rebuilding the same 8.6 project generates a different value, and every controlled and real fixture uses RFC 4122 version and variant bits. The parser exposes the canonical value as `BootstrapperId` and reports the validated `ascii-guid-v4-n` route.

## Transform boundary

Catalog v0 stores payload bytes directly. In catalog v1, `TransformFlag = 0` stores payload bytes directly and `TransformFlag = 2` XORs the first `min(512, PayloadSize)` bytes with `0xFF`; bytes after that prefix are unchanged. Unknown flags are opaque and cannot be extracted as plain data.

## Nested archives

Compressed main packages commonly use 7z framing and LZMA compression. Archive paths still require traversal checks, duplicate-path handling, entry-count limits, and expanded-byte limits. A 7z entry marked encrypted is AES evidence. The parser must not attempt password recovery or silently emit encrypted bytes as a package.
