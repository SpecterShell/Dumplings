# Task lifecycle

## Scope

A package task discovers the current upstream release and describes it as state. `PackageTask` owns comparison, persistence, messaging, and submission. The task script should not merge YAML documents, move manifest fields, or recreate pull request logic.

Read these implementations when behavior is unclear:

- `Modules/PackageModule/Models/PackageTask.ps1`
- `Modules/PackageModule/Libraries/WinGet/WinGetSubmission.psm1`
- `Modules/PackageModule/Libraries/WinGet/WinGetManifestUpdate.psm1`
- `Core/README.md`
- `Modules/PackageModule/README.md`

## 1. Confirm The Reference Package

Resolve the identifier before creating a directory:

```powershell
winget search 'Product Name' --source winget
winget show --id Vendor.Package --exact --source winget
```

Inspect the latest manifest's installer count, architecture, locale, type, scope, nested files, and Apps & Features shape. A normal submission reads that latest version as its reference. If the package does not exist yet, author and submit the package manifests first with `$author-winget-manifest`.

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

Do not create `State.yaml` by guessing the current state. After the script works read-only, run it once with `-EnableWrite`; `PackageTask.Write()` creates a timestamped `Log_*.yaml` and makes `State.yaml` point to that log.

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

Do not set `IgnorePRCheck`, `SkipPRCheck`, or repository overrides as routine boilerplate. They change submission safety and require a package-specific reason.

## 3. Write The Ordinary Lifecycle

Use this shape when the source exposes a version and installer URLs directly:

```powershell
$Release = Invoke-GitHubApi -Uri 'https://api.github.com/repos/owner/repository/releases/latest'

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

PowerShell `switch -Regex` executes every matching clause. An `Updated` result therefore prints and writes, then messages, then submits. Do not add `break` to this standard cascade.

`Check()` returns these status tokens:

| Status | Meaning | Ordinary action |
| --- | --- | --- |
| `New` | No prior state exists. | Review and write a baseline; do not submit. |
| `Changed` | Installer URLs changed while the version did not. | Write and notify; investigate before a same-version manifest update. |
| `Updated` | `[ChunkVersion]` says the version increased. | Write, notify, and submit. |
| `Rollbacked` | The discovered version is lower. | Warn and investigate; do not submit unless rollback handling is intentional. |

`-Force` makes `Check()` report `Changed|Updated`, so the normal cascade can exercise manifest generation. Keep expensive release-note parsing inside the change branch, after version and installer discovery.

Optional metadata and required installer evidence have different failure boundaries. Parse each optional source for `ReleaseTime`, `ReleaseNotes`, or `ReleaseNotesUrl` in its own `try`/`catch`. Keep installer downloading, `RealVersion`, and other required installer parsing outside those blocks so a failure prevents `Print()`, `Write()`, and `Submit()`. Follow [Release metadata workflow](../release/workflow.md) when optional fields come from more than one source.

## 8. Validate The Task

Run the narrowest checks first:

```powershell
.\Core\Index.ps1 -Name Vendor.Package -ThrottleLimit 1 -PassThru
.\Core\Index.ps1 -Name Vendor.Package -Force -EnableSubmit -Dry -ThrottleLimit 1
Invoke-ScriptAnalyzer .\Tasks\Vendor.Package\Script.ps1
git diff --check
```

The first run must discover the expected current release without writing. The dry submission must download and parse every applicable installer, update the logical manifest, serialize the multi-file set, and pass offline validation. Inspect `Outputs/WinGet/<PackageIdentifier>/<PackageVersion>/` rather than assuming a successful task check proves the generated manifests are correct.
