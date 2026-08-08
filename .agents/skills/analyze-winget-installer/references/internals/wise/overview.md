# Wise parser internals

This reference supports parser implementation and review. For installer analysis and manifest authoring, use the [Wise workflow](../../families/wise/workflow.md).

Read [binary notation](../../parser-development/binary-notation.md), [parser contracts](../../parser-development/contracts.md), and [performance guidance](../../parser-development/performance.md) before changing the parser.

## Supported formats and variants

The parser covers the structured Wise variants documented below. Variant-specific evidence must pass the same content-based detection and bounds checks.

## Binary structure

The implemented Wise variant is a PE wrapper containing a complete CFB MSI range. Wise marker strings identify the engine; the CFB root CLSID proves that the nested object is an MSI database.

```text
Wise PE launcher
+-- Wise engine resources/markers
`-- embedded CFB range
    +-- D0 CF 11 E0 A1 B1 1A E1   CFB header
    +-- FAT/directory streams
    `-- Root Entry CLSID
        `{000C1084-0000-0000-C000-000000000046}`
        `-- Windows Installer tables and payload streams
```

The embedded range starts at the validated CFB signature and ends before the Authenticode certificate table or file end. Dumplings validates CFB/root-storage structure before carving, then passes the exact MSI to `Get-MsiInstallerInfo`. Other historical Wise formats are outside this parser and must not be inferred from this layout.

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

- Modules/PackageModule/Libraries/Installers/Wise.psm1

## Representative fixtures

Use generated malformed fixtures and the behaviorally distinct real installers cited by the focused tests and family workflow.

## Source references

No external source-code repository is recorded in the parser module header.
