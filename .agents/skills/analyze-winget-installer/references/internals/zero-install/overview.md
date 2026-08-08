# Zero Install parser internals

This reference supports parser implementation and review. For installer analysis and manifest authoring, use the [Zero Install workflow](../../families/zero-install/workflow.md).

Read [binary notation](../../parser-development/binary-notation.md), [parser contracts](../../parser-development/contracts.md), and [performance guidance](../../parser-development/performance.md) before changing the parser.

## Supported formats and variants

The parser covers the structured Zero Install variants documented below. Variant-specific evidence must pass the same content-based detection and bounds checks.

## Binary structure

The bootstrapper is a managed PE. `IMAGE_COR20_HEADER.ResourcesDirectory` points to one CLR resource blob, while rows in the CLR `ManifestResource` table identify records relative to that blob.

```text
managed PE image
+-- DOS/PE headers and section table
+-- IMAGE_COR20_HEADER
|   `-- ResourcesDirectory RVA/Size
+-- CLR metadata streams
|   +-- #Strings heap
|   `-- ManifestResource table
|       +-- Offset:u32 -> relative resource record offset
|       +-- Attributes
|       +-- Name -> #Strings
|       `-- Implementation = nil for embedded data
`-- CLR managed-resource blob
    +-- ResourceLength:u32 LE
    `-- ResourceData[ResourceLength]
```

The application bootstrapper resources consumed by Dumplings are layered as follows:

```text
ZeroInstall.BootstrapConfig.ini (UTF-8)
+-- [global]
|   `-- self_update_uri, feed_mirror, ...
`-- [bootstrap]
    +-- app_uri, app_name, app_args
    +-- integrate_args, catalog_uri
    +-- key_fingerprint
    `-- customizable_store_path, estimated_required_space

ZeroInstall.content.*
+-- signed feed XML or OpenPGP key
+-- icon/archive content
`-- <digest>_<filename>.exe desktop-integration stub
```

All resource offsets are relative to the CLR resource directory until mapped to absolute PE file offsets. Each selected record must fit inside both that directory and the file. Dumplings limits resource count, individual size, cumulative expansion, XML size, and extraction paths.

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

- Modules/PackageModule/Libraries/Installers/ZeroInstall.psm1

## Representative fixtures

Use generated malformed fixtures and the behaviorally distinct real installers cited by the focused tests and family workflow.

## Source references

- [0install/0install-win](https://github.com/0install/0install-win): bootstrap configuration, argument handling, and embedded-content behavior.
- [0install/0install-dotnet](https://github.com/0install/0install-dotnet): feed model, URI escaping, desktop integration, and Windows uninstall-entry behavior.
- [Zero Install feed specification](https://docs.0install.net/specifications/feed/)
- [Zero Install on Windows](https://docs.0install.net/details/windows/)
