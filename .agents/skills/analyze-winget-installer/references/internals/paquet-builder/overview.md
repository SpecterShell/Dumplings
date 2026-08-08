# Paquet Builder parser internals

This reference supports parser implementation and review. For installer analysis and manifest authoring, use the [Paquet Builder workflow](../../families/paquet-builder/workflow.md).

Read [binary notation](../../parser-development/binary-notation.md), [parser contracts](../../parser-development/contracts.md), and [performance guidance](../../parser-development/performance.md) before changing the parser.

## Supported formats and variants

The parser covers the structured Paquet Builder variants documented below. Variant-specific evidence must pass the same content-based detection and bounds checks.

## Binary structure

The supported Paquet Builder layout appends two independently valid standard 7z archives to a PE launcher. Dumplings classifies them by catalog contents rather than physical order.

```text
PE launcher
`-- overlay
    +-- payload 7z archive
    |   `-- installed/nested application files
    `-- runtime 7z archive
        +-- pbfprop.dat
        `-- PBCore.dll / PBCore64.dll
```

Each archive starts with `37 7A BC AF 27 1C` and has its own start header, catalog, packed streams, and bounded range. Runtime markers classify the runtime archive; the other validated archive is the payload. The parser does not infer ARP behavior from archive adjacency and keeps extraction paths/counts/expanded bytes bounded.

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

- Modules/PackageModule/Libraries/Installers/PaquetBuilder.psm1

## Representative fixtures

Use generated malformed fixtures and the behaviorally distinct real installers cited by the focused tests and family workflow.

## Source references

Use the source references in the mapped module headers and its focused tests. Add upstream references here when new behavior is grounded.
