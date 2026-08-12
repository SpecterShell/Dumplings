# InstallShield proprietary media and cabinet internals

[Back to InstallShield internals](overview.md).

This page describes InstallShield's proprietary `data*.hdr` and `data*.cab` media. It is unrelated to Microsoft Cabinet files used by PackageForTheWeb. Both formats may appear in one setup and remain separate container layers.

## Binary structure

Script-driven media can store `setup.inx`, string tables, project configuration, and application files inside InstallShield's proprietary cabinet format rather than in the outer launcher.

```text
data1.hdr
+-- CommonHeader (20 bytes)
|   +-- 0x00  4  Magic: 49 53 63 28 ("ISc(")
|   +-- 0x04  4  Version, uint32 LE
|   +-- 0x0C  4  CabinetDescriptorOffset, uint32 LE
|   `-- 0x10  4  CabinetDescriptorSize, uint32 LE
`-- CabinetDescriptor
    +-- directory/file counts and relative table offsets
    +-- directory and file-name strings (UTF-16LE for modern media)
    +-- descriptor+0x30 -> locale-specific setup-type records
    +-- descriptor+0x3E -> 71 file-group hash buckets
    +-- descriptor+0x15A -> 71 component hash buckets
    +-- descriptor+0x27E -> shell-object table directory
    +-- descriptor+0x282 -> registry-set directory
    `-- repeated 0x57-byte file descriptors
        +-- flags, expanded/compressed sizes, and data offset
        +-- MD5, name offset, directory index, and volume number
        `-- split/link metadata

dataN.cab
+-- CommonHeader (20 bytes)
+-- VolumeHeader (64 bytes for InstallShield 6+)
`-- selected file range
    `-- repeated uint16-LE compressed length + raw Deflate block
```

InstallShield 5 uses two related profiles. Early media stores both the catalog and payload ranges in `data1.cab`; its family-1 raw version can normalize to major `0`, as in the archived InstallShield 5 Professional value `0x01000004`. Later media can split the catalog into `data1.hdr` and adds a digest to each descriptor.

```text
data1.cab or data1.hdr file-table offset entry -> FileDescriptor5
Offset  Size  Field
------  ----  ----------------------------------------
0x00       4  NameOffset, uint32 LE
0x04       2  DirectoryIndex, uint16 LE
0x08       2  Flags, uint16 LE
0x0A       4  ExpandedSize, uint32 LE
0x0E       4  CompressedSize, uint32 LE
0x26       4  DataOffset, uint32 LE
0x2A      16  Expanded-data MD5 (later major-5 profile only)

dataN.cab
+-- CommonHeader (20 bytes)
+-- VolumeHeader5 (40 bytes; first/last-file ranges)
`-- raw-Deflate streams separated by 00 00 FF FF
```

The pre-digest descriptor occupies 0x2A bytes and has no checksum field. The later descriptor occupies 0x3A bytes and appends the 16-byte MD5. Both use the `Cabinet5/LegacyDescriptor` route because the payload framing and 40-byte volume header are shared, while `StructuralProfile` distinguishes `LegacyDescriptorWithoutDigest` from `LegacyDescriptor`.

The known layouts are the two InstallShield 5 legacy descriptors, a version-6-and-later ANSI catalog, and a version-17-and-later Unicode catalog. Unknown `ISc(` versions must not be forced into one of these layouts. Split files span consecutive volume ranges, including cases where Deflate framing crosses a volume boundary. `LinkPrevious` identifies the descriptor that owns stored bytes; `LinkNext` describes the forward relationship.

The high byte of `Version` selects its encoding family. Family `1` carries a legacy cabinet-format generation and must not be mapped to a builder release; official InstallShield 11.5 output uses `0x01009500`, identifying format 9. Families `2` and `4` use a version/100 encoding whose major is builder-aligned in the official modern fixtures (`0x04000C1C` for InstallShield 2025 and `0x04000C80` for 2026). Builder release and cabinet layout remain separate version domains.

Some modern InstallScript media stores project-authored registry sets and shell objects in descriptor-relative pointer graphs in the same `data*.hdr` catalog as the file table. The concrete offsets documented below are grounded in validated cabinet majors 22, 30, and 32. ANSI majors 6 through 16 use generation-specific optional fields and are not projected. Unicode majors 17 through 29 are decoded transactionally: evidence is published only when the complete bounded graph validates, so a failed probe cannot leak partial records or produce a false malformed-media warning.

```text
descriptor+0x282 -> RegistryDirectory
+0x00  uint16  registry-set count
+0x02  uint32  registry-set offset table, descriptor-relative
  `-> RegistrySet (40 bytes)
      +0x00 uint32 qualified name, usually ProductGUID:SetName
      +0x04 uint16 component count
      +0x06 uint32 component-name offset table
      `+0x0A five 6-byte root slots: HKCR, HKCU, HKLM, HKU, SHCTX
          `-> KeyRecord (14 bytes) -> ValueRecord (10 bytes)
              +0x00 uint32 value-name pointer
              +0x04 uint16 REGDB type
              `+0x06 uint32 encoded-data string pointer

REGDB payload encodings used by current media
+-- REGDB_STRING / REGDB_STRING_EXPAND -> direct media string
+-- REGDB_BINARY -> hexadecimal byte string
+-- REGDB_NUMBER -> invariant decimal uint32 text
`-- REGDB_STRING_MULTI -> hexadecimal MULTI_SZ bytes

descriptor+0x30 -> SetupTypeLocaleGroup[]
  `-> SetupType -> included feature-path strings

descriptor+0x3E / +0x15A -> 71 OffsetList hash buckets
+-- FileGroup -> project Component name + first/last cabinet file index
`-- Component -> feature path + included FileGroup names

descriptor+0x27E -> media-table offset array
  `-> entry 2 -> shell-folder group
      `-> ShellFolder (20 bytes)
          `-> packed ShortcutRecord (54 bytes)
              +-- Name / ISShortcutName
              +-- Target / Arguments / WorkingDirectory
              +-- generated properties (`HotKeyCode=...`) / ShowCmd
              `-- owning component
```

## Catalog and volume separation

`data1.hdr` owns names, directories, descriptors, links, setup types, feature topology, registry sets, and shell records. `dataN.cab` owns payload byte ranges. The catalog can therefore be enumerated even when one payload volume is absent. A missing volume and a malformed catalog are different media failures.

## Version decoding and profiles

The uint32 version in the common header selects a descriptor and string profile:

```text
major 0       -> 0x2A legacy descriptor without MD5, 40-byte volume header
major 5       -> 0x3A legacy descriptor with MD5, 40-byte volume header
major 6..16   -> 0x57 descriptor, ANSI catalog strings; core catalog
major 17..29  -> 0x57 descriptor, UTF-16LE catalog strings; validated optional graphs only
major 30..32  -> 0x57 descriptor, UTF-16LE catalog strings; grounded optional graphs
major > 32    -> future Unicode profile; bounded base layout only
unknown       -> unknown layout; do not guess a descriptor profile
```

This threshold selects a byte layout. Product and media versions are described separately in [versions and generations](versions-and-generations.md).

## File descriptors

A valid descriptor names one logical file and identifies its file index, directory, flags, expanded and compressed sizes, data offset, MD5, volume, and link fields.

| Flag evidence | Meaning used by the reader |
| --- | --- |
| bit 0 | File data spans media ranges or volumes. |
| bit 1 | Payload uses the InstallShield obfuscation transform. |
| bit 2 | Payload is compressed. |
| bit 3 | Descriptor is invalid or deleted and is not extractable. |

A descriptor resolves to bytes only after its name, offset, validity flag, and linked source are valid. Undocumented flag bits should remain uninterpreted.

## Linked and split files

`LinkPrevious` points toward the descriptor that owns stored bytes. Resolution requires a valid index and an acyclic chain. `LinkNext` is a forward relationship, not an unchecked extraction pointer.

Split files form one logical byte stream over consecutive volume ranges. Deflate framing may cross a volume boundary; the physical volumes are not independent compressed files.

Each required numbered volume has its own common and volume header. The descriptor must belong to the volume's declared file range. A missing intermediate volume makes the logical file incomplete while leaving catalog metadata available.

## Compression and integrity

Compressed modern entries contain repeated uint16-LE chunk lengths followed by raw Deflate blocks. A chunk expands to at most 64 KiB. The descriptor supplies the complete expanded size. Version-5 streams use their raw-Deflate separators.

Expanded size protects every logical file. MD5 additionally protects later legacy and modern descriptors, but the pre-digest major-0 profile has no stored digest to verify. Obfuscation applies only to the selected descriptor range and in the order defined by that media generation.

## Descriptor-relative metadata graphs

Every pointer in a validated registry, shell, setup-type, component, and file-group graph is descriptor-relative unless the layout states otherwise. It must resolve inside the declared descriptor, not merely somewhere in `data1.hdr`.

The records form this authored topology:

```text
setup type
  -> feature path
      -> component
          -> file group
              -> first..last cabinet file indexes

component
  +-> registry set
  `-> shell folder / shortcut
```

This graph describes eligibility. It does not prove the setup type or feature a user selects at runtime.

### Registry sets

Each registry set has a qualified name, short name, default-set flag, and zero or more component associations. Root slots identify HKCR, HKCU, HKLM, HKU, or SHCTX branches. Key and value counts, offset tables, strings, and encoded data are validated independently.

Known records encode string, expandable-string, binary, uint32, and multi-string values. An unknown REGDB type has no safe string interpretation.

### Shell objects

Shell folders contain packed shortcut records with name, target, arguments, working directory, component, folder, hotkey, and show-state fields. Other bytes remain undocumented.

### Setup types, features, and components

Locale-specific setup types list feature paths. Components connect those paths to file groups and file-index ranges. This topology supplies `Features` and `SetupTypes` on conditional registry and shortcut evidence.

## Runtime application of authored records

`<Default>` is created during normal file transfer. An unassociated named registry set is created when project code calls `CreateRegistrySet` for that name; the empty-string form selects all applicable sets. Component-associated registry records are created while the selected component transfers.

`CreateShellObjects` similarly applies unassociated shell records. Shortcuts owned by a component follow component transfer and feature selection. The media catalog therefore describes possible authored resources, while setup type, feature state, component state, and script calls determine which resources are installed.

## Authored data and runtime effects

Literal registry records, protocols, file extensions, shortcuts, setup types, components, and feature paths are authored media data. Conditional component records remain conditional until setup-type and feature selection are known.

Media records are not automatically executed effects. Registry-set calls, shell-object calls, and component transfer connect the catalog to runtime behavior.

## Generation boundaries

The five documented REGDB value types, shortcut hotkeys, and show state have known representations. Other shortcut bytes remain undocumented.

InstallShield 5 does not use the modern registry, shell, setup-type, or component pointer graphs. Those offsets must not be applied to either legacy descriptor. Majors 6 through 16 have a supported core catalog but generation-specific optional metadata. Unicode majors 17 through 29 may publish the documented registry and shell graphs only after every count, offset, string, and record range validates transactionally. InstallShield 5's active `setup.ins` is ordinarily external media beside `Setup.exe`; a `setup.ins` found inside the application cabinet can instead be an installed sample or template and is not automatically analyzed as the outer setup program.

Common structural failures point to different media layers:

| Warning | Inspect |
| --- | --- |
| Descriptor outside the file table | Version/profile selection and file-table base. |
| Registry offset table outside the descriptor | Optional metadata layout, pointer base, or truncation. |
| Missing volume | Incomplete media or numbered-volume resolution. |
| Expanded-size mismatch | Compression framing, split range, or corrupt payload. |
| MD5 mismatch | Source descriptor, transform order, or corrupt media. |
| Link cycle or invalid previous index | Malformed catalog; do not extract the entry. |

Unknown later fields should not invalidate a structurally sound file catalog. Conversely, a valid optional metadata pointer cannot repair a malformed core descriptor or payload range.

## Sources

- [Unshield](https://github.com/twogood/unshield) for proprietary cabinet catalogs, descriptors, volumes, links, transforms, Deflate framing, and historical profile behavior.
- [ISx](https://github.com/lifenjoiner/ISx) for InstallShield container identification and transformed setup payload behavior.
