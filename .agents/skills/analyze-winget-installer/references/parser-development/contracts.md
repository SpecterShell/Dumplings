# Parser contracts

## Streams and bounds

Open an installer once per operation and pass parsed layouts or bounded streams. Restore the position of caller-owned seekable streams and never dispose caller-owned streams. Validate offsets, sizes, counts, alignment, checksums, expanded size, destination paths, and recursion depth before allocation or extraction.

Use typed lists, streaming output, and spill-to-disk seekable streams for large content. Avoid unbounded `ReadAllBytes` and accidental PowerShell `Object[]` materialization.

## Managed helpers

Use C# only for mechanical or measured hot paths such as scanning, checksums, transforms, or PE metadata. Keep format policy and evidence composition readable in PowerShell. Do not add an opaque compiled dependency when existing shared sources or pinned libraries suffice.

## Result contract

Return the same property names for shared semantics: `Path`, `InstallerType`, `ProductCode`, `UpgradeCode`, `DisplayName`, `DisplayVersion`, `Publisher`, `Scope`, `DefaultInstallLocation`, `WritesAppsAndFeaturesEntry`, `AppsAndFeaturesProductCode`, `AppsAndFeaturesInstallerType`, `Warnings`, and `UnresolvedFields`. Keep `Warnings` and `UnresolvedFields` as string arrays, including when empty. Add family-specific evidence without legacy aliases.

## Match and parse failures

Distinguish "not this family" from "matched family but incomplete or malformed." A declared known type that fails family detection is an error. Missing fields or unsupported substructures after a positive match normally produce warnings and preserve existing manifest intent. Generic candidate detection must prefer strict signatures over broad product strings.
