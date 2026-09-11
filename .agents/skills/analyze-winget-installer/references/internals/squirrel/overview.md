# Squirrel and Velopack parser internals

This reference supports parser implementation and review. For installer analysis and manifest authoring, use the [Squirrel and Velopack workflow](../../families/squirrel/workflow.md).

Read [binary notation](../../parser-development/binary-notation.md), [parser contracts](../../parser-development/contracts.md), and [performance guidance](../../parser-development/performance.md) before changing the parser.

## Supported formats and variants

The parser covers the structured Squirrel and Velopack variants documented below. Variant-specific evidence must pass the same content-based detection and bounds checks.

## Binary structure

Squirrel.Windows stores an update ZIP in PE `DATA` resource ID `131`. A short-lived Clowd.Squirrel design stores UTF-16 metadata in `DATA` resource IDs `200`, `201`, `203`, and `204`, with the nupkg bytes in ID `205`. Later Clowd.Squirrel and Velopack launchers share a signed offset/length locator. The outer structure identifies the package route, while source-defined launcher markers distinguish the legacy C++ setup from the Rust Velopack setup. The location of the nuspec inside the ZIP does not identify the launcher. A bounded ZIP fallback can recover package metadata, but it cannot select a launcher contract.

```text
Squirrel PE setup
+-- .rsrc/DATA/#131
|   `-- ZIP
|       +-- *.nupkg -> ZIP -> *.nuspec
|       `-- RELEASES / package payload
`-- .rsrc/FLAGS/#132 -> UTF-16 .NET Framework selector

Transitional Clowd.Squirrel PE setup
+-- .rsrc/DATA/#200 -> AppId, UTF-16
+-- .rsrc/DATA/#201 -> AppFriendlyName, UTF-16
+-- .rsrc/DATA/#203 -> RequiredFrameworks, UTF-16
+-- .rsrc/DATA/#204 -> BundledPackageName, UTF-16
`-- .rsrc/DATA/#205 -> nupkg -> *.nuspec

Signed Clowd.Squirrel or Velopack PE setup
`-- bundle locator
    +-- PayloadOffset, int64 LE      16 bytes before signature
    +-- PayloadLength, int64 LE
    +-- 32-byte signed-bundle signature
    `-- [PayloadOffset, Length] -> nupkg/ZIP

.NET single-file application using Squirrel libraries
`-- .NET bundle header and file-entry table
    +-- Squirrel.dll / NuGet.Squirrel.dll
    `-- no nupkg, nuspec, or RELEASES entry -> reject as a Squirrel setup
```

The signed-bundle signature is `94 F0 B1 7B 68 93 E0 29 37 EB 34 EF 53 AA E7 D4 2B 54 F5 70 7E F5 D6 F5 78 54 98 3E 5E 94 ED 7D`. It first appeared in Clowd.Squirrel, so it cannot by itself prove the Rust Velopack command line. The Rust route is identified from the stable `VELOPACK_FIRSTRUN` lifecycle marker inside the bounded launcher range; `installtoDIR` and `logFILE` independently corroborate the source-defined CLI options without depending on localized help descriptions. Resource and locator ranges are absolute after PE RVA mapping. The parser requires a valid ZIP/nupkg and nuspec, checks every bounded locator candidate instead of trusting the first signature, and does not classify from `--silent` or a bare ZIP signature alone.

## Family selection routes

| Route | Required structure | Result | Confidence | Launcher policy |
| --- | --- | --- | --- | --- |
| `SquirrelPeResource` | Valid `DATA/#131` PE resource range and package metadata | `Squirrel` | High | Squirrel switches |
| `ClowdSquirrelPeResource` | Valid `DATA/#205` nupkg plus consistent package metadata | `Velopack` | High | Clowd.Squirrel resource-generation switches |
| `VelopackBundle` | Valid signed locator, preceding offset/length, bounded package range, and package metadata | `Velopack` | High | Selected by `LauncherGeneration` |
| `EmbeddedZipFallback` | Generic embedded ZIP containing valid nuspec metadata | `Squirrel/Velopack` | Low | Omitted |
| `ConflictingAuthoritativeRoutes` | Multiple authoritative routes validate with different launcher contracts | Common family when identities agree, otherwise `Squirrel/Velopack` | Low | Intersection of capabilities for one family; otherwise omitted |

Candidate provenance must survive ZIP and nuspec parsing. A nested `.nupkg` does not by itself mean Squirrel.Windows, and a root nuspec does not by itself mean Velopack. `LauncherGeneration` is `Squirrel.Windows`, `Clowd.Squirrel.Resource`, `Clowd.Squirrel.Bundle`, or `Velopack` when the source generation can be established. When authoritative routes conflict, the parser retains package identity, reports both evidence records, and leaves launcher-specific fields unresolved.

## Command-line contracts

Squirrel.Windows accepts `-s` and `--silent`. Dumplings uses the canonical long form and maps both WinGet `Silent` and `SilentWithProgress` to `--silent`. The confirmed Squirrel profile does not expose setup-level installation-directory or log-path overrides.

The transitional Clowd.Squirrel resource setup and signed C++ setup have source-backed silent handling. The signed C++ setup forwards remaining arguments to its updater, but that forwarding is not proof that its outer setup implements the later Velopack `--installto` or `--log` contract. The parser therefore emits only `Silent` and `SilentWithProgress` for both Clowd generations.

The Rust Velopack setup is identified within the launcher range by the source-defined `VELOPACK_FIRSTRUN` lifecycle marker. The compiled Clap identifiers `installtoDIR` and `logFILE` independently gate `--installto <DIR>` and `--log <FILE>`. Only that generation emits `InstallLocation: --installto "<INSTALLPATH>"` and `Log: --log "<LOGPATH>"`, alongside the silent mappings.

## Detection invariants

Accept an exact family only when its outer structure and package payload both validate. Treat an isolated marker as a routing hint and preserve generic package evidence as an unresolved family. A validated .NET bundle file table containing Squirrel libraries without package metadata is a runtime-client false positive, not an alternate setup layout. Reject conflicting authoritative identities rather than choosing the first result. Routes that agree on identity but disagree on projected nuspec metadata are rejected as ambiguous package content. When authoritative routes agree on family and package identity but disagree on launcher generation, retain the family and only the command-line capabilities common to all validated routes. Clowd `DATA/#205` metadata comes from resources with the same PE language ID as the package resource.

## Metadata projection

Project only structured metadata and explicit registry behavior into the shared parser result. Current Velopack nuspec projection includes `machineArchitecture`, `runtimeDependencies`, `mainExe`, `os`, `rid`, `osMinVersion`, `channel`, `shortcutLocations`, `shortcutAumid`, release notes, release-notes HTML, and splash progress color; the parser also accepts the historical `shortcutAmuid` spelling. List-valued metadata is normalized to arrays while the `Raw` properties retain the source strings. Architecture aliases are normalized for WinGet, minimum OS versions are validated, and unsupported values remain diagnostic evidence. Rust Velopack packages must provide the source-required `id`, nonzero SemVer with UInt64 numeric components, and a safe relative Windows `mainExe` path before the route is accepted.

Squirrel.Windows `FLAGS/#132` stores the UTF-16 framework selector consumed by `FxHelper`. Recognized values range from `net45` through `net48`; the launcher treats an unknown value as `net45`, so the parser returns both the raw resource and the effective requirement. Absence remains unresolved rather than being replaced with a guessed prerequisite.

For Rust Velopack packages, `mainExe` selects one exact `lib/app/<mainExe>` archive entry. The parser opens that entry through a bounded seekable stream, requires a valid PE image, and records its machine, managed status, target framework when readable, and imported DLL names. The PE architecture corroborates `machineArchitecture` and an architecture-bearing RID. A disagreement leaves `Architecture` unresolved and prevents payload architecture evidence from being projected into a WinGet suggestion.

## Bounds and malformed input

Apply the shared parser bounds to every offset, size, count, decompressed range, destination path, and recursion boundary. The parser caps locator scans, archive entries, nuspec size, nested package buffering, and main-executable inspection; it uses subtraction-based range checks to avoid integer overflow. Nuspec XML prohibits DTD processing and external resolution. The locator defaults are eight signatures and a 16 MiB launcher prefix. Callers can raise both through validated parameters for a known outlier. Reject malformed input deterministically, and do not downgrade a recognized authoritative route to generic ZIP evidence when its package fails validation.

## Performance considerations

Open the installer once, reuse its PE layout, and parse resource, signed-bundle, and generic ZIP candidates through bounded streams. Nested nupkg entries use the shared seekable-stream helper with memory and total-size limits, avoiding whole-installer copies.

## Known gaps

Custom runtime bootstrappers that contain Squirrel libraries but obtain package metadata after launch cannot provide static nuspec identity through this parser. Generic ZIP-only candidates can expose nuspec identity but still require outer-launcher validation before assigning switches. A custom or stripped Rust launcher that omits the source markers is conservatively treated as the legacy signed generation and receives no modern-only switches.

## Implementation mapping

- Modules/PackageModule/Libraries/Installers/Squirrel.psm1
- Modules/PackageModule/Tests/Support/New-SquirrelHistoricalFixtures.ps1

## Representative fixtures

Use generated malformed fixtures and behaviorally distinct real installers. The focused suite includes controlled application-complete fixtures for the Squirrel.Windows 1.9.1 `DATA/#131` and Clowd.Squirrel 2.7.98-pre `DATA/#205` layouts. Run `./Modules/PackageModule/Tests/Support/New-SquirrelHistoricalFixtures.ps1 -FixtureRoot ../Dumplings-TestFixtures` from the repository root to compose them without launching vendor code. The script uses official NuGet launcher packages and hash-pinned application packages committed upstream; their tests skip when the external builder cache is absent. The suite also includes upstream migration binaries built with Squirrel.Windows 2.0.1, Clowd.Squirrel 2.11.1, a later Clowd.Squirrel generation, Velopack 0.0.84, and Velopack 1.2.98, plus current signed Clowd and Rust Velopack installers.

## Source references

- [Squirrel.Windows](https://github.com/Squirrel/Squirrel.Windows)
- [Velopack](https://github.com/velopack/velopack)
- [Squirrel.Windows `DATA/#131` writer](https://github.com/Squirrel/Squirrel.Windows/blob/6867fa20fc5228ec23383ae6d1c993598655730e/src/WriteZipToSetup/WriteZipToSetup.cpp)
- [Clowd.Squirrel resource bundle metadata](https://github.com/velopack/velopack/blob/d713596bd891a69c238d3cdd613ef7cff4314726/src/Squirrel/Internal/BundledSetupInfo.cs)
- [Clowd.Squirrel signed bundle introduction](https://github.com/velopack/velopack/tree/01aab4d7637a55a8bdde81b841f688bac643ead1/src/Squirrel.Shared)
- [Rust Velopack setup introduction](https://github.com/velopack/velopack/blob/0c87c94b4518e1ddaf0ec449d31db5e11c37d3a7/src/bins/src/setup.rs)
- [.NET single-file bundle manifest](https://github.com/dotnet/dotnet/tree/main/src/runtime/src/installer/managed/Microsoft.NET.HostModel/Bundle)
