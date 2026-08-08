# Font parser internals

This reference supports parser implementation and review. For installer analysis and manifest authoring, use the [Font workflow](../../families/font/workflow.md).

Read [binary notation](../../parser-development/binary-notation.md), [parser contracts](../../parser-development/contracts.md), and [performance guidance](../../parser-development/performance.md) before changing the parser.

## Supported formats and variants

The parser covers the structured Font variants documented below. Variant-specific evidence must pass the same content-based detection and bounds checks.

## Binary structure

Font formats use their own signatures and table directories. The installer analyzer currently treats a recognized font as a terminal artifact rather than emulating an installer.

```text
Font file
+-- format signature or sfnt version
+-- table directory
`-- named tables and glyph data
```

Do not infer a font family from the extension alone. Parse the format signature and naming metadata where available. Unknown table fields remain unknown; they are not installer metadata.

## Detection invariants

A marker alone is a routing hint. Accept the family only after its surrounding headers, ranges, counts, and relationships validate.

## Metadata projection

Project only structured metadata and explicit registry behavior into the shared parser result. Preserve conditional or unknown values as warnings or unresolved fields.

## Bounds and malformed input

Apply the shared parser bounds to every offset, size, count, decompressed range, destination path, and recursion boundary. Reject malformed input deterministically.

## Performance considerations

Open the installer once, reuse parsed layout evidence, and prefer bounded streams or selected-entry extraction over whole-file materialization.

## Known gaps

Dumplings does not expose a full cross-format font metadata parser. Confirm format and names with a trusted static tool when module evidence is incomplete. External tools are research evidence and must not become parser runtime dependencies.

## Implementation mapping

See the focused parser modules and tests named below.

## Representative fixtures

Use generated malformed fixtures and the behaviorally distinct real installers cited by the focused tests and family workflow.

## Source references

- [OpenType specification](https://learn.microsoft.com/en-us/typography/opentype/spec/)
