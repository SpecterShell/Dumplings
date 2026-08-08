# Actual Installer parser internals

This reference supports parser implementation and review. For installer analysis and manifest authoring, use the [Actual Installer workflow](../../families/actual-installer/workflow.md).

Read [binary notation](../../parser-development/binary-notation.md), [parser contracts](../../parser-development/contracts.md), and [performance guidance](../../parser-development/performance.md) before changing the parser.

## Supported formats and variants

The parser covers the structured Actual Installer variants documented below. Variant-specific evidence must pass the same content-based detection and bounds checks.

## Binary structure

Actual Installer uses a PE stub with one or more physically embedded standard ZIP ranges. Dumplings validates each candidate by its own central directory and selects the archive containing `aisetup.ini`; it does not treat the last `PK` byte sequence as sufficient evidence.

```text
PE launcher
+-- ZIP range 0 (optional payload archive)
|   +-- 50 4B 03 04                local-file records
|   +-- compressed payload entries
|   `-- 50 4B 05 06                matching EOCD
`-- ZIP range N (setup metadata)
    +-- aisetup.ini                product/switch/ARP settings
    +-- *ai.lng                    language resources
    `-- optional helper payloads
```

ZIP offsets are absolute file offsets; ZIP-local offsets remain relative to that embedded ZIP range. Every selected range must have a self-consistent end-of-central-directory record and bounded entries. The parser assigns no invented meaning to other embedded ZIPs until their catalogs identify them.

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

- Modules/PackageModule/Libraries/Installers/ActualInstaller.psm1

## Representative fixtures

Use generated malformed fixtures and the behaviorally distinct real installers cited by the focused tests and family workflow.

## Source references

Use the source references in the mapped module headers and its focused tests. Add upstream references here when new behavior is grounded.
