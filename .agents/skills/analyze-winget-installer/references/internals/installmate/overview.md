# InstallMate parser internals

This reference supports parser implementation and review. For installer analysis and manifest authoring, use the [InstallMate workflow](../../families/installmate/workflow.md).

Read [binary notation](../../parser-development/binary-notation.md), [parser contracts](../../parser-development/contracts.md), and [performance guidance](../../parser-development/performance.md) before changing the parser.

## Supported formats and variants

The parser covers the structured InstallMate variants documented below. Variant-specific evidence must pass the same content-based detection and bounds checks.

## Binary structure

InstallMate appends a Tarma TIZ archive after the PE image and before any Authenticode certificate. The archive wraps a raw-LZMA stream whose first decoded segment is the installer database.

```text
PE launcher
`-- overlay before certificate table
    +-- "tiz1" .. "tiz4"           TIZ header
    +-- format/version/size fields
    +-- raw-LZMA properties at +0x38 (5 bytes)
    `-- raw-LZMA data at +0x3D
        +-- 64-byte "tzf3" segment header
        +-- "tin?" setup database
        `-- repeated file segments
```

```text
Base       Offset  Size  Field
---------  ------  ----  --------------------------------------------
[archive]  0x00    4     Signature: "tiz1" through "tiz4"
[archive]  0x04    2     FormatMajor, uint16 LE
[archive]  0x06    2     FormatMinor, uint16 LE
[archive]  0x08    8     Reserved/observed
[archive]  0x10    8     DeclaredArchiveSize, uint64 LE
[archive]  0x38    5     LZMA properties
[archive]  0x3D    ...   raw-LZMA bytes
[tzf3]     0x08    2     SegmentType, uint16 LE (database = 2)
[tzf3]     0x10    8     SegmentLength, uint64 LE
```

The decoded database signature must match `tin?`. Format 15.11's install-level byte and file records are interpreted only at validated record offsets; older layouts remain conditional. Decompressed bytes, file records, names, archive size, and certificate boundary are bounded.

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

- Modules/PackageModule/Libraries/Installers/InstallMate.psm1

## Representative fixtures

Use generated malformed fixtures and the behaviorally distinct real installers cited by the focused tests and family workflow.

## Source references

- [InstallMate setup command line](https://tarma.com/support/im9/setup/cmdline.htm)
