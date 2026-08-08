# DeployMaster parser internals

This reference supports parser implementation and review. For installer analysis and manifest authoring, use the [DeployMaster workflow](../../families/deploymaster/workflow.md).

Read [binary notation](../../parser-development/binary-notation.md), [parser contracts](../../parser-development/contracts.md), and [performance guidance](../../parser-development/performance.md) before changing the parser.

## Supported formats and variants

The parser covers the structured DeployMaster variants documented below. Variant-specific evidence must pass the same content-based detection and bounds checks.

## Binary structure

DeployMaster keeps an absolute package locator at file offset `0x80`. The locator protects a bounded package range with expected file size and CRC32. The package begins with LZMA properties followed by a version-dependent control header and compressed metadata/file ranges.

```text
PE setup stub
+-- locator at [abs] 0x80
`-- package at PackageOffset
    +-- 5-byte LZMA properties
    +-- 70/74-byte observed control header
    +-- compressed metadata range
    `-- compressed file-data range
```

```text
Base   Offset  Size  Field
-----  ------  ----  ---------------------------------------------
[abs]  0x80    4     PackageOffset, uint32 LE -> [abs]
[abs]  0x84    4     IntegrityLength, uint32 LE
[abs]  0x88    4     ExpectedCRC32, uint32 LE
[abs]  0x8C    8     ExpectedFileSize, uint64 LE
[abs]  0x94    4     Reserved/observed
```

The CRC covers the declared integrity range, not all bytes to EOF. Current and legacy control headers are selected only after size/range checks. Undocumented control fields remain `Observed`; the parser uses only fields demonstrated by controlled builder samples and rejects truncated or expanding-out-of-bound ranges.

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

- Modules/PackageModule/Libraries/Installers/DeployMaster.psm1

## Representative fixtures

Use generated malformed fixtures and the behaviorally distinct real installers cited by the focused tests and family workflow.

## Source references

- [DeployMaster manual](https://www.deploymaster.com/manual.html)
- [DeployMaster silent installation](https://www.deploymaster.com/manual.html#silent)
