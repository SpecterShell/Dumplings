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
PE read-only initialized data (`.rdata` in normal MSVC builds)
+-- PHF entry slice
|   +-- name VA          uint32 on PE32, uint64 on PE32+
|   +-- name byte count  pointer-sized unsigned word
|   +-- payload VA       pointer-sized unsigned word
|   `-- stored byte count
+-- rooted UTF-8 names   /index.html, /assets/app.js, ...
+-- Brotli or raw bytes  one mode per generated asset map
`-- Tauri markers        v1 pattern/metadata, v2 internals, bundle type, asset origin

HTML CSP PHF value slice
`-- CspHash::Script records
    +-- discriminant      pointer-sized zero
    +-- hash string VA    pointer-sized absolute VA
    `-- hash byte count   pointer-sized value, exactly 53

PE .taubndl (Tauri 2.7 through 2.9)
`-- Rust &str fat pointer
    +-- tag VA            uint32 on PE32, uint64 on PE32+
    `-- tag byte count    pointer-sized unsigned word, exactly 3
```

The generated asset-map ABI is stable from Tauri 1.0 onward. The asset record is 16 bytes for PE32 x86 and 32 bytes for PE32+ x64 or ARM64. Pointers are absolute image virtual addresses and require image-base and section mapping. PHF keys are unique, so a repeated key splits adjacent generated map slices even when the linker inserts no padding. A CSP map value uses an element count instead of a byte count. Each non-empty element must decode as `CspHash::Script(&str)` and point to a quoted SHA-256 CSP value before the map is cataloged as auxiliary evidence; accept an empty CSP slice only when a matching non-empty HTML record proves the adjacent map boundary. Tauri 1.x injects the `__TAURI_PATTERN__` and `__TAURI_METADATA__` globals; require both marker classes when a custom or URL-backed provider leaves no standard asset map.

Tauri 2.7 through 2.9 placed the runtime bundle type in `.taubndl`. The section contains a Rust string fat pointer to `NSS`, `MSI`, or `UNK` in read-only data; the bundler follows that pointer and patches the three-byte value. Tauri 2.10 replaced this structure with a long `__TAURI_BUNDLE_TYPE_VAR_*` string token referenced by a mutable Rust `&str` in writable initialized data. Follow that fat pointer to distinguish the patched runtime value from match-arm literals retained elsewhere. Resolve the mutable reference independently from the capped marker catalog. When no validated reference is available, accept only one unambiguous token value and report it as a medium-confidence fallback.

## Detection invariants

A marker alone is a routing hint. Accept the family only after its surrounding headers, ranges, counts, and relationships validate.

## Metadata projection

Project only structured metadata and explicit registry behavior into the shared parser result. Preserve conditional or unknown values as warnings or unresolved fields. Tauri evidence is application-framework data nested under `PortableEvidence`, not an installer-family result; its top-level version strings retain the PE `VERSIONINFO` field names.

## Bounds and malformed input

Apply the shared parser bounds to every offset, size, count, decompressed range, destination path, and recursion boundary. Tauri parsing accepts at most 1 GiB of relevant read-only and writable initialized data, scans at most 1 GiB per managed operation, examines at most 67,108,864 potential asset-record offsets and 16,777,216 potential mutable-string offsets, and accepts at most 100,000 candidate records. Brotli validation permits at most 1 GiB expanded per asset and 8 GiB of cumulative stored-input and expanded-output work. CSP validation examines at most 65,536 Rust enum entries per operation. Identifier scanning stops after 128 distinct candidates. Unsafe coherent maps remain visible through `Tauri.AssetMap.UnsafePath`, while extraction stays disabled.

## Performance considerations

Open the executable once per operation, reuse parsed layout evidence, and prefer bounded streams or selected-entry extraction over whole-file materialization. The portable analyzer uses one marker-gate pass instead of scanning once per marker. Brotli measurements are cached by payload offset and stored length, so shared payload ranges are decoded once while logical asset sizes remain distinct.

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
- [Tauri 1.0 generated assets](https://github.com/tauri-apps/tauri/blob/tauri-v1.0.0/core/tauri-codegen/src/embedded_assets.rs)
- [Tauri 1.0 runtime pattern](https://github.com/tauri-apps/tauri/blob/tauri-v1.0.0/core/tauri/scripts/pattern.js)
- [Tauri 1.0 runtime metadata](https://github.com/tauri-apps/tauri/blob/tauri-v1.0.0/core/tauri/src/manager.rs)
- [Tauri 2.9.5 Windows bundle patching](https://github.com/tauri-apps/tauri/blob/tauri-v2.9.5/crates/tauri-bundler/src/bundle/windows/util.rs)
- [Tauri 2.9.5 runtime bundle section](https://github.com/tauri-apps/tauri/blob/tauri-v2.9.5/crates/tauri-utils/src/platform.rs)
- [Tauri 2.10 token-based bundle patching](https://github.com/tauri-apps/tauri/blob/tauri-v2.10.0/crates/tauri-bundler/src/bundle.rs)
