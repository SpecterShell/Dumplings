# Versionless installer sources

Use installer change tracking when no official feed, page, API, redirect, or browser source exposes the package version. `BitSum.ProcessLasso.Beta` now uses the official JSON feed and should not be copied as a Last-Modified example.

## Task workflow

Populate installer entries, call `CheckInstallerUpdates`, fetch optional metadata only when requested, and finish with `CompleteInstallerUpdates`. Do not add another `Check()` or recreate the submission branches.

```powershell
$this.CurrentState.Installer += [ordered]@{
  InstallerUrl = 'https://example.com/setup.msi'
}
$Result = $this.CheckInstallerUpdates(@{
  Validator = 'ETag'
  ReadVersion = { param($Path, $Installer) Read-ProductVersionFromMsi -Path $Path }
})
if ($Result.NeedsMetadata) {
  # Fetch optional release notes in a separate guarded block.
}
$this.CompleteInstallerUpdates($Result)
```

`CheckInstallerUpdates` prepares `CurrentState`, registers downloads in `InstallerFiles`, and returns a runtime-only result. It never writes state files, sends messages, or submits manifests. It preserves `LastState` and rejects inconsistent versions before applying any candidate. `CompleteInstallerUpdates` belongs to that task instance and is idempotent, including after a partially failed completion. Start a new check explicitly to retry a completed operation; an unfinished check must be completed first.

The result exposes `Outcome`, `NeedsMetadata`, `Accepted`, `ShouldWrite`, `ShouldMessage`, `ShouldSubmit`, and ordered `Artifacts`. Each artifact contains `Key`, `InstallerIndex`, `Downloaded`, `Path`, `Sha256`, `Version`, and `RealVersion`. `Path` is absent after a fast validator match. The result also carries internal candidate, ownership, and hash evidence; never put the result itself in state.

| Outcome | Completion |
| --- | --- |
| `Unchanged` | No write, message, or submission. |
| `EvidenceChanged` | Preserve package, installer, and locale metadata; write refreshed tracking only. |
| `New` | Print and write; no message or submission. |
| `Updated` | Print, write, message, submit. |
| `Rebuilt` | Same version, changed bytes: print, write, message, submit. |
| `Changed` | URL-only change with identical bytes: print, write, message. |
| `Rollbacked` | Warn and retain accepted state; no publishing unless `AllowRollback = $true`. |
| `Forced` | Download and read every artifact; use the normal forced publishing gates. |

Every write/message/submission still respects existing task and runner enablement flags. Rebuilds do not set `IgnorePRCheck`; other-author blocking, identical-PR detection, empty-change rejection, and submission claims remain active. A regressed Last-Modified timestamp triggers hash verification, not a version rollback decision.

## Options

| Option | Contract |
| --- | --- |
| `Validator` | `Auto` (default), `ETag`, `LastModified`, `ContentLength`, `Header`, or `Hash`. |
| `ReadVersion` | Required synchronous scriptblock receiving `(Path, Installer)`. Return one nonempty string or `{ Version; RealVersion }`. Select the actual package version; the engine does not guess a parser property. |
| `HeaderName`, `SelectValue` | Custom checksum header and optional scriptblock receiving its value array and returning one opaque value. Used by `Header`, or first in `Auto`. Return null for unavailable evidence. |
| `Method` | Probe `HEAD` (default) or `GET` without reading a body. Unsupported HEAD responses (405/501) retry GET. |
| `Headers`, `UserAgent`, `Proxy` | Shared probe/download request settings; existing transport retry limits and cancellation still apply. |
| `Installers` | Array of overrides, each with `InstallerIndex` and its changed options. Index selects today's entry; it is not its persistent identity. |
| `Key` | Explicit stable artifact identity for ambiguous or scriptblock/query-based selectors. Use a non-secret label such as `machine-x64`, not a URL or credential. |
| `VersionKey` | Optional stable revision for the reader's external dependencies. Change it when captured values or helper semantics change without changing the reader scriptblock. |
| `AllowRollback` | Explicit opt-in to publishing a lower parsed package version. |
| `LegacyState` | Explicit legacy mapping described below. |
| `Probe`, `Download`, `RequestKey` | Custom endpoint callbacks and a required non-secret request identity revision. |

`Auto` tries a configured checksum header, ETag, Last-Modified, Content-Length, then downloaded SHA256. Explicit modes never silently switch to a weaker fast validator: missing, multiple, or malformed values require a download. ETags and checksum values compare exactly, including case. Dates normalize to UTC and lengths to nonnegative integers. Base64 MD5, CRC64, multipart ETags, and other checksum encodings remain opaque; they are never assigned to `InstallerSha256`.

```powershell
$Result = $this.CheckInstallerUpdates(@{
  Validator = 'Header'
  HeaderName = 'x-goog-hash'
  SelectValue = { param($Values) @($Values) -split ',' | ForEach-Object { $_.Trim() } | Where-Object { $_.StartsWith('md5=') } | ForEach-Object { $_.Substring(4) } }
  ReadVersion = { param($Path, $Installer) Read-ProductVersionFromExe -Path $Path }
})
```

Unchanged dates and lengths do not prove unchanged bytes. Use `Hash` to verify SHA256 every run if the endpoint's validators are unreliable; `-Force` also bypasses all fast checks and version-reader reuse. Successful HTTP status is checked before using headers. Authentication and network failures fail the check; this version sends no conditional HTTP requests.

Delivery Optimization may complete a valid download without exposing HTTP status; that file can still supply SHA256/version evidence, but no header validator is accepted. For its completed ranged transfers, partial-response Content-Length is excluded from tracking.

## Multiple installers and state migration

Every selected installer must resolve to the same `Version` and `RealVersion`. Shared requests download and hash once, but each architecture/scope-specific reader still runs when its bytes or reader change. A staged architecture rollout fails without advancing accepted state. Default keys derive from literal locale, architecture, type, nested type, and scope selectors, excluding URL and list order. Duplicate selectors and query/scriptblock selectors require explicit keys. Changing request settings invalidates fast reuse; differing requests for the same URL are rejected because the existing `InstallerFiles` cache is URL-keyed.

Migrate old fields only through verified mappings. Specify the old installer index when more than one old entry exists. Legacy state has no request or reader identity, so the first migrated check downloads and reads every artifact even if it has a SHA256. The old hash still distinguishes unchanged bytes from rebuilds; subsequent checks can use the new fast path. Missing hashes or ambiguous associations never establish equivalence. Migration uses an explicit validator, not `Auto`.

```powershell
$Result = $this.CheckInstallerUpdates(@{
  Validator = 'LastModified'
  Installers = @(
    @{ InstallerIndex = 0; LegacyState = @{ ValidatorField = 'LastModified'; InstallerIndex = 0 } }
    @{ InstallerIndex = 1; LegacyState = @{ ValidatorField = 'LastModifiedX64'; InstallerIndex = 1 } }
  )
  ReadVersion = { param($Path, $Installer) $Version = (Read-ProductVersionRawFromExe -Path $Path).ToString(); @{ Version = $Version; RealVersion = $Version.Split('.')[0] } }
})
```

Accepted evidence is stored under `InstallerTracking.SchemaVersion = 1` and `InstallerTracking.Artifacts`, keyed by artifact identity. Records contain digests of request/source/reader identity, validator kind/name, up to 16 accepted values for the current SHA256, and resolved versions. Changed bytes reset validator history. Only actual download-response validators are added; missing download validators disable subsequent fast reuse. The explicitly mapped old keys are removed only from the candidate state and persisted through normal enabled writes. Do not rewrite `State.yaml` or historical logs during a script migration.

## Custom endpoints and ownership

`Probe(Uri, Options)` runs synchronously in the task runspace and must return one `{ StatusCode = 200; Headers = <dictionary>; RequestUri = <final URL> }` record. `Download(Uri, DestinationPath, Options)` returns one `{ Path; OwnsFile; Response }` record, with optional `Response` following the same contract. Prefer writing to the supplied resolved destination. A different returned file is borrowed unless `OwnsFile = $true`; callback-supplied hashes are ignored and computed from the actual file. A callback that throws owns cleanup of any extra paths it created; the workflow removes its supplied destination. `RequestKey` must change when external callback request settings change. Do not embed secrets in keys.

Never change the installer inside `ReadVersion`, dispose the retained installer yourself, or store credentials, bodies, responses, or paths in task state. Readers may use local temporary extraction directories with `finally` cleanup. Successful downloads stay registered for manifest parsing until `PackageTask.Dispose`; failed checks remove only workflow-owned files. Verified hashes are reused by manifest updating while the file identity still matches, and are recomputed after a detected file change.

## Examples and remaining migrations

Use `1IC.BPMN-RPAStudio` for MSI/ETag, `AnyDesk.AnyDesk` for Last-Modified, `Ardisk.Ardisk` for Content-Length, `Alibaba.Taobao` and `Bazwise.FolderSizeExplorer` for checksum selection, `ABC.PowerExtension` for GET/user-agent settings, and `Untis.Untis.2026` and `Cjwdev.ADAccountResetTool` for multiple architectures. Keep `Amazon.EC2Launch`'s mutable-to-versioned URL transition bespoke until that behavior is supported explicitly. Inventory candidates with `Utilities/Testing/Get-TaskMechanicsInventory.ps1 -InstallerTracking`; its matches require review and do not authorize bulk migration.
