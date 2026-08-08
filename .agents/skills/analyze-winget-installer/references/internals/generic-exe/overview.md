# Generic EXE fallback parser internals

This reference supports parser implementation and review. For installer analysis and manifest authoring, use the [Generic EXE fallback workflow](../../families/generic-exe/workflow.md).

Read [binary notation](../../parser-development/binary-notation.md), [parser contracts](../../parser-development/contracts.md), and [performance guidance](../../parser-development/performance.md) before changing the parser.

## Supported formats and variants

The parser covers the structured Generic EXE fallback variants documented below. Variant-specific evidence must pass the same content-based detection and bounds checks.

## Binary structure

Generic EXE is a fallback classification, not a file format, so it has no canonical binary layout. Record only structures independently proven by the analyzer, such as a valid PE header, resource tree, certificate range, overlay, or embedded standard archive. Do not combine unrelated markers into an invented proprietary header.

```text
PE image (known)
+-- DOS/PE/section headers
+-- resources and certificate table (if present)
`-- overlay or nested ranges (format unknown until separately validated)
```

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

- Modules/PackageModule/Libraries/Infrastructure/InstallerAnalyzer.psm1

## Representative fixtures

Use generated malformed fixtures and the behaviorally distinct real installers cited by the focused tests and family workflow.

## Source references

- [Detect It Easy](https://github.com/horsicq/Detect-It-Easy)
- [Universal Extractor 2](https://github.com/Bioruebe/UniExtract2)
