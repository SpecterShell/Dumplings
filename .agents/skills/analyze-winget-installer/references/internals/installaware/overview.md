# InstallAware parser internals

This reference supports parser implementation and review. For installer analysis and manifest authoring, use the [InstallAware workflow](../../families/installaware/workflow.md).

Read [binary notation](../../parser-development/binary-notation.md), [parser contracts](../../parser-development/contracts.md), and [performance guidance](../../parser-development/performance.md) before changing the parser.

## Supported formats and variants

The parser covers the structured InstallAware variants documented below. Variant-specific evidence must pass the same content-based detection and bounds checks.

## Binary structure

The supported InstallAware parser recognizes standard 7z archives embedded in a PE launcher and requires InstallAware-specific project entries inside the archive.

```text
PE setup launcher
`-- one or more embedded 7z ranges
    +-- 37 7A BC AF 27 1C          7z signature
    +-- 7z catalog
    +-- mia.lib / *.mia            project evidence
    +-- _setup.exe / resources     nested setup logic
    `-- data/ and payload entries
```

Each 7z candidate is opened as a bounded archive and ranked by structured entry evidence. The parser does not claim an undocumented InstallAware header around the standard archive. PE requested-execution-level and version resources are separate supporting layers; nested MSI/EXE files must be routed independently.

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

- Modules/PackageModule/Libraries/Installers/InstallAware.psm1

## Representative fixtures

Use generated malformed fixtures and the behaviorally distinct real installers cited by the focused tests and family workflow.

## Source references

Use the source references in the mapped module headers and its focused tests. Add upstream references here when new behavior is grounded.
