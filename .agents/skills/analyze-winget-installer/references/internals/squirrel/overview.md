# Squirrel and Velopack parser internals

This reference supports parser implementation and review. For installer analysis and manifest authoring, use the [Squirrel and Velopack workflow](../../families/squirrel/workflow.md).

Read [binary notation](../../parser-development/binary-notation.md), [parser contracts](../../parser-development/contracts.md), and [performance guidance](../../parser-development/performance.md) before changing the parser.

## Supported formats and variants

The parser covers the structured Squirrel and Velopack variants documented below. Variant-specific evidence must pass the same content-based detection and bounds checks.

## Binary structure

Squirrel.Windows stores an update ZIP in PE `DATA` resource ID `131`. Velopack stores a referenced nupkg/ZIP range in the launcher bundle header. These outer structures identify the family; the location of the nuspec inside the resulting ZIP does not. A bounded ZIP fallback can recover package metadata, but it cannot select either launcher contract.

```text
Squirrel PE setup
`-- .rsrc/DATA/#131
    `-- ZIP
        +-- *.nupkg -> ZIP -> *.nuspec
        `-- RELEASES / package payload

Velopack PE setup
`-- bundle locator
    +-- PayloadOffset, int64 LE      16 bytes before signature
    +-- PayloadLength, int64 LE
    +-- 32-byte Velopack signature
    `-- [PayloadOffset, Length] -> nupkg/ZIP

.NET single-file application using Squirrel libraries
`-- .NET bundle header and file-entry table
    +-- Squirrel.dll / NuGet.Squirrel.dll
    `-- no nupkg, nuspec, or RELEASES entry -> reject as a Squirrel setup
```

Velopack's signature is `94 F0 B1 7B 68 93 E0 29 37 EB 34 EF 53 AA E7 D4 2B 54 F5 70 7E F5 D6 F5 78 54 98 3E 5E 94 ED 7D`. Resource and locator ranges are absolute after PE RVA mapping. The parser requires a valid ZIP/nupkg and nuspec metadata, bounds candidate count/range extraction, and does not classify from `--silent` or a bare ZIP signature alone.

## Family selection routes

| Route | Required structure | Result | Confidence | Launcher policy |
| --- | --- | --- | --- | --- |
| `SquirrelPeResource` | Valid `DATA/#131` PE resource range and package metadata | `Squirrel` | High | Squirrel switches |
| `VelopackBundle` | Valid bundle signature, preceding offset/length, bounded package range, and package metadata | `Velopack` | High | Velopack switches |
| `EmbeddedZipFallback` | Generic embedded ZIP containing valid nuspec metadata | `Squirrel/Velopack` | Low | Omitted |
| `ConflictingAuthoritativeRoutes` | Both authoritative routes validate | `Squirrel/Velopack` | Low | Omitted |

Candidate provenance must survive ZIP and nuspec parsing. A nested `.nupkg` does not by itself mean Squirrel.Windows, and a root nuspec does not by itself mean Velopack. When both authoritative routes validate, the parser retains package identity, reports both evidence records, and leaves launcher-specific fields unresolved.

## Command-line contracts

Squirrel.Windows accepts `-s` and `--silent`. Dumplings uses the canonical long form and maps both WinGet `Silent` and `SilentWithProgress` to `--silent`. The confirmed Squirrel profile does not expose setup-level installation-directory or log-path overrides.

Velopack and its Clowd.Squirrel predecessor use the same bundle signature and accept `-s`/`--silent`, `-t`/`--installto <DIR>`, and `-l`/`--log <FILE>`. Dumplings emits the long forms, including `SilentWithProgress: --silent`, `InstallLocation: --installto "<INSTALLPATH>"`, and `Log: --log "<LOGPATH>"`.

## Detection invariants

Accept an exact family only when its outer structure and package payload both validate. Treat an isolated marker as a routing hint and preserve generic package evidence as an unresolved family. A validated .NET bundle file table containing Squirrel libraries without package metadata is a runtime-client false positive, not an alternate setup layout.

## Metadata projection

Project only structured metadata and explicit registry behavior into the shared parser result. Preserve conditional or unknown values as warnings or unresolved fields.

## Bounds and malformed input

Apply the shared parser bounds to every offset, size, count, decompressed range, destination path, and recursion boundary. Reject malformed input deterministically.

## Performance considerations

Open the installer once, reuse parsed layout evidence, and prefer bounded streams or selected-entry extraction over whole-file materialization.

## Known gaps

Custom runtime bootstrappers that contain Squirrel libraries but obtain package metadata after launch cannot provide static nuspec identity through this parser. Generic ZIP-only candidates can expose nuspec identity but still require outer-launcher validation before assigning switches. Both cases require VM evidence for unresolved behavior.

## Implementation mapping

- Modules/PackageModule/Libraries/Installers/Squirrel.psm1

## Representative fixtures

Use generated malformed fixtures and the behaviorally distinct real installers cited by the focused tests and family workflow.

## Source references

- [Squirrel.Windows](https://github.com/Squirrel/Squirrel.Windows)
- [Velopack](https://github.com/velopack/velopack)
- [.NET single-file bundle manifest](https://github.com/dotnet/dotnet/tree/main/src/runtime/src/installer/managed/Microsoft.NET.HostModel/Bundle)
