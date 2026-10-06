---
name: author-dumplings-task
description: Create, review, debug, or refactor Dumplings automation under Tasks, including Config.yaml, Script.ps1, state detection, installer and locale entries, GitHub release asset selection, HTML pages, redirects, Sparkle/electron-updater/Squirrel feeds, versionless URLs tracked by headers and hashes, shared provider tasks, and dry-run validation. Use when the agent needs to automate an existing WinGet package or explain how PackageTask projects task state into updated manifests.
---

# Author Dumplings tasks

## Runtime

Run Dumplings module commands and task validation with PowerShell 7.4 or later (`pwsh`). Windows PowerShell 5.1 is unsupported for PackageModule and Core.

## Workflow

1. Confirm the existing package with `winget search`. Have its first manifest version accepted before adding automation.
2. Read [Task lifecycle](references/task/lifecycle.md), [state, versions, and cache](references/task/state-version-cache.md), and [dependencies and providers](references/task/dependencies-and-providers.md).
3. Read the [manifest update contract](references/manifest/update-contract.md) before selecting installers, locales, queries, or replace mode.
4. Select the relevant source workflow: [source selection](references/sources/selection.md), [pages and releases](references/sources/pages-and-releases.md), [update feeds](references/sources/update-feeds.md), [wrappers and providers](references/sources/wrappers-and-providers.md), or [versionless sources](references/sources/versionless.md).
5. Select the relevant release workflow: [release metadata](references/release/workflow.md), [HTML and Markdown](references/release/html-markdown.md), or [feeds and line-oriented text](references/release/feeds-text.md).
6. Load [`$use-dumplings-functions`](../use-dumplings-functions/SKILL.md) before writing `Script.ps1`, then read only the networking, file, content, feed, browser, or external-module reference required by the task.
7. Find current examples in the [task example index](references/example-index.md). Open each named task directly and verify its assumptions.
8. Persist large records through [Transient evidence](../analyze-winget-installer/references/workflows/evidence.md).

Run a dry submission once the task produces the required version and installer state. Inspect the manifests under `Outputs/WinGet` and repeat after parsing, locale, or release-metadata changes. Apply changes through `CurrentState` and the manifest pipeline. Do not edit winget-pkgs YAML from `Script.ps1`.

## Design rules

Keep package-specific discovery in `Script.ps1` and reusable mechanics in PackageModule. Create a shared provider when at least three tasks fetch the same source. Declare every dependency in `Config.yaml`.

Populate the current version and installer URLs before calling `Check()` once. For versionless installers, use `CheckInstallerUpdates` and `CompleteInstallerUpdates` instead of handwritten probe/hash/state branches. Keep required installer downloads and `RealVersion` parsing outside recoverable `try`/`catch` blocks. Isolate optional release metadata sources in separate `try`/`catch` blocks.

Select full installers. Exclude updater, delta, and electron-builder portable artifacts. Use unambiguous asset filters and verify architecture from package or binary evidence. Cache reused downloads in `$this.InstallerFiles`.

Let manifest generation download, classify, hash, and parse installers. Do not copy legacy individual `Read-Product*` sequences into new tasks. External `7z.exe` extraction is a task-local last resort for an unsupported custom wrapper and must never become parser or CI infrastructure.

Use response validators only when official pages, feeds, APIs, redirects, and browser access cannot expose the version. Prefer checksum/hash headers, then `ETag`, `Last-Modified`, and `Content-Length`. Confirm changed content with SHA256. Leave the `Last-Modified` fallback for `ReleaseTime` to the framework.

Set `ReleaseNotesUrl` only to a human-readable HTTP(S), text, or Markdown source. An API, JSON response, XML appcast, or other machine feed may supply content but not the public URL.

Never execute an installer on the host. Use `$analyze-winget-installer` for static parsing and its VM workflow for unresolved behavior.

If host or VM security software flags an executable as a virus or malware, stop work on the affected package and warn the user. Follow [Stop on malware alerts](../analyze-winget-installer/references/workflows/installer-analysis.md#stop-on-malware-alerts).

## Validation

```powershell
.\Core\Index.ps1 -Name Vendor.Package -ThrottleLimit 1 -PassThru
.\Core\Index.ps1 -Name Vendor.Package -Force -EnableSubmit -Dry -ThrottleLimit 1
Invoke-ScriptAnalyzer .\Tasks\Vendor.Package\Script.ps1
git diff --check
```

Review a new task's read-only result before enabling state writes. Do not enable real submission or messaging during initial validation.
