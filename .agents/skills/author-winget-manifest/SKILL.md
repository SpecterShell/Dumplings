---
name: author-winget-manifest
description: Author, review, or update Windows Package Manager winget-pkgs YAML manifests from trusted installer evidence. Use when the agent needs to locate official package sources, distinguish homepage downloads from GitHub release assets, create or modify multi-file WinGet manifests, choose manifest fields, handle AppsAndFeaturesEntries, or prepare manifest evidence before Dumplings automation or winget-pkgs submission.
---

# Author WinGet manifests

## Runtime

Run Dumplings module commands and host-side skill scripts with PowerShell 7.4 or later (`pwsh`). Windows PowerShell 5.1 is unsupported unless a specific self-contained guest collector says otherwise.

## Workflow

Read the references needed for the current stage.

- Package selection: [Identity](references/package/identity.md), [source-index duplicate lookup](references/package/source-index-lookup.md), [official source discovery](references/package/source-discovery.md), [artifact selection](references/package/artifact-selection.md), and [release date evidence](references/package/release-date.md).
- Manifest construction: [Model and files](references/manifest/model-and-files.md), [installer fields](references/manifest/installer-fields.md), [dependencies](references/manifest/dependencies.md), [defaults and return codes](references/manifest/defaults-and-return-codes.md), [Apps and Features](references/manifest/apps-and-features.md), and [formatting and validation](references/manifest/formatting-and-validation.md).
- Localization: [Locale model](references/locale/model.md), [locale identity](references/locale/identity.md), and [locale content and release notes](references/locale/content-and-resources.md).
- Completion: [Submission](references/submission/workflow.md) and [validation logs from PR checks](references/submission/validation-logs.md).
- Shared helper APIs: use [`$use-dumplings-functions`](../use-dumplings-functions/SKILL.md) for source retrieval, redirects, response decoding, temporary files, HTML or Markdown processing, YAML, and browser evidence.
- Installer-family guidance: start with the analyzer's [installer-family route table](../analyze-winget-installer/references/workflows/installer-analysis.md), then open the selected family workflow for static parser commands, switches, ARP ownership, and VM exceptions.
- Large working records: [Transient evidence](../analyze-winget-installer/references/workflows/evidence.md).

Use `$analyze-winget-installer` for installer evidence and `$author-dumplings-task` after the first package version is accepted.

## Incremental authoring

Create and save a working multi-file manifest once the identifier, version, default locale, and required installer fields are known. For an existing package, use its logical model to create the new version leaf. Continue research and VM validation against this draft.

Save the manifest as artifact selection, parsing, locale research, release notes, and VM validation establish new facts. Read the current logical model before each edit and inspect the diff. Omit unresolved optional fields. When handling a batch, maintain each package's draft throughout its research. Format and validate the complete set after the initial save and structural changes, then perform a strict final review before submission.

## Non-negotiable rules

Use official publisher sources. Do not use download aggregators, mirrors, repackagers, or search-result download sites. Cross-check websites and repositories before trusting either.

Never execute an unknown installer on the host. Before finalizing or submitting an entry, complete [VM validation](../analyze-winget-installer/references/workflows/vm-validation.md) with the exact artifact and authored switches. Stop if the only link requires login, is delivered by email, is unofficial or suspicious, or is session-bound without a stable fallback. Reject installers that cannot run unattended, including those blocked by a [Windows Security driver-publisher consent dialog](../analyze-winget-installer/references/workflows/vm-validation.md#reject-blocking-driver-trust-prompts).

If host or VM security software flags an executable as a virus or malware, stop the affected package workflow immediately and warn the user. Follow [Stop on malware alerts](../analyze-winget-installer/references/workflows/installer-analysis.md#stop-on-malware-alerts).

Do not invent publisher identities, legal names, URLs, release notes, versions, registry metadata, or switches. Search all likely authoritative sources before omitting an applicable optional field.

Current authoring uses schema `1.12.0` and the fixed Dumplings headers.

Do not add `Moniker` automatically. Do not author `UnsupportedOSArchitectures` at present. Omit known installer switches, modes, and return codes when they equal WinGet defaults.

## Output discipline

Use the complete logical model throughout authoring. Save each evidence-backed revision with `Save-WinGetManifest` or the documented model APIs, then validate offline. Reserve `Format-WinGetManifest` for isolated documents. It cannot optimize across documents or establish missing evidence.

Preserve full source, installer, VM, and validation records in the transient evidence tree. Report only the decisions, unresolved diagnostics, and evidence path in the task.
