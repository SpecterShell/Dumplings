# 7z SFX parser internals

This reference supports parser implementation and review. For installer analysis and manifest authoring, use the [7z SFX workflow](../../families/7z-sfx/workflow.md).

Read [binary notation](../../parser-development/binary-notation.md), [parser contracts](../../parser-development/contracts.md), and [performance guidance](../../parser-development/performance.md) before changing the parser.

## Supported formats and variants

The parser covers the structured 7z SFX variants documented below. Variant-specific evidence must pass the same content-based detection and bounds checks.

## Binary structure

The parser treats 7z SFX as a PE launcher, a UTF-8 configuration record, and a standard 7z archive. The configured command determines execution; archive order alone does not.

```text
PE SFX stub
+-- [abs] configuration block (normally within the first 2 MiB)
|   +-- ";!@Install@!UTF-8!" + CR/LF
|   +-- UTF-8 key="value" records
|   `-- ";!@InstallEnd@!"
`-- [abs] 7z archive
    +-- 37 7A BC AF 27 1C          7z signature
    +-- 7z start header/catalog
    `-- packed payload streams

RunProgram / ExecuteFile / AutoInstall -> named archive entry + arguments
```

The configuration delimiters and 7z signature are absolute-file search targets. Values are decoded as UTF-8 and may be repeated. `Expand-SevenZipSfx` passes only the bounded archive range to SharpCompress and applies entry-count, expanded-byte, duplicate-path, and traversal limits.

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

- Modules/PackageModule/Libraries/Installers/SevenZipSfx.psm1

## Representative fixtures

Use generated malformed fixtures and the behaviorally distinct real installers cited by the focused tests and family workflow.

## Source references

- [7-Zip SFX setup source](https://github.com/ip7z/7zip/blob/main/CPP/7zip/Bundles/SFXSetup/SfxSetup.cpp)
