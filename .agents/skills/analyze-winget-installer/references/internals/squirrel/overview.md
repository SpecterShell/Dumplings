# Squirrel and Velopack parser internals

This reference supports parser implementation and review. For installer analysis and manifest authoring, use the [Squirrel and Velopack workflow](../../families/squirrel/workflow.md).

Read [binary notation](../../parser-development/binary-notation.md), [parser contracts](../../parser-development/contracts.md), and [performance guidance](../../parser-development/performance.md) before changing the parser.

## Supported formats and variants

The parser covers the structured Squirrel and Velopack variants documented below. Variant-specific evidence must pass the same content-based detection and bounds checks.

## Binary structure

Squirrel.Windows stores an update ZIP in PE `DATA` resource ID `131` in the canonical layout. Velopack commonly stores a referenced nupkg/ZIP range in the launcher bundle header. A bounded ZIP fallback is used only when its nuspec structure validates the candidate.

```text
Squirrel PE setup
`-- .rsrc/DATA/#131
    `-- ZIP
        +-- *.nupkg -> ZIP -> *.nuspec
        `-- RELEASES / package payload

Velopack PE setup
`-- bundle locator
    +-- PayloadOffset, int64 LE      16 bytes before signature
    +-- PayloadLength, int64 LE
    +-- 32-byte Velopack signature
    `-- [PayloadOffset, Length] -> nupkg/ZIP
```

Velopack's signature is `94 F0 B1 7B 68 93 E0 29 37 EB 34 EF 53 AA E7 D4 2B 54 F5 70 7E F5 D6 F5 78 54 98 3E 5E 94 ED 7D`. Resource and locator ranges are absolute after PE RVA mapping. The parser requires a valid ZIP/nupkg and nuspec metadata, bounds candidate count/range extraction, and does not classify from `--silent` or a bare ZIP signature alone.

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

- Modules/PackageModule/Libraries/Installers/Squirrel.psm1

## Representative fixtures

Use generated malformed fixtures and the behaviorally distinct real installers cited by the focused tests and family workflow.

## Source references

- [Squirrel.Windows](https://github.com/Squirrel/Squirrel.Windows)
- [Velopack](https://github.com/velopack/velopack)
