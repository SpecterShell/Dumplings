# dotNetInstaller parser internals

This reference supports parser implementation and review. For installer analysis and manifest authoring, use the [dotNetInstaller workflow](../../families/dotnetinstaller/workflow.md).

Read [binary notation](../../parser-development/binary-notation.md), [parser contracts](../../parser-development/contracts.md), and [performance guidance](../../parser-development/performance.md) before changing the parser.

## Supported formats and variants

The parser covers the structured dotNetInstaller variants documented below. Variant-specific evidence must pass the same content-based detection and bounds checks.

## Binary structure

dotNetInstaller is a PE resource wrapper. Its XML configuration controls conditional execution; embedded CAB order alone does not.

```text
PE bootstrapper
`-- .rsrc
    +-- CUSTOM / RES_CONFIGURATION  UTF-8 or BOM-marked UTF-16 XML
    `-- RES_CAB / <resource name>    one or more Microsoft CAB ranges
        +-- 4D 53 43 46 ("MSCF")
        +-- CAB folders/file catalog
        `-- compressed component payloads

configuration/component
  +-- OS and architecture conditions
  +-- interactive/basic/silent command
  `-- payload reference -> matching RES_CAB entry
```

Resource offsets are PE resource-relative until mapped to absolute file ranges. CAB payloads are bounded by each resource's declared size. The XML is authoritative for component order, conditions, executable, and arguments; extracting every CAB does not prove every component will run.

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

- Modules/PackageModule/Libraries/Installers/DotNetInstaller.psm1

## Representative fixtures

Use generated malformed fixtures and the behaviorally distinct real installers cited by the focused tests and family workflow.

## Source references

- [dotNetInstaller](https://github.com/dotnetinstaller/dotnetinstaller)
