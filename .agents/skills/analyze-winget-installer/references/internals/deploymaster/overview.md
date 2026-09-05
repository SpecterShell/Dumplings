# DeployMaster parser internals

This reference supports parser implementation and review. For installer analysis and manifest authoring, use the [DeployMaster workflow](../../families/deploymaster/workflow.md).

Read [binary notation](../../parser-development/binary-notation.md), [parser contracts](../../parser-development/contracts.md), and [performance guidance](../../parser-development/performance.md) before changing the parser.

## Supported formats and variants

The parser covers the structured DeployMaster variants documented below. Variant-specific evidence must pass the same content-based detection and bounds checks.

## Binary structure

DeployMaster keeps an absolute package locator at file offset `0x80`. The locator protects a bounded package range with expected file size and CRC32. The package begins with LZMA properties followed by a version-dependent control header, runtime cores, typed metadata blocks, and file ranges.

```text
PE setup stub
+-- locator at [abs] 0x80
`-- package at PackageOffset
    +-- 5-byte LZMA properties
    +-- 70/74-byte control header
    +-- x86 and/or x64 runtime cores
    +-- language data block
    +-- identity data block
    +-- current package-settings preamble and portable-folder block
    +-- metadata-resident file payloads
    +-- component data block
    +-- CRLF file-name data block
    +-- parallel file catalog
    +-- install-tree data block
    +-- registry-operation data block
    +-- file-association data block
    +-- prerequisite, completion, uninstall, and update tail
    `-- catalogued payload ranges
```

```text
Base   Offset  Size  Field
-----  ------  ----  ---------------------------------------------
[abs]  0x80    4     PackageOffset, uint32 LE -> [abs]
[abs]  0x84    4     IntegrityLength, uint32 LE
[abs]  0x88    4     ExpectedCRC32, uint32 LE
[abs]  0x8C    8     ExpectedFileSize, uint64 LE
[abs]  0x94    4     Reserved/observed
```

The CRC covers the declared integrity range, not all bytes to EOF. Current and legacy control headers are selected only after size/range checks. Undocumented control fields remain `Observed`; the parser uses only fields demonstrated by controlled builder samples and rejects truncated or expanding-out-of-bound ranges.

The first eight control-header bytes after the LZMA properties form a platform bitset. Controlled current-builder outputs identify `0x80` as Windows 7, `0x0100` as Windows 8, `0x0200` as Windows 8.1, `0x0400` as Windows 10, `0x0800` as Windows 11, and bit 63 as future Windows releases. Four following UInt16 fields hold the minimum and maximum Windows 10 and Windows 11 version codes. Older platform bits remain raw until separately verified.

Current media stores a compiled expiration year, month, and day at package-relative offsets `0x32`, `0x34`, and `0x36` as UInt16 values. A zero date disables expiration. When enabled, `0x38` is the absolute offset of the UTF-16LE expiration message and `0x3C` is its UInt16 character count. Legacy media shifts these fields four bytes earlier with the rest of its shorter control header. The message must fit between the last runtime core and the language block. Both fixed-date and days-after-release projects compile to this final date and cannot be distinguished afterward.

The structured identity block contains form-feed-delimited UTF-8 fields. Fields 0 through 6 hold publisher, publisher URL, application name, application URL, version, OLE Automation release day, and copyright. Fields 7 through 10 hold the readme filename, license filename and policy marker, x86 support-DLL filename, and x64 support-DLL filename. The first byte of field 11, the machine application path, is a route marker rather than part of the path: `0x01` selects machine scope, `0x02` selects user scope, `0x03` permits both, and `0x06` selects user scope while requiring administrative rights. Marker `0x06` intentionally shares package-control scope byte `1` with machine media, so registry hive selection must use the identity route. Fields 12 through 18 contain user application, common-files, publisher-common, machine/user menu, and common/user data locations.

## Data blocks

DeployMaster reuses one signed-size framing convention for metadata. All integers are little-endian and offsets are absolute unless noted otherwise.

```text
Offset  Size  Field
------  ----  -------------------------------------------------------
+0x00      4  Size, Int32
              0: empty block
             <0: stored byte count is -Size; bytes begin at +0x04
             >0: expanded byte count; CompressedSize follows
+0x04      4  CompressedSize, Int32, present only when Size > 0
+0x08      n  raw-LZMA bytes, using the package-level 5-byte properties
```

Each decoder receives the next structural boundary and an expanded-size limit. A block cannot consume the following record, and its decoded length must equal the declared positive size.

## Components and install tree

The component block begins with a byte count. Each component contains a length-prefixed UTF-8 name, a flag byte, a byte requirement count and requirement indexes, then a UTF-8 description. Flag bit `0x02` means installed by default and bit `0x01` means user-selectable.

One install-tree data block contains a recursive tree for every component in catalog order. A marker below `0xFE` is the UTF-16LE character count for a directory name, followed by a create-empty flag and nested records. `0xFE` starts an item list and `0xFF` terminates the current list or directory. The parser currently decodes file items (`0x80` family), file shortcuts (`0x40`), and URL shortcuts (`0x20`); every file reference is checked against the catalog.

## File catalog

The CRLF-delimited UTF-8 filename block ends immediately before the catalog. Readme, license, and x86/x64 support-DLL names are omitted from this block because identity fields 7 through 10 already carry them; they prefix ordinary names in the same order, with duplicate physical files represented once. Current media serializes one value per file in six parallel arrays: absolute offset, expanded size, stored size, OLE Automation timestamp, attributes, and CRC32. The first five arrays use 64-bit values and CRC32 uses 32 bits, for `44 * FileCount` bytes. Legacy media reconstructs the license entry before the table, so its offset array has one fewer value while the remaining arrays still cover every file.

Stored size equal to expanded size selects direct copying. Other files are raw-LZMA streams using the package properties. Expansion checks the selected entry's output size and CRC32 before retaining it.

## Registry and associations

The registry block is a recursive opcode stream. An outer `0x01` introduces a root name and branch; a non-`0x01` byte ends the root list. Branch opcodes are `0x01` child key, `0x02` delete key during uninstall, `0x03` select default value, `0x04` select named value, `0x05` keep an existing value, `0x06` logging/removal behavior, `0x07` `REG_SZ`, `0x08` `REG_DWORD`, `0x09` `REG_BINARY`, and `0xFF` end branch. `HKEY_AUTO` resolves to HKCU for user scope, HKLM for machine scope, and SHCTX for dual-scope media.

The following file-association block stores literal extensions, descriptions, default-selection flags, architecture-specific icon indexes, and action records. An action holds its name, x86/x64 executable indexes, and parameters. Registry-tab class writes are interpreted separately and then merged with these dedicated records.

## Trailing records

After associations, one byte is a .NET Framework compatibility mask: bits `0x01`, `0x02`, `0x04`, `0x08`, and `0x10` represent versions 1.0, 1.1, 2.0, 3.0, and 3.5, while `0x20` enables the 4.x family. The next byte selects the minimum 4.x release from 4.0 through 4.8.1. A data block follows with bare-CR positional fields for an optional automatic-installer filename and fallback download URL, followed by a 16-byte observed state record. A bounded signed custom-prerequisite count follows; every custom prerequisite has a compressed text descriptor and 16 observed bytes. The parser preserves undocumented positions without assigning guessed semantics.

Completion flags gate x86/x64 post-install file indexes and one argument block. The same tail stores architecture-specific pre-uninstall file indexes, arguments, and uninstall-shortcut settings. The final update flag byte uses `0x01` for delete-obsolete-files behavior, `0x02` for a patch package requiring a compatible previous release, `0x04` for blocked window classes, and `0x08` for blocked window captions. A UInt16 OLE Automation day follows, then each enabled variable-length field appears as a normal data block in patch text, class, caption order. File indexes are resolved to catalog names in `ExecutedPayloads`.

## Detection invariants

Accept the family only when the surrounding headers, ranges, counts, and relationships described above validate. Treat an isolated marker as a routing hint and preserve conditional values as unresolved evidence.

## Metadata projection

Project only structured metadata and explicit registry behavior into the shared parser result. Preserve conditional or unknown values as warnings or unresolved fields.

## Bounds and malformed input

Apply the shared parser bounds to every offset, size, count, decompressed range, destination path, and recursion boundary. Reject malformed input deterministically.

## Performance considerations

Open the installer once, reuse parsed layout evidence, and prefer bounded streams or selected-entry extraction over whole-file materialization.

## Known gaps

Several prerequisite descriptor positions, record flags, condition semantics, and support-DLL effects remain observed fields because the builder help does not define their wire representation. The source expiration mode is also lost after compilation; only its final date and message survive. Legacy releases outside the validated 70-byte control-header route and future layouts are rejected. Conditional runtime behavior remains explicit diagnostic or unresolved evidence rather than being inferred from arbitrary strings.

## Implementation mapping

- Modules/PackageModule/Libraries/Installers/DeployMaster.psm1

## Representative fixtures

Use generated malformed fixtures and the behaviorally distinct real installers cited by the focused tests and family workflow.

## Source references

- [DeployMaster manual](https://www.deploymaster.com/manual.html)
- [DeployMaster silent installation](https://www.deploymaster.com/manual.html#silent)
