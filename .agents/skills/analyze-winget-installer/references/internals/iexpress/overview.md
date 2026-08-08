# IExpress parser internals

This reference supports parser implementation and review. For installer analysis and manifest authoring, use the [IExpress workflow](../../families/iexpress/workflow.md).

Read [binary notation](../../parser-development/binary-notation.md), [parser contracts](../../parser-development/contracts.md), and [performance guidance](../../parser-development/performance.md) before changing the parser.

## Supported formats and variants

The parser covers the structured IExpress variants documented below. Variant-specific evidence must pass the same content-based detection and bounds checks.

## Binary structure

IExpress/WExtract packages keep both configuration strings and one or more CAB files in named PE resources.

```text
WExtract PE stub
`-- .rsrc
    +-- RUNPROGRAM / POSTRUNPROGRAM  text command resources
    +-- ADMQCMD / USRQCMD            administrative/user command variants
    +-- other SED-derived settings  prompt and extraction behavior
    `-- CABINET*                     Microsoft CAB resources
        +-- 4D 53 43 46 ("MSCF")
        +-- folder/file catalog
        `-- compressed payloads

selected command -> script, EXE, or MSI from CAB catalog + configured arguments
```

PE resource RVAs are mapped through the section table; each resource size bounds its CAB or text. Resource names, not neighboring strings, associate commands with settings. The configured command is execution evidence, while CAB entry order is only physical catalog order.

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

- Modules/PackageModule/Libraries/Installers/IExpress.psm1

## Representative fixtures

Use generated malformed fixtures and the behaviorally distinct real installers cited by the focused tests and family workflow.

## Source references

Use the source references in the mapped module headers and its focused tests. Add upstream references here when new behavior is grounded.
