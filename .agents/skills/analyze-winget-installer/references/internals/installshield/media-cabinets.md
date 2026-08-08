# InstallShield proprietary media and cabinet internals

[Back to InstallShield parser internals](overview.md).

## Binary structure

Some script-driven media stores `setup.inx` inside InstallShield's proprietary cabinet format rather than in the outer launcher catalog. Dumplings enumerates that catalog but extracts only InstallScript support files; the application payload remains compressed.

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

The focused reader rejects old pre-v6 catalogs, missing volumes, invalid ranges, oversized output, malformed Deflate chunks, expanded-size mismatches, and MD5 mismatches. Split files are read as one bounded stream over the first/last-file ranges in consecutive volume headers, including when Deflate framing crosses a volume boundary. Linked descriptors resolve through `LinkPrevious` with index, flag, depth, and cycle validation; `LinkNext` is retained as the forward alias relationship. `Get-InstallShieldInfo` exposes `InstallShieldCabinetSupport` with catalog counts and selected support-file evidence without returning every application-file record.

Modern InstallScript media stores project-authored registry sets and shell objects in descriptor-relative pointer graphs. The parser reads these records from the same bounded `data*.hdr` allocation used for the file catalog.

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

## Parsing behavior

`<Default>` is created during normal file transfer. Unassociated named registry sets are promoted only when a complete literal `CreateRegistrySet` call selects that name or the empty-string all-sets form. Component-associated registry sets are instead created when their selected component transfers, so they remain in `ConditionalMediaRegistryWrites` with component, feature-path, and eligible setup-type evidence. `CreateShellObjects` similarly applies only to unassociated shortcuts; component-associated records are created by component transfer and remain in `ConditionalMediaShortcuts` until feature/component selection is known.

## Metadata projection

The parser reports selected support files, literal registry records, protocols, file extensions, shell objects, setup types, components, and feature paths separately. Conditional component records remain conditional until setup-type and feature selection are known.

## Limits and gaps

The parser decodes the five documented REGDB value types, shortcut hotkeys, and show state. Other shortcut bytes stay unresolved rather than being guessed.
