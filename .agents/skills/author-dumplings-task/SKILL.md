---
name: author-dumplings-task
description: Create, review, debug, or refactor Dumplings automation under Tasks, including Config.yaml, Script.ps1, state detection, installer and locale entries, GitHub release asset selection, HTML pages, redirects, Sparkle/electron-updater/Squirrel feeds, versionless URLs tracked by headers and hashes, shared provider tasks, and dry-run validation. Use when the agent needs to automate an existing WinGet package or explain how PackageTask projects task state into updated manifests.
---

# Author Dumplings tasks

## Workflow

1. Confirm the package with `winget search`; Dumplings updates an existing manifest rather than authoring its first version.
2. Read [Task lifecycle](references/task/lifecycle.md), [state, versions, and cache](references/task/state-version-cache.md), and [dependencies and providers](references/task/dependencies-and-providers.md).
3. Read the [manifest update contract](references/manifest/update-contract.md) before selecting installers, locales, queries, or replace mode.
4. Select the relevant source workflow: [source selection](references/sources/selection.md), [pages and releases](references/sources/pages-and-releases.md), [update feeds](references/sources/update-feeds.md), [wrappers and providers](references/sources/wrappers-and-providers.md), or [versionless sources](references/sources/versionless.md).
5. Select the relevant release workflow: [release metadata](references/release/workflow.md), [HTML and Markdown](references/release/html-markdown.md), or [feeds and line-oriented text](references/release/feeds-text.md).
6. Load [`$use-dumplings-functions`](../use-dumplings-functions/SKILL.md) before writing `Script.ps1`, then read only the networking, file, content, feed, browser, or external-module reference required by the task.
7. Find current examples in the [task example index](references/example-index.md). Open each named task directly and verify its assumptions.
8. Persist large records through [Transient evidence](../analyze-winget-installer/references/workflows/evidence.md).

Start manifest feedback early. As soon as the task can produce the required version and installer state, run a dry submission and inspect the generated manifests under `Outputs/WinGet`. Repeat the dry run after installer parsing, locale projection, or release-metadata changes instead of waiting until the task is otherwise finished. Keep these changes in `CurrentState` and the manifest update pipeline; do not edit winget-pkgs YAML from `Script.ps1`.

## Design rules

Keep package-specific discovery in `Script.ps1`; keep reusable mechanics in PackageModule. Create a shared provider when at least three tasks fetch the same source and declare every dependency in `Config.yaml`.

Populate the current version and installer URLs before calling `Check()` once. Keep required installer downloads and `RealVersion` parsing outside recoverable `try`/`catch` blocks. Isolate optional release metadata sources in separate `try`/`catch` blocks.

Select full installers, not updater, delta, or electron-builder portable artifacts. Require unambiguous asset filters and verify architecture from package or binary evidence. Cache reused downloads in `$this.InstallerFiles`.

Let manifest generation download, classify, hash, and parse installers. Do not copy legacy individual `Read-Product*` sequences into new tasks. External `7z.exe` extraction is a task-local last resort for an unsupported custom wrapper and must never become parser or CI infrastructure.

Use response validators only when no official page, feed, API, redirect, or browser source exposes the version. Prefer checksum/hash headers, then `ETag`, `Last-Modified`, and `Content-Length`, and confirm changed content with SHA256. Do not derive `ReleaseTime` from `Last-Modified`; the framework handles that fallback.

Set `ReleaseNotesUrl` only to a human-readable HTTP(S), text, or Markdown source. An API, JSON response, XML appcast, or other machine feed may supply content but not the public URL.

Never execute an installer on the host. Use `$analyze-winget-installer` for static parsing and its VM workflow for unresolved behavior.

## Validation

```powershell
.\Core\Index.ps1 -Name Vendor.Package -ThrottleLimit 1 -PassThru
.\Core\Index.ps1 -Name Vendor.Package -Force -EnableSubmit -Dry -ThrottleLimit 1
Invoke-ScriptAnalyzer .\Tasks\Vendor.Package\Script.ps1
git diff --check
```

Review a new task's read-only result before enabling state writes. Do not enable real submission or messaging during initial validation.
