# InstallForge parser internals

This reference supports parser implementation and review. For installer analysis and manifest authoring, use the [InstallForge workflow](../../families/installforge/workflow.md).

Read [binary notation](../../parser-development/binary-notation.md), [parser contracts](../../parser-development/contracts.md), and [performance guidance](../../parser-development/performance.md) before changing the parser.

## Supported formats and variants

The parser covers the structured InstallForge variants documented below. Variant-specific evidence must pass the same content-based detection and bounds checks.

## Binary structure

InstallForge separates configuration and payload into two standard 7z containers. The configuration archive is a named PE resource; payload bytes are in the PE overlay.

```text
PE setup stub
+-- .rsrc/RCDATA/SETUPCONFIGURATION
|   `-- 7z archive
|       `-- SC.dat                  structured setup configuration
`-- overlay
    `-- 7z archive                  install payload files
```

Both archives begin with `37 7A BC AF 27 1C` and are bounded independently. `SC.dat` supplies identity, directory, scope, registry associations, and payload metadata. Some stored path components are Base64-encoded UTF-16LE; decoding is applied only where the structured configuration marks those values. Archive extraction still enforces traversal, duplicate-path, entry-count, and byte limits.

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

- Modules/PackageModule/Libraries/Installers/InstallForge.psm1

## Representative fixtures

Use generated malformed fixtures and the behaviorally distinct real installers cited by the focused tests and family workflow.

## Source references

Use the source references in the mapped module headers and its focused tests. Add upstream references here when new behavior is grounded.
