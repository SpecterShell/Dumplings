---
name: author-winget-manifest
description: Author, review, or update Windows Package Manager winget-pkgs YAML manifests from trusted installer evidence. Use when Codex needs to locate official package sources, distinguish homepage downloads from GitHub release assets, create or modify multi-file WinGet manifests, choose manifest fields, handle AppsAndFeaturesEntries, or prepare manifest evidence before Dumplings automation or winget-pkgs submission.
---

# Author Winget Manifest

## Workflow

Use official WinGet docs and repo-local evidence, not memory. Read only the workflow needed for the current stage:

- `references/package-discovery-workflow.md`: official source discovery, legitimacy checks, URL stability, release date, and WinGet download compatibility.
- `references/manifest-workflow.md`: installer/default-locale evidence, Apps & Features rules, field priority, defaults, sorting, and manifest shape.
- `references/locale-workflow.md`: default and additional locale fields, translations, documentation, tags, and source conventions.
- `references/electron-builder-automation.md`: Dumplings tasks driven by electron-builder/electron-updater feeds.
- `references/submission-workflow.md`: local validation, blocking issues, evidence reporting, and PR scope.

Use `scripts/Get-WinGetPRValidationLog.ps1` to download `wingetbot` Azure validation artifacts without modifying the pull request.

Default to multi-file manifests using schema `1.12.0` unless updating an existing package that intentionally uses another accepted schema. The minimum manifest set is the version file, default locale file, and installer file.

Before recursively searching a local winget-pkgs checkout, query the public source with `winget search`. Once an identifier is known, navigate directly to its manifest path. Reserve broad repository file searches for cases that cannot be resolved through WinGet or direct path lookup.

## Required Evidence

Collect and preserve evidence before writing YAML:

- Official package source and cross-reference proof that the source is legitimate.
- Product developer, brand, ownership, and legal-entity evidence, especially when the product was acquired or rebranded.
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

Prefer version-specific installer URLs. Avoid vanity/latest URLs and signed/session query parameters unless no stable version URL exists; if unavoidable, call out the hash-mismatch or expiry risk and consider whether automation should use headers, page metadata, or VM traffic capture to detect changes.

Use `PackageVersion` from the installed ARP version when that is the best user-facing upgrade behavior. If the upstream marketing version differs from ARP `DisplayVersion`, include `AppsAndFeaturesEntries.DisplayVersion` when required by WinGet behavior.

For EXE wrappers around MSI payloads, distinguish manifest `InstallerType` from the ARP entry type. Add `AppsAndFeaturesEntries.InstallerType` when the registry entry type differs from the manifest installer type.

For GitHub release sources, inspect the latest non-prerelease release unless the package is explicitly a preview/beta channel. Report repository legitimacy signals: stars, commits, issues, pull requests, archived status, latest release tag, and whether multiple release asset families should map to separate package identifiers.

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
