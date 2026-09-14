# Astrum InstallWizard binary format

All footer integers are unsigned little-endian values. Configuration and operation tables use bounded readers with their own big-endian primitives and Windows-1252 strings. File offsets are absolute unless a field is explicitly described as record-relative or logical-stream-relative.

## Physical layers

```text
PE image
+-- DOS, COFF, optional headers, sections, resources, and manifest
+-- native runtime option table
`-- logical Astrum overlay
    +-- protected configuration
    +-- optional pre-catalog UI/resource ranges
    +-- installation-item table
    +-- file records and payload members
    +-- generated-uninstaller GZip member
    +-- 0xE8 or 0xEC footer
    +-- optional magic 3E 2D 1C 0B 78 56 34 12
    `-- optional PE certificate alignment and WIN_CERTIFICATE table
```

The logical end is physical EOF for unsigned media or the validated PE security-directory offset for signed media after removing at most eight zero alignment bytes. A trailer candidate is accepted only when its footer self pointer, configuration range, installation-item range, file count, and exact file-catalog endpoint agree.

## Footer profiles

| Field | `astrum-1` offset | `astrum-2` offset | Meaning |
| --- | ---: | ---: | --- |
| ConfigurationOffset | `0x00` | `0x00` | absolute protected-configuration start |
| ConfigurationSize | `0x04` | `0x04` | protected byte count |
| UninstallerCompressedSize | `0xA4` | `0xA8` | generated-uninstaller GZip length, zero when absent |
| UninstallerOffset | `0xA8` | `0xAC` | absolute uninstaller member start |
| InstallationItemCount | `0xAC` | `0xB0` | installation-item record count |
| InstallationItemOffset | `0xB0` | `0xB4` | absolute table start |
| InstallationItemSize | `0xB4` | `0xB8` | complete table byte length |
| FileCount | `0xB8` | `0xBC` | file-record count |
| FileOffset | `0xBC` | `0xC0` | absolute first file record |
| PayloadSize | `0xC0` | `0xC4` | observed aggregate stored payload size |
| ExpandedSize | `0xC4` | `0xC8` | observed aggregate expanded payload size |
| InstalledSize | `0xC8` | `0xCC` | observed installed-size value |
| SelfPointer | `0xE4` | `0xE8` | absolute footer start |

The two profiles use 60-byte and 64-byte file descriptors respectively. The 2.x descriptor adds a condition word at index 15. Descriptor words 8 and 9 contain the high and low `VS_FIXEDFILEINFO` version halves when neither is `0xFFFFFFFF`; word 10 then packs code page in the high word and language ID in the low word.

## Protected configuration

```text
protected bytes
+-- integrity byte A
+-- transformed configuration bytes
`-- integrity byte B
```

The runtime transform is applied twice around integrity checks. The parser requires both checks and an exact structural parse after decoding. A checksum failure cannot fall through to treating the bytes as plaintext. Decoded strings are length-bounded Windows-1252 values and collection counts are checked before allocation.

Configuration starts with recursive registry records, shortcuts, INI operations, text operations, file operations, variables, interactive operations, identity strings, and generation-dependent option data. `Legacy1` stops interactive records after execute count. The 2.x route adds flags, a custom message, a condition, and a post-interactive table.

## Installation-item and file records

Installation-item groups bind authored feature names and selection state to file-record indexes. Physical file identity remains the catalog record, not the filename, because several items can reuse names or destinations under different conditions.

```text
file record
+-- path and destination expression
+-- compression and expected-size fields
+-- absolute or logical payload offset
+-- installation-item index
+-- attributes and version-resource words
+-- 2.x condition word
`-- stored bytes: GZip member or exact stored range
```

GZip records are bounded to the descriptor range. The decompressor verifies member checksum and length, and extraction compares the output with the expected size. Stored records copy exactly the declared byte count. A payload cannot consume the next record even if its compressed stream would continue.

## Tiny wrappers

```text
outer PE
`-- 96-byte descriptor
    +-- version and reserved words
    +-- innerOffset:u32 LE
    +-- compressedSize:u32 LE
    +-- expandedSize:u32 LE
    +-- silentExtraction:u32 LE
    `-- bounded GZip member -> complete inner Astrum PE
```

`silentExtraction=1` identifies the tiny route and zero identifies tiny-verbose. The descriptor flags, ranges, GZip framing, output size, and complete inner Astrum structure must all validate. Marker strings or a generic GZip overlay are insufficient.

## Spanned media

Spanned 2.x media is one virtual address space. The setup EXE contains the beginning and footer-owned end; caller-supplied companion files fill the missing middle range in explicit order. Their aggregate length must equal the catalog gap exactly. The parser uses a disk-backed seekable composite and records per-file `VolumeOffsets`; it never searches adjacent directories for guessed companions.

## Raw ranges

Footer pointers do not name every compiled dialog or image range before the catalog. Raw extraction subtracts all owned ranges from the validated logical overlay and exports the remaining bounded gaps under `_astrum\pre-catalog`. Those bytes remain untyped until controlled builds or runtime code establishes their grammar.
