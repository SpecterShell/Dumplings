---
name: author-winget-manifest
description: Author, review, or update Windows Package Manager winget-pkgs YAML manifests from trusted installer evidence. Use when Codex needs to locate official package sources, distinguish homepage downloads from GitHub release assets, create or modify multi-file WinGet manifests, choose manifest fields, handle AppsAndFeaturesEntries, or prepare manifest evidence before Dumplings automation or winget-pkgs submission.
---

# Author Winget Manifest

## Workflow

Use official WinGet docs and repo-local evidence, not memory. Read only the workflow needed for the current stage:

- `references/package-discovery-workflow.md`: existing-package lookup, package identifier design, official source discovery, legitimacy checks, URL stability, release date, and WinGet download compatibility.
- `references/manifest-workflow.md`: installer/default-locale evidence, Apps & Features rules, field priority, defaults, sorting, and manifest shape.
- `references/locale-workflow.md`: default and additional locale fields, translations, documentation, tags, and source conventions.
- `references/submission-workflow.md`: local validation, blocking issues, evidence reporting, and PR scope.

After the manifest is accepted, use `$author-dumplings-task` to create or update
release automation, including electron-updater feeds and versionless URLs.

Use `scripts/Get-WinGetPRValidationLog.ps1` to download `wingetbot` Azure validation artifacts without modifying the pull request.

Use the latest stable manifest schema accepted by winget-pkgs, currently `1.12.0`. Every YAML file must begin with the fixed Dumplings header and the manifest-type-specific, versioned schema directive documented in `references/manifest-workflow.md`. Use the same schema version throughout the submitted manifest set, including when updating manifests that previously used an older schema. The minimum manifest set is the version file, default locale file, and installer file.

Name the version manifest `<PackageIdentifier>.yaml`. Do not add a `.version`
segment to its filename. The `ManifestType: version` field and version-schema
header identify the document type. Follow the complete multi-file naming table
in `references/manifest-workflow.md` for installer and locale files.

Map every dot-delimited `PackageIdentifier` component to a separate repository
directory. For example, store `Google.Chrome.Canary` under
`manifests/g/Google/Chrome/Canary/<PackageVersion>/`, never under a directory
named `Google.Chrome.Canary` or `Chrome.Canary`. This restriction applies to
identifier directories; the leaf version directory retains the exact
`PackageVersion` and may contain dots.

Before recursively searching a local winget-pkgs checkout, query the public source with `winget search`. Once an identifier is known, navigate directly to its manifest path. Reserve broad repository file searches for cases that cannot be resolved through WinGet or direct path lookup.

## Required Evidence

Collect and preserve evidence before writing YAML:

- Official package source and cross-reference proof that the source is legitimate.
- Product developer, brand, ownership, and legal-entity evidence, especially when the product was acquired or rebranded.
- Package-identifier evidence showing whether region, channel, major version,
  edition, architecture, extension/plugin family, or installer versioning requires
  a separate package identity.
- Exact installer URL, redirect chain, dynamic query-parameter assessment, response headers, file size, and SHA256.
- Version source: release tag, page text, installer metadata, MSI/MSIX metadata, or ARP `DisplayVersion`.
- Installer technology and architecture mapping.
- Silent install behavior, supported install modes, elevation behavior, and observed process exit codes, or documented WinGet installer-type defaults.
- ARP entries when static metadata is incomplete or when `AppsAndFeaturesEntries` is needed.
- Release date from the selected GitHub release, official release notes, or the installer's `Last-Modified` header.
- Raw version-specific desktop release notes, the processed verbatim text, and the supporting human-readable `ReleaseNotesUrl`.

Never execute an unknown installer on the host. If static extraction is insufficient, use `$analyze-winget-installer` and run the installer only in an isolated VM or sandbox.

## Authoring Rules

Use official publisher URLs only. Do not use third-party download aggregators, mirrors, repackagers, or search-result download sites as `InstallerUrl`, `PackageUrl`, `PublisherUrl`, release notes, or support links.

Do not stop after satisfying the schema's required fields. Perform a field-by-field completeness pass over the installer and locale schemas and actively search the official product page, support/documentation pages, legal pages, release history, static installer metadata, and compact VM comparison evidence for every applicable optional field. Omit an optional field only after its likely authoritative sources were checked or when the field is intentionally excluded by this workflow. Never invent a value to make a manifest look complete.

Do not author `UnsupportedOSArchitectures` at the moment. Architecture analysis remains evidence for choosing or rejecting an installer entry, but this field must be omitted from new manifests until this project adopts it explicitly.

Do not add `Moniker` automatically when creating a new package. Do not infer it
from the product name, executable name, command alias, or package identifier.
Preserve an established moniker when updating an existing package, but add or
change one only when the task explicitly requires it.

Prefer version-specific installer URLs. Avoid vanity/latest URLs and signed/session query parameters unless no stable version URL exists; if unavoidable, call out the hash-mismatch or expiry risk and consider whether automation should use headers, page metadata, or VM traffic capture to detect changes.

Use `PackageVersion` from the installed ARP version when that is the best user-facing upgrade behavior. If the upstream marketing version differs from ARP `DisplayVersion`, include `AppsAndFeaturesEntries.DisplayVersion` when required by WinGet behavior.

For EXE wrappers around MSI payloads, distinguish manifest `InstallerType` from the ARP entry type. Add `AppsAndFeaturesEntries.InstallerType` when the registry entry type differs from the manifest installer type.

When an official release offers both an InstallShield or Advanced Installer EXE and its direct MSI for the same application, prefer the MSI and do not add the equivalent EXE to the manifest. First confirm that the direct MSI represents the same version, architecture, scope, features, and visible ARP identity. Keep the EXE only when static or VM evidence proves that it supplies required prerequisites, transforms, payload selection, or other behavior that the MSI cannot reproduce directly. Follow the artifact-comparison procedure in `references/package-discovery-workflow.md`.

When an installer writes localized ARP names or publishers, prefer the corresponding additional locale manifest's `PackageName` and `Publisher`. Use `AppsAndFeaturesEntries` for a localized identity only when that locale manifest does not exist or another non-localization ARP override is still required.

For GitHub release sources, inspect the latest non-prerelease release unless the package is explicitly a preview/beta channel. Report repository legitimacy signals: stars, commits, issues, pull requests, archived status, latest release tag, and whether multiple release asset families should map to separate package identifiers.

After all manifest files are authored, parse and serialize the complete set through the logical manifest pipeline as documented in `references/manifest-workflow.md`. Complete-manifest serialization applies cross-document redundancy rules, legal field levels, and schema ordering. Use `Format-WinGetManifest` only for an isolated document that is not yet part of a complete set; it cannot compare installer fields with locale manifests and must not replace the evidence-completeness pass.

Prefer the PackageModule authoring APIs when constructing or editing a complete set. `Get-WinGetInstallerManifestSuggestion` downloads or inspects an installer and returns authoritative applied fields separately from suggestions, warnings, and blocking issues. Reuse that result with `Add-WinGetManifestInstaller`; do not call the analyzer or individual installer-family readers again for the same file. Use the immutable installer, locale, and RFC 6901 value functions for edits, then call `Save-WinGetManifest` so serialization, optimization, offline validation, staging, and atomic replacement run together. The standalone entry point is `Modules/PackageModule/Utilities/WinGetManifest.ps1`.

## Stop Conditions

Stop and warn instead of writing a manifest when:

- The only available installer link is delivered through email after a form submission.
- The only discovered links are unofficial third-party sites.
- Cross-reference checks suggest a fake website, fake repository, or unconnected source.
- The only installer URL contains dynamic keys, signatures, expiring hashes, or session parameters and no stable official fallback URL can be found.
- The installer cannot install silently, requires unapproved scripts, is flagged as malicious/PUA, or cannot be downloaded publicly.
- The package identity, publisher, or installer domain changed suspiciously from existing manifests.

## Source Documents

Use these upstream source documents as primary references:

- [winget-pkgs Authoring](https://github.com/microsoft/winget-pkgs/blob/master/doc/Authoring.md)
- [winget-pkgs Policies](https://github.com/microsoft/winget-pkgs/blob/master/doc/Policies.md)
- [winget-pkgs Validation Failure Guide](https://github.com/microsoft/winget-pkgs/blob/master/doc/ValidationFailureGuide.md)
- [WinGet manifest schema documentation](https://github.com/microsoft/winget-pkgs/tree/master/doc/manifest/schema/1.12.0)
