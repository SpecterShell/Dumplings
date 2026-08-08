# MSIX and AppX parser internals

This reference supports parser implementation and review. For installer analysis and manifest authoring, use the [MSIX and AppX workflow](../../families/msix-appx/workflow.md).

Read [binary notation](../../parser-development/binary-notation.md), [parser contracts](../../parser-development/contracts.md), and [performance guidance](../../parser-development/performance.md) before changing the parser.

## Supported formats and variants

The parser covers the structured MSIX and AppX variants documented below. Variant-specific evidence must pass the same content-based detection and bounds checks.

## Binary structure

AppX/MSIX packages are ZIP-based Open Packaging Convention containers. The package manifest defines identity and dependencies; the block map hashes payload blocks; `AppxSignature.p7x` carries the package signature. Bundles contain a bundle manifest plus nested package files.

```text
ZIP/OPC package
+-- [Content_Types].xml
+-- AppxManifest.xml                identity, architecture, capabilities
+-- AppxBlockMap.xml                per-file block hashes
+-- AppxSignature.p7x               PKCS #7 signature
`-- application payload files

ZIP/OPC bundle
+-- AppxMetadata/AppxBundleManifest.xml
+-- AppxBlockMap.xml / AppxSignature.p7x
`-- nested *.appx / *.msix packages selected by architecture/resource
```

The ZIP central directory supplies entry ranges; OPC relationships and manifests supply meaning. Dumplings detects the type from required entry names rather than the filename extension, validates safe bounded ZIP entries, reads XML declarations, hashes the signature entry for `SignatureSha256`, and separately verifies that Windows reports a valid trusted signature. `.appinstaller` is XML update metadata pointing to a package/bundle URL and is not itself an accepted WinGet installer container.

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

- Modules/PackageModule/Libraries/Installers/MSIX.psm1

## Representative fixtures

Use generated malformed fixtures and the behaviorally distinct real installers cited by the focused tests and family workflow.

## Source references

- [MSIX Packaging](https://github.com/microsoft/msix-packaging)
