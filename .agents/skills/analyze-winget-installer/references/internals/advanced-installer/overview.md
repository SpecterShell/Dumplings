# Advanced Installer parser internals

This reference supports parser implementation and review. For installer analysis and manifest authoring, use the [Advanced Installer workflow](../../families/advanced-installer/workflow.md).

Read [binary notation](../../parser-development/binary-notation.md), [parser contracts](../../parser-development/contracts.md), and [performance guidance](../../parser-development/performance.md) before changing the parser.

## Supported formats and variants

The parser covers the structured Advanced Installer variants documented below. Variant-specific evidence must pass the same content-based detection and bounds checks.

## Binary structure

The supported Advanced Installer bootstrapper stores a catalog and payload ranges before a fixed footer near the end of the PE file. An Authenticode certificate may follow the logical footer, so the parser searches backward in a bounded tail instead of assuming `EOF - 70`.

```text
PE bootstrapper
+-- payload ranges                  MSI/CAB/config bytes
+-- file catalog at InfoOffset
|   `-- repeated 24-byte entry + UTF-16LE name
`-- footer (70 bytes; observed variants may include 2 tail bytes)
    `-- "ADVINSTSFX" at footer + 0x3C
```

```text
Base      Offset  Size     Field
--------  ------  -------  ----------------------------------------
[footer]  0x04    4        FileCount, uint32 LE
[footer]  0x10    4        InfoOffset, uint32 LE -> [abs] catalog
[footer]  0x14    4        FileOffset, uint32 LE -> [abs] payload area
[footer]  0x3C    10       Magic: 41 44 56 49 4E 53 54 53 46 58
[record]  0x00    4        SelectorType, uint32 LE
[record]  0x04    4        SelectorGroup, uint32 LE
[record]  0x08    4        TransformFlag, uint32 LE
[record]  0x0C    4        PayloadSize, uint32 LE
[record]  0x10    4        PayloadOffset, uint32 LE -> [abs]
[record]  0x14    4        NameLength, uint32 LE UTF-16 code units
[record]  0x18    N*2      Name, UTF-16LE
```

`TransformFlag == 2` means the first `min(512, PayloadSize)` bytes are XORed with `0xFF`; the remainder is direct. Selector type/group and the configuration INI choose the architecture-specific MSI by configured path. A wildcard MSI search would not reproduce the bootstrapper's selection behavior.

## Detection invariants

Accept the family only when the surrounding headers, ranges, counts, and relationships described above validate. Treat an isolated marker as a routing hint and preserve conditional values as unresolved evidence.

## Metadata projection

Project only structured metadata and explicit registry behavior into the shared parser result. Preserve conditional or unknown values as warnings or unresolved fields.

## Bounds and malformed input

Apply the shared parser bounds to every offset, size, count, decompressed range, destination path, and recursion boundary. Reject malformed input deterministically.

## Performance considerations

Open the installer once, reuse parsed layout evidence, and prefer bounded streams or selected-entry extraction over whole-file materialization.

## Known gaps

Unsupported variants and conditional runtime behavior remain explicit warnings or unresolved evidence; they are not inferred from arbitrary strings.

## Implementation mapping

- Modules/PackageModule/Libraries/Installers/AdvancedInstaller.psm1
- Modules/InstallerParsers/Libraries/Installers/AdvancedInstaller.psm1

## Representative fixtures

Use generated malformed fixtures and the behaviorally distinct real installers cited by the focused tests and family workflow.

## Source references

- [HydraDragonAntivirus](https://github.com/HydraDragonAntivirus/HydraDragonAntivirus)
- [Komac](https://github.com/russellbanks/Komac)
