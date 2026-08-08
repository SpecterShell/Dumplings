# WinRAR GUI SFX parser internals

This reference supports parser implementation and review. For installer analysis and manifest authoring, use the [WinRAR GUI SFX workflow](../../families/winrar-sfx/workflow.md).

Read [binary notation](../../parser-development/binary-notation.md), [parser contracts](../../parser-development/contracts.md), and [performance guidance](../../parser-development/performance.md) before changing the parser.

## Supported formats and variants

The parser covers the structured WinRAR GUI SFX variants documented below. Variant-specific evidence must pass the same content-based detection and bounds checks.

## Binary structure

WinRAR GUI SFX is a PE launcher followed by a standard RAR archive. SFX commands are stored in the archive comment/configuration; they are execution metadata rather than payload bytes.

```text
PE WinRAR SFX stub
`-- RAR archive
    +-- 52 61 72 21 1A 07 00       RAR4 signature
    |   or 52 61 72 21 1A 07 01 00 RAR5 signature
    +-- archive headers/catalog
    +-- SFX comment
    |   +-- Presetup=<command>
    |   `-- Setup=<command>
    `-- compressed entries

Presetup/Setup -> named archive entry + configured arguments
```

Dumplings asks SharpCompress for the bounded archive/comment structure, resolves configured commands against catalog entries, and applies safe-path/count/byte limits during export. The first EXE in archive order is not assumed to be the executed payload.

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

- Modules/PackageModule/Libraries/Installers/WinRarSfx.psm1

## Representative fixtures

Use generated malformed fixtures and the behaviorally distinct real installers cited by the focused tests and family workflow.

## Source references

Use the source references in the mapped module headers and its focused tests. Add upstream references here when new behavior is grounded.
