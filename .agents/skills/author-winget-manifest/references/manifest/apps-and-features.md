# Apps and Features metadata

## AppsAndFeaturesEntries

Add `AppsAndFeaturesEntries` only when WinGet would otherwise parse or match an ARP value differently from the manifest identity. Relevant differences include:

- ARP `DisplayVersion` is missing, unsortable, contains marketing text, or differs from `PackageVersion`.
- ARP `DisplayName` differs materially from `PackageName` in every authored locale after WinGet name normalization.
- ARP `Publisher` differs materially from `Publisher` in every authored locale.
- The manifest `InstallerType` differs from the ARP entry technology, such as an EXE wrapper installing an MSI.
- The effective ARP installer type differs from the outer installer type.

Rules:

- Omit `DisplayVersion` when it is identical to `PackageVersion`.
- Omit `DisplayName` when the only difference from `PackageName` is a version string that WinGet normalization removes. For example, `7pace Timetracker 1.37.55247` and `7pace Timetracker` normalize to the same package name.
- Retain `DisplayName` when meaningful text survives normalization or when an architecture-bearing ARP name is required for more accurate architecture correlation.
- When an ARP `DisplayName` or `Publisher` is localized, write the evidenced value as `PackageName` or `Publisher` in the corresponding locale manifest instead of duplicating it in `AppsAndFeaturesEntries`. Retain the Apps & Features value only when that locale manifest does not exist.
- Keep `ProductCode` at installer level. Do not duplicate the same value in `AppsAndFeaturesEntries.ProductCode`.
- When an installer has exactly one Apps & Features entry and its `ProductCode` equals the installer-level `ProductCode`, remove the entry-level duplicate.
- Independently of ProductCode, remove a sole entry's `DisplayName` or `Publisher` when WinGet normalization makes it equal to `PackageName` or `Publisher` in the default or any additional locale manifest. `Optimize-WinGetManifest` performs these comparisons against every authored localization.
- In a sole Apps & Features entry, remove `InstallerType` when it equals the effective installer type, including a ZIP's `NestedInstallerType`. Retain it when the visible ARP technology genuinely differs from the installer payload type.
- Delete the sole Apps & Features entry if no meaningful fields remain after these independent checks.
- When an `AppsAndFeaturesEntries` item is needed and either the outer `InstallerType` or that item's `InstallerType` is `msi`, `wix`, or `burn`, always include its `UpgradeCode`.
- Include `InstallerType` inside `AppsAndFeaturesEntries` only when it differs from the installer node type or is needed to disambiguate.
- If a wrapper writes an EXE ARP entry and hides the MSI ARP entry, model the visible ARP entry, not only the embedded MSI.
- Do not retain an entry merely because an older manifest included redundant fields; remove it when installer-level and locale fields now match the visible ARP identity and no required mismatch remains.

WinGet's source index stores normalized package names and publishers from the default localization and every additional localization in independent lookup tables. Consequently, locale-manifest identity values participate in ARP matching without being repeated in `AppsAndFeaturesEntries`; name and publisher redundancy must be evaluated independently.

## Existing Packages

When updating an existing package:

- Read the previous version's manifests before changing field style.
- Preserve established package identifier, casing, locale set, moniker, tags, and installer grouping unless evidence shows they are wrong.
- Compare new installer domains, product codes, upgrade codes, ARP names, and publisher values to previous manifests.
- Treat domain changes and identity changes as security-sensitive and report them before proceeding.
- Block updates that move an existing package from an official publisher domain to an unaffiliated GitHub mirror, personal account, third-party CDN, or aggregator unless the publisher explicitly cross-links that source.
- Do not invent a higher `PackageVersion` from third-party sites when the publisher does not publish that version. This can force `winget upgrade` to run an untrusted installer under an existing package identifier.
