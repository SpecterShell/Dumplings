# Qt Installer Framework parser internals

This reference supports parser implementation and review. For installer analysis and manifest authoring, use the [Qt Installer Framework workflow](../../families/qt-installer-framework/workflow.md).

Read [binary notation](../../parser-development/binary-notation.md), [parser contracts](../../parser-development/contracts.md), and [performance guidance](../../parser-development/performance.md) before changing the parser.

## Supported formats and variants

The parser covers the structured Qt Installer Framework variants documented below. Variant-specific evidence must pass the same content-based detection and bounds checks.

## Binary structure

Qt IFW appends binary content to the launcher and terminates it with a source-defined segment table and magic cookie. Segment pairs are `[offset:int64 LE][length:int64 LE]`, initially relative to the binary-content base and then mapped to absolute file ranges.

```text
PE installerbase launcher
`-- appended binary content
    +-- resource collection segment
    +-- N metadata resource segments
    +-- operations segment
    +-- resource/package archive data
    `-- trailer + cookie
```

```text
Trailer ending at EndOfBinaryContent (cookie end)
Field order                         Size
---------------------------------  ----
ResourceCollection range           16 bytes
MetaResource range[MetaCount]      16 bytes each
Operations range                   16 bytes
ResourceCount                      int64 LE
BinaryContentSize                  int64 LE
MagicMarker                        int64 LE
MagicCookie                        8 bytes
```

Cookies are `F8 68 D6 99 1C 0A 63 C2` for installer content and `F9 68 D6 99 1C 0A 63 C2` for DAT content. Supported marker values identify installer `0x12023233`, uninstaller `0x12023234`, updater `0x12023235`, and package manager `0x12023236`. Metadata may be Qt RCC data with 14-byte tree nodes; package payloads are standard 7z archives. Counts, segment arithmetic, RCC names, resources, archives, and expanded output are bounded before extraction.

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

- Modules/PackageModule/Libraries/Installers/QtInstallerFramework.psm1

## Representative fixtures

Use generated malformed fixtures and the behaviorally distinct real installers cited by the focused tests and family workflow.

## Source references

- [Qt Installer Framework](https://github.com/qtproject/installer-framework)
