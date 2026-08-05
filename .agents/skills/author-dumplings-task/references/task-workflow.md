# Dumplings Task Workflow

## Contents

- [Scope](#scope)
- [1. Confirm The Reference Package](#1-confirm-the-reference-package)
- [2. Create The Task Files](#2-create-the-task-files)
- [3. Write The Ordinary Lifecycle](#3-write-the-ordinary-lifecycle)
- [4. Model The Current State](#4-model-the-current-state)
- [5. Use RealVersion Only When Needed](#5-use-realversion-only-when-needed)
- [6. Share Vendor Data Explicitly](#6-share-vendor-data-explicitly)
- [7. Reuse Downloaded Installers](#7-reuse-downloaded-installers)
- [8. Validate The Task](#8-validate-the-task)

## Scope

A package task discovers the current upstream release and describes it as state.
`PackageTask` owns comparison, persistence, messaging, and submission. The task
script should not merge YAML documents, move manifest fields, or recreate pull
request logic.

Read these implementations when behavior is unclear:

- `Modules/PackageModule/Models/PackageTask.ps1`
- `Modules/PackageModule/Libraries/WinGetSubmission.psm1`
- `Modules/PackageModule/Libraries/WinGetManifestUpdate.psm1`
- `Core/README.md`
- `Modules/PackageModule/README.md`

## 1. Confirm The Reference Package

Resolve the identifier before creating a directory:

```powershell
winget search 'Product Name' --source winget
winget show --id Vendor.Package --exact --source winget
```

Inspect the latest manifest's installer count, architecture, locale, type,
scope, nested files, and Apps & Features shape. A normal submission reads that
latest version as its reference. If the package does not exist yet, author and
submit the package manifests first with `$author-winget-manifest`.

## 2. Create The Task Files

Create this layout:

```text
Tasks/Vendor.Package/
+-- Config.yaml
`-- Script.ps1
```

Start with:

```yaml
Type: PackageTask
WinGetIdentifier: Vendor.Package
Skip: false
```

Do not create `State.yaml` by guessing the current state. After the script works
read-only, run it once with `-EnableWrite`; `PackageTask.Write()` creates a
timestamped `Log_*.yaml` and makes `State.yaml` point to that log.

Common configuration fields:

| Field | Use |
| --- | --- |
| `Type` | Use `PackageTask` for WinGet state and submission; use `SimpleTask` for a shared provider or another task without package state. |
| `WinGetIdentifier` | Existing package read and updated by `Submit()`. |
| `DependsOn` | Explicit provider tasks that must complete first. |
| `CheckVersionOnly` | Ignore installer URL changes during `Check()`; mainly useful for provider-style state. |
| `WinGetReplaceMode` | Replace the effective installer set from task entries instead of updating every existing installer. Use only after reading the matching rules. |
| `RemoveLastVersion` | Explicitly control removal of the previous manifest version. |
| `SkipInstallerAnalysis` | Preserve existing parser-managed metadata while still downloading, hashing, formatting, and validating. Use only for a reviewed parser limitation. |
| `WinGetPackageIdentifier` | Read a reference package whose identifier differs from the task's destination identity. |
| `WinGetNewPackageIdentifier` | Submit to a new identifier, such as a deliberate major-version namespace migration. |
| `Notes` | Add a short operational note to task output. |

Do not set `IgnorePRCheck`, `SkipPRCheck`, or repository overrides as routine
boilerplate. They change submission safety and require a package-specific reason.

## 3. Write The Ordinary Lifecycle

Use this shape when the source exposes a version and installer URLs directly:

```powershell
$Release = Get-UpstreamRelease

$this.CurrentState.Version = [string]$Release.Version
$this.CurrentState.Installer += [ordered]@{
  Architecture = 'x64'
  InstallerUrl = [string]$Release.InstallerUrl
}

switch -Regex ($this.Check()) {
  'New|Changed|Updated' {
    try {
      $this.CurrentState.ReleaseTime = $Release.PublishedAt
    } catch {
      $_ | Out-Host
      $this.Log($_, 'Warning')
    }

    # Download and parse required installer evidence here, outside a recoverable try/catch, when RealVersion or another required value is not available from the discovery source.

    try {
      $FallbackReleaseNotesUrl = [string]$Release.ReleaseNotesUrl
      $this.CurrentState.Locale += [ordered]@{
        Locale = 'en-US'
        Key    = 'ReleaseNotesUrl'
        Value  = [string]::IsNullOrWhiteSpace($FallbackReleaseNotesUrl) ? $null : $FallbackReleaseNotesUrl
      }

      if ($Release.ReleaseNotes) {
        $this.CurrentState.Locale += [ordered]@{
          Locale = 'en-US'
          Key    = 'ReleaseNotes'
          Value  = [string]$Release.ReleaseNotes
        }
      }
    } catch {
      $_ | Out-Host
      $this.Log($_, 'Warning')
    }

    $this.Print()
    $this.Write()
  }
  'Changed|Updated' {
    $this.Message()
  }
  'Updated' {
    $this.Submit()
  }
}
```

PowerShell `switch -Regex` executes every matching clause. An `Updated` result
therefore prints and writes, then messages, then submits. Do not add `break` to
this standard cascade.

`Check()` returns these status tokens:

| Status | Meaning | Ordinary action |
| --- | --- | --- |
| `New` | No prior state exists. | Review and write a baseline; do not submit. |
| `Changed` | Installer URLs changed while the version did not. | Write and notify; investigate before a same-version manifest update. |
| `Updated` | `[ChunkVersion]` says the version increased. | Write, notify, and submit. |
| `Rollbacked` | The discovered version is lower. | Warn and investigate; do not submit unless rollback handling is intentional. |

`-Force` makes `Check()` report `Changed|Updated`, so the normal cascade can
exercise manifest generation. Keep expensive release-note parsing inside the
change branch, after version and installer discovery.

Optional metadata and required installer evidence have different failure
boundaries. Parse each optional source for `ReleaseTime`, `ReleaseNotes`, or
`ReleaseNotesUrl` in its own `try`/`catch`. Keep installer downloading,
`RealVersion`, and other required installer parsing outside those blocks so a
failure prevents `Print()`, `Write()`, and `Submit()`. Follow
[Release Metadata Patterns](release-metadata-patterns.md) when optional fields
come from more than one source.

## 4. Model The Current State

Use these top-level fields:

- `Version`: source version used for state comparison.
- `RealVersion`: optional manifest `PackageVersion` when it must differ from the
  source comparison version. `Xmind.Xmind` demonstrates this split.
- `Installer`: installer-state dictionaries consumed by manifest updating.
- `Locale`: locale field mutations consumed by manifest updating.
- `ReleaseTime`: converted to installer `ReleaseDate` unless an installer entry
  supplies its own date.
- `ETag`, `Hash`, `LastModified`, `ContentLength`, or another task-specific key:
  persisted change evidence only for a last-resort versionless installer source;
  these keys do not become manifest fields.

Validate that every selected asset exists and that all architecture variants
report a consistent release version. Do not silently publish only whichever
asset happened to be first in an API response.

## 5. Use RealVersion Only When Needed

`Version` and `RealVersion` have different responsibilities:

- `Version` is the upstream release or build version stored in task state.
  `PackageTask.Check()` compares it with the previous state's `Version` using
  `[ChunkVersion]`, so it must remain complete, stable, and monotonic enough to
  distinguish upstream releases.
- `RealVersion`, when present, becomes the WinGet manifest `PackageVersion`, the
  output-directory version, and the version used in the submission branch,
  commit, and pull-request lookup. It does not participate in `Check()`.
- When `RealVersion` is absent, submission uses `Version` as `PackageVersion`.

Use `RealVersion` only when the best upstream change-detection version must
differ from the canonical version authored in winget-pkgs. Common cases are:

- A feed or download URL includes an extra build component needed to detect
  every release, while the package intentionally uses the shorter product
  version. `Readdle.Spark`, `Zoom.ZoomRooms`, and `#IQM2.MinuteTraq` use this
  pattern.
- The source version is available before downloading and is suitable for
  `Check()`, but the authoritative manifest version must be read from the changed
  installer. `Xmind.Xmind`, `ZWSOFT.ZWCAD.*`, and
  `Zoom.ZoomVDIUniversalPlugin` demonstrate this split.

For a deterministic source transformation, assign both values before `Check()`:

```powershell
$this.CurrentState.Version = [string]$Release.BuildVersion
$this.CurrentState.RealVersion = $this.CurrentState.Version.Split('.')[0..2] -join '.'
```

When the manifest version is available only from installer analysis, call
`Check()` with the source version first. In its change branch, cache and inspect
the installer and set `RealVersion` outside a recoverable `try`/`catch`. Do so
before optional sources that still need to be fetched and before `Print()`,
`Write()`, or `Submit()`.

Do not use `RealVersion` when `Version` can already be the correct WinGet
`PackageVersion` without missing upstream updates. Never use it to conceal an
uncertain version mapping. If multiple upstream versions intentionally collapse
to one `RealVersion`, expect same-version manifest updates and verify that this
matches the publisher's versioning and winget-pkgs policy.

## 6. Share Vendor Data Explicitly

Use a `SimpleTask` whose name begins with `#` when at least three package tasks
would fetch the same upstream source. With one or two consumers, keep retrieval
in the package tasks instead of adding a provider. Store normalized, preferably
immutable data in `$Global:DumplingsStorage` and declare the provider in every
consumer:

```yaml
Type: PackageTask
DependsOn:
- '#Vendor'
WinGetIdentifier: Vendor.Package
Skip: false
```

`#Argente` fetches architecture-specific catalogs once for the `Argente.*`
tasks. `#JetBrains` batches product/channel API requests into one shared catalog.
Core includes declared dependencies, waits for them, and blocks consumers when a
provider fails. Shared storage does not create an implicit dependency. Sharing a
publisher alone is insufficient; the tasks must reuse the same source response
or source catalog.

## 7. Reuse Downloaded Installers

When a task must inspect an installer to discover its version or confirm a hash,
register the file before parsing it:

```powershell
$Url = $this.CurrentState.Installer[0].InstallerUrl
$this.InstallerFiles[$Url] = $InstallerFile = Get-TempFile -Uri $Url
$this.CurrentState.Version = $InstallerFile | Read-ProductVersionFromExe
```

Do not remove the cached file yourself. `PackageTask.Dispose()` owns cleanup.
Submission reuses it for SHA256 and static parser metadata. If a task supplies
`InstallerSha256` without a cached file, manifest updating can accept the hash
without downloading the installer, so parser-managed fields may not be refreshed.

Prefer one aggregate `Get-<Family>Info` call when family-specific inspection is
unavoidable. Do not call several `Read-*` helpers against the same installer.

If the downloaded file is an unsupported custom EXE wrapper and the required
version or ARP identity exists only in a nested MSI, follow
[Custom EXE Wrappers With Nested MSI](installer-source-patterns.md#custom-exe-wrappers-with-nested-msi).
That fallback keeps the outer file cached, extracts only the verified payload,
and parses the MSI once with `Get-MsiInstallerInfo`.

## 8. Validate The Task

Run the narrowest checks first:

```powershell
.\Core\Index.ps1 -Name Vendor.Package -ThrottleLimit 1 -PassThru
.\Core\Index.ps1 -Name Vendor.Package -Force -EnableSubmit -Dry -ThrottleLimit 1
Invoke-ScriptAnalyzer .\Tasks\Vendor.Package\Script.ps1
git diff --check
```

The first run must discover the expected current release without writing. The
dry submission must download and parse every applicable installer, update the
logical manifest, serialize the multi-file set, and pass offline validation.
Inspect `Outputs/WinGet/<PackageIdentifier>/<PackageVersion>/` rather than
assuming a successful task check proves the generated manifests are correct.
