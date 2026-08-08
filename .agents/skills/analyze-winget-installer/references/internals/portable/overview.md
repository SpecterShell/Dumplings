# Portable parser internals

This reference supports parser implementation and review. For installer analysis and manifest authoring, use the [Portable workflow](../../families/portable/workflow.md).

Read [binary notation](../../parser-development/binary-notation.md), [parser contracts](../../parser-development/contracts.md), and [performance guidance](../../parser-development/performance.md) before changing the parser.

## Supported formats and variants

The parser covers the structured Portable variants documented below. Variant-specific evidence must pass the same content-based detection and bounds checks.

## Binary structure

```text
Portable executable
+-- DOS header: 4D 5A ("MZ")
+-- PE signature: 50 45 00 00
+-- COFF/optional headers           machine, subsystem, data directories
`-- sections / CLR metadata / imports
```

PE offsets and RVAs are image-relative and must be mapped through the section table. Architecture analysis combines the COFF machine, CLR flags, managed target framework, apphost binding, bundle metadata, and adjacent native libraries.

### Tauri generated assets

```text
PE .rdata
+-- PHF entry slice
|   +-- name VA          uint32 on PE32, uint64 on PE32+
|   +-- name byte count  pointer-sized unsigned word
|   +-- payload VA       pointer-sized unsigned word
|   `-- stored byte count
+-- rooted UTF-8 names   /index.html, /assets/app.js, ...
+-- Brotli or raw bytes  one mode per generated asset map
`-- Tauri markers        bundle type, internal API, asset origin
```

The record is 16 bytes for PE32 x86 and 32 bytes for PE32+ x64 or ARM64. Pointers are absolute image virtual addresses and require image-base and section mapping. The CSP hash map has the same pointer shape but does not contain file payloads.

## Detection invariants

A marker alone is a routing hint. Accept the family only after its surrounding headers, ranges, counts, and relationships validate.

## Metadata projection

Project only structured metadata and explicit registry behavior into the shared parser result. Preserve conditional or unknown values as warnings or unresolved fields.

## Bounds and malformed input

Apply the shared parser bounds to every offset, size, count, decompressed range, destination path, and recursion boundary. Reject malformed input deterministically.

## Performance considerations

Open the installer once, reuse parsed layout evidence, and prefer bounded streams or selected-entry extraction over whole-file materialization.

## Known gaps

Unsupported variants and conditional runtime behavior remain explicit warnings or unresolved evidence; they are not inferred from arbitrary strings.

## Implementation mapping

The primary implementations are `PE.psm1`, `PEArchitecture.psm1`, `PEDependency.psm1`, `DotNetHost.psm1`, and `Tauri.psm1` under `Modules/PackageModule/Libraries`.

## Representative fixtures

Use generated malformed fixtures and the behaviorally distinct real installers cited by the focused tests and family workflow.

## Source references

- [PE format](https://learn.microsoft.com/en-us/windows/win32/debug/pe-format)
- [.NET runtime](https://github.com/dotnet/runtime)
- [Tauri code generation](https://github.com/tauri-apps/tauri/tree/dev/crates/tauri-codegen)
- [Tauri runtime assets](https://github.com/tauri-apps/tauri/tree/dev/crates/tauri-utils)
