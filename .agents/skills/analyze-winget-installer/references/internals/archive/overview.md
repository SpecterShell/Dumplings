# Archive parser internals

This reference supports parser implementation and review. For installer analysis and manifest authoring, use the [Archive workflow](../../families/archive/workflow.md).

Read [binary notation](../../parser-development/binary-notation.md), [parser contracts](../../parser-development/contracts.md), and [performance guidance](../../parser-development/performance.md) before changing the parser.

## Supported formats and variants

The parser covers the structured Archive variants documented below. Variant-specific evidence must pass the same content-based detection and bounds checks.

## Binary structure

Archives do not share one binary layout. Identify the outer signature, parse that format's catalog, and route selected entries by content.

```text
Archive
+-- format header/signature         ZIP, 7z, RAR, TAR, or another supported type
+-- entry catalog                   names, sizes, compression, CRC/hash
`-- selected bounded entry range
    `-- PE / MSI / MSIX / font      route again by content
```

Entry offsets and lengths are container-relative. A ZIP central directory is catalog evidence, not proof that an entry is safe to export.

## Detection invariants

Validate entry counts, declared and expanded sizes, checksums, compression support, recursion depth, and destination paths before extraction. Reject rooted, traversing, duplicate, linked, or escaping paths. Extract only selected entries when the caller does not need the full archive.

Shared implementations live in `Modules/PackageModule/Libraries/Infrastructure/Archive.psm1` and its mirrored InstallerParsers counterpart. See [Binary notation](../../parser-development/binary-notation.md) and [parser contracts](../../parser-development/contracts.md).

## Metadata projection

Project only structured metadata and explicit registry behavior into the shared parser result. Preserve conditional or unknown values as warnings or unresolved fields.

## Bounds and malformed input

Apply the shared parser bounds to every offset, size, count, decompressed range, destination path, and recursion boundary. Reject malformed input deterministically.

## Performance considerations

Open the installer once, reuse parsed layout evidence, and prefer bounded streams or selected-entry extraction over whole-file materialization.

## Known gaps

Unsupported variants and conditional runtime behavior remain explicit warnings or unresolved evidence; they are not inferred from arbitrary strings.

## Implementation mapping

See the focused parser modules and tests named below.

## Representative fixtures

Use generated malformed fixtures and the behaviorally distinct real installers cited by the focused tests and family workflow.

## Source references

- [SharpCompress](https://github.com/adamhathcock/sharpcompress)
