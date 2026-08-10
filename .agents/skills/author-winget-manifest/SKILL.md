---
name: author-winget-manifest
description: Author, review, or update Windows Package Manager winget-pkgs YAML manifests from trusted installer evidence. Use when the agent needs to locate official package sources, distinguish homepage downloads from GitHub release assets, create or modify multi-file WinGet manifests, choose manifest fields, handle AppsAndFeaturesEntries, or prepare manifest evidence before Dumplings automation or winget-pkgs submission.
---

# Author WinGet manifests

## Runtime

Run Dumplings module commands and host-side skill scripts with PowerShell 7.4 or later (`pwsh`). Windows PowerShell 5.1 is unsupported unless a specific self-contained guest collector says otherwise.

## Workflow

Read only the references needed for the current stage:

- Package selection: [Identity](references/package/identity.md), [official source discovery](references/package/source-discovery.md), [artifact selection](references/package/artifact-selection.md), and [release evidence](references/package/release-evidence.md).
- Manifest construction: [Model and files](references/manifest/model-and-files.md), [installer fields](references/manifest/installer-fields.md), [dependencies](references/manifest/dependencies.md), [defaults and return codes](references/manifest/defaults-and-return-codes.md), [Apps and Features](references/manifest/apps-and-features.md), and [formatting and validation](references/manifest/formatting-and-validation.md).
- Localization: [Locale model](references/locale/model.md), [locale identity](references/locale/identity.md), and [locale content](references/locale/content-and-resources.md).
- Completion: [Submission](references/submission/workflow.md).
- Shared helper APIs: use [`$use-dumplings-functions`](../use-dumplings-functions/SKILL.md) for source retrieval, redirects, response decoding, temporary files, HTML or Markdown processing, YAML, and browser evidence.
- Installer-family guidance: start with the analyzer's [installer-family route table](../analyze-winget-installer/references/workflows/installer-analysis.md), then open the selected family workflow for static parser commands, switches, ARP ownership, and VM exceptions.
- Large working records: [Transient evidence](../analyze-winget-installer/references/workflows/evidence.md).

Use `$analyze-winget-installer` for installer evidence and `$author-dumplings-task` after the first package version is accepted.

## Incremental authoring

Create the working multi-file manifest as soon as the package identifier, package version, default locale, and enough installer evidence to satisfy the required schema fields are known. For an existing package, create the new version leaf from the logical model at this point. Do not postpone file creation until source research, static analysis, locale research, and VM validation are all finished.

Update and save the working manifest after each meaningful evidence milestone: artifact selection and hashing, installer-family parsing, locale discovery, release-note discovery, and VM validation. Read the current logical model before the next mutation, inspect each diff, and omit unresolved optional fields rather than inserting guesses or placeholders. When handling several packages, create and maintain each package's working manifest while researching it instead of collecting evidence for the whole batch and writing all YAML at the end. Format and validate the complete set after the initial save and after structural changes; run the final strict review before submission.

## Non-negotiable rules

Use official publisher sources. Do not use download aggregators, mirrors, repackagers, or search-result download sites. Cross-check websites and repositories before trusting either.

Never execute an unknown installer on the host. Stop when the only link is login-required, email-delivered, unofficial, suspicious, session-bound without a stable fallback, or when the installer cannot be installed unattended. A blocking Windows Security driver-publisher consent dialog also rejects the installer; follow the [VM procedure](../analyze-winget-installer/references/workflows/vm-validation.md#reject-blocking-driver-trust-prompts).

Do not invent publisher identities, legal names, URLs, release notes, versions, registry metadata, or switches. Search all likely authoritative sources before omitting an applicable optional field.

Current authoring uses schema `1.12.0` and the fixed Dumplings headers.

Do not add `Moniker` automatically. Do not author `UnsupportedOSArchitectures` at present. Omit known installer switches, modes, and return codes when they equal WinGet defaults.

## Output discipline

Operate on the complete logical manifest model throughout authoring. Serialize each evidence-backed revision with `Save-WinGetManifest` or the documented model APIs, then validate offline. Use `Format-WinGetManifest` only for an isolated document; it cannot perform cross-document optimization or prove missing evidence.

Preserve full source, installer, VM, and validation records in the transient evidence tree. Report only the decisions, unresolved warnings, and evidence path in the task.
