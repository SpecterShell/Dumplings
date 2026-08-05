---
name: author-dumplings-task
description: Create, review, debug, or refactor Dumplings automation under Tasks, including Config.yaml, Script.ps1, state detection, installer and locale entries, GitHub release asset selection, HTML pages, redirects, Sparkle/electron-updater/Squirrel feeds, versionless URLs tracked by headers and hashes, shared provider tasks, and dry-run validation. Use when Codex needs to automate an existing WinGet package or explain how PackageTask projects task state into updated manifests.
---

# Author Dumplings Task

## Workflow

1. Confirm the package already exists with `winget search` and inspect its latest
   manifests. Dumplings updates an existing reference manifest; it is not a
   substitute for authoring the first package version.
2. Read [Task Workflow](references/task-workflow.md) before creating
   `Config.yaml`, `Script.ps1`, or initial state.
3. Read [Manifest Update Contract](references/manifest-update-contract.md) before
   choosing installer selectors, `Query`, locale entries, cached files, or
   `WinGetReplaceMode`.
4. Read only the applicable recipe in
   [Installer Source Patterns](references/installer-source-patterns.md) and
   [Release Metadata Patterns](references/release-metadata-patterns.md). Use
   source behavior, not a similar package name, to choose a template.
5. Use `$author-winget-manifest` for package-source legitimacy, manifest-field,
   locale, and submission policy. Use `$analyze-winget-installer` when installer
   metadata cannot be established without static parsing.
6. Run the task read-only, seed or refresh state only after reviewing the result,
   then exercise dry manifest generation.

## Required Design

- Keep package-specific network discovery in `Script.ps1`; keep reusable feed,
  text, installer, and manifest mechanics in PackageModule.
- Decode web responses with `Read-ResponseContent` when their text may use a
  BOM or a non-default encoding. Parse the returned string rather than reading
  `RawContentStream` with an assumed encoding.
- Create a shared vendor provider when at least three tasks fetch the same
  upstream source. Keep retrieval local for one or two consumers, and declare
  the provider through `DependsOn` for every shared consumer.
- Populate `$this.CurrentState.Version` and every required installer URL before
  calling `$this.Check()`. Call `Check()` once in the ordinary lifecycle.
- Use `[ordered]` installer and locale dictionaries so state and diagnostics are
  deterministic.
- Select the full installer intended for a fresh installation. Reject updater,
  delta, auto-update, and electron-builder portable artifacts unless the WinGet
  package intentionally represents that artifact. Verify derived full-installer
  URLs before recording them.
- Filter release assets by every distinguishing fact exposed by the source and
  require an unambiguous result. Map explicit source architecture names such as
  `x86_64`, `amd64`, and `aarch64` to WinGet architecture values. Treat bare
  `arm` and `win32` as candidate filters only, then inspect the installer or
  nested binaries before assigning `Architecture`; `win64` identifies x64.
- Cache a downloaded installer in `$this.InstallerFiles[$InstallerUrl]` when the
  same file is used for version or hash detection. PackageTask disposes cached
  files and manifest generation can reuse them for static analysis.
- Use task-side `7z.exe` extraction only as a fallback for a custom EXE wrapper
  that PackageModule cannot parse. Select the exact nested MSI, call
  `Get-MsiInstallerInfo` once, and reuse its result. See
  [Custom EXE Wrappers With Nested MSI](references/installer-source-patterns.md#custom-exe-wrappers-with-nested-msi).
- Let manifest generation download, hash, classify, and parse installers. Do not
  repeat ProductCode, UpgradeCode, Apps & Features, or association parsing in the
  task unless the source exposes authoritative data that the parser cannot.
- Keep required installer downloads and `RealVersion` parsing outside
  recoverable `try`/`catch` blocks. Handle `ReleaseTime`, `ReleaseNotes`, and
  `ReleaseNotesUrl` only after a possible change is established, with each
  optional source isolated in its own `try`/`catch`.
- Replace an existing `ReleaseNotesUrl` with a trustworthy general changelog URL
  or a null locale entry before fallible version-specific logic. Preserve
  release-note source text through the project's HTML or Markdown conversion
  pipeline rather than summarizing it.
- Use response validators only as a last resort when no official API, feed,
  page, redirect, or browser-accessible source exposes the version and it must
  be extracted from the downloaded installer. Prefer a content-hash or checksum
  header, then `ETag`, `Last-Modified`, and `Content-Length`. Treat the value as
  a download prefilter, never as the package version or manifest hash, and
  confirm changed content with SHA256.
- Never execute a downloaded installer on the host. Dynamic checks belong in the
  isolated VM workflow.

## Review Existing Tasks Carefully

Task scripts are production evidence, not immutable templates. Reuse the part
named by the example index and re-check it against current infrastructure.
Legacy tasks may manually set hashes, call individual installer readers, invoke
`7z.exe`, omit `$this.InstallerFiles`, or select artifact combinations that no
longer match current authoring policy. Do not copy those details into new tasks.

## Validation

Run from the Dumplings root:

```powershell
# Discover the current state without writes or submission.
.\Core\Index.ps1 -Name Vendor.Package -ThrottleLimit 1 -PassThru

# Generate and validate updated manifests without opening a pull request.
.\Core\Index.ps1 -Name Vendor.Package -Force -EnableSubmit -Dry -ThrottleLimit 1

Invoke-ScriptAnalyzer .\Tasks\Vendor.Package\Script.ps1
git diff --check
```

For a new task, review the read-only `New` result, then use `-EnableWrite` to
create the timestamped state log and `State.yaml` link. Do not enable real
messaging or submission during initial validation.
