# Parser contracts

## Streams and bounds

Open an installer once per operation and pass parsed layouts or bounded streams. Restore the position of caller-owned seekable streams and never dispose caller-owned streams. Validate offsets, sizes, counts, alignment, checksums, expanded size, destination paths, and recursion depth before allocation or extraction.

Use typed lists, streaming output, and spill-to-disk seekable streams for large content. Avoid unbounded `ReadAllBytes` and accidental PowerShell `Object[]` materialization.

## Managed helpers

Use C# only for mechanical or measured hot paths such as scanning, checksums, transforms, or PE metadata. Keep format policy and evidence composition readable in PowerShell. Do not add an opaque compiled dependency when existing shared sources or pinned libraries suffice.

## Result contract

Return the same property names for shared semantics: `Path`, `InstallerType`, `ProductCode`, `UpgradeCode`, `DisplayName`, `DisplayVersion`, `Publisher`, `Scope`, `DefaultInstallLocation`, `WritesAppsAndFeaturesEntry`, `AppsAndFeaturesProductCode`, `AppsAndFeaturesInstallerType`, `Diagnostics`, and `UnresolvedFields`. Keep `Diagnostics` as an object array and `UnresolvedFields` as a string array, including when empty. Add family-specific evidence without legacy aliases.

Each diagnostic contains `Id`, `Source`, `Message`, `Kind`, `Areas`, `AffectedFields`, `Evidence`, `Scenario`, `Level`, and `IsBlocking`. A parser sets the first seven fields and leaves the last three empty. Use a stable semantic ID such as `NSIS.Extraction.ExternalPayloadRequired`; do not derive caller behavior from message text. `Kind` describes the condition, while `Areas` and `AffectedFields` describe its impact. Keep recommended actions in `Suggestions` or `SuggestedNextSteps`.

Resolve diagnostics only at a workflow boundary. `FullAnalysis` reports complete static-analysis concerns, `Detection` separates rejected hints from confirmed structural failures, `ManifestAuthoring` marks missing required authoring evidence as blocking, `ManifestUpdate` promotes only fields being refreshed plus installability and security concerns, and `Extraction` treats malformed or unsafe output as blocking. Direct `Get-*Info` functions must not log.

## Match and parse failures

Distinguish "not this family" from "matched family but incomplete or malformed." A declared known type that fails family detection produces a blocking `Mismatch` diagnostic. Missing fields or unsupported substructures after a positive match preserve existing manifest intent and return field-specific diagnostics. Generic candidate detection must prefer strict signatures over broad product strings.
