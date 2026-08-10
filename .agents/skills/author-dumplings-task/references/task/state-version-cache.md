# Task state, versions, and installer cache

## 4. Model The Current State

Use these top-level fields:

- `Version`: source version used for state comparison.
- `RealVersion`: optional manifest `PackageVersion` when it must differ from the source comparison version. `Xmind.Xmind` demonstrates this split.
- `Installer`: installer-state dictionaries consumed by manifest updating.
- `Locale`: locale field mutations consumed by manifest updating.
- `ReleaseTime`: converted to installer `ReleaseDate` unless an installer entry supplies its own date.
- `ETag`, `Hash`, `LastModified`, `ContentLength`, or another task-specific key: persisted change evidence only for a last-resort versionless installer source; these keys do not become manifest fields.

Validate that every selected asset exists and that all architecture variants report a consistent release version. Do not silently publish only whichever asset happened to be first in an API response.

## 5. Use RealVersion Only When Needed

`Version` and `RealVersion` have different responsibilities:

- `Version` is the upstream release or build version stored in task state. `PackageTask.Check()` compares it with the previous state's `Version` using `[ChunkVersion]`, so it must remain complete, stable, and monotonic enough to distinguish upstream releases.
- `RealVersion`, when present, becomes the WinGet manifest `PackageVersion`, the output-directory version, and the version used in the submission branch, commit, and pull-request lookup. It does not participate in `Check()`.
- When `RealVersion` is absent, submission uses `Version` as `PackageVersion`.

Use `RealVersion` only when the best upstream change-detection version must differ from the canonical version authored in winget-pkgs. Common cases are:

- A feed or download URL includes an extra build component needed to detect every release, while the package intentionally uses the shorter product version. `Readdle.Spark`, `Zoom.ZoomRooms`, and `#IQM2.MinuteTraq` use this pattern.
- The source version is available before downloading and is suitable for `Check()`, but the authoritative manifest version must be read from the changed installer. `Xmind.Xmind`, `ZWSOFT.ZWCAD.*`, and `Zoom.ZoomVDIUniversalPlugin` demonstrate this split.

For a deterministic source transformation, assign both values before `Check()`:

```powershell
$this.CurrentState.Version = [string]$Release.BuildVersion
$this.CurrentState.RealVersion = $this.CurrentState.Version.Split('.')[0..2] -join '.'
```

When the manifest version is available only from installer analysis, call `Check()` with the source version first. In its change branch, cache and inspect the installer and set `RealVersion` outside a recoverable `try`/`catch`. Do so before optional sources that still need to be fetched and before `Print()`, `Write()`, or `Submit()`.

Do not use `RealVersion` when `Version` can already be the correct WinGet `PackageVersion` without missing upstream updates. Never use it to conceal an uncertain version mapping. If multiple upstream versions intentionally collapse to one `RealVersion`, expect same-version manifest updates and verify that this matches the publisher's versioning and winget-pkgs policy.

## 7. Reuse Downloaded Installers

When a task must inspect an installer to discover its version or confirm a hash, register the file before parsing it:

```powershell
$Url = $this.CurrentState.Installer[0].InstallerUrl
$this.InstallerFiles[$Url] = $InstallerFile = Get-TempFile -Uri $Url
$this.CurrentState.Version = $InstallerFile | Read-ProductVersionFromExe
```

Do not remove the cached file yourself. `PackageTask.Dispose()` owns cleanup. Submission reuses it for SHA256 and static parser metadata. If a task supplies `InstallerSha256` without a cached file, manifest updating can accept the hash without downloading the installer, so parser-managed fields may not be refreshed.

Prefer one aggregate `Get-<Family>Info` call when family-specific inspection is unavoidable. Do not call several `Read-*` helpers against the same installer.

`Read-ProductVersionFromExe` returns the PE `ProductVersion` verbatim. A .NET informational version can include prerelease or build metadata such as `11.31.22413+d6e55d8f98`; do not assign it directly when the publisher, feed, or ARP uses a different package version. Compare authoritative source and installed-version evidence, keep the complete monotonic source value in `Version` when it is useful for update detection, and set an evidence-backed `RealVersion` for the WinGet `PackageVersion`. Do not strip arbitrary suffixes automatically.

If the downloaded file is an unsupported custom EXE wrapper and the required version or ARP identity exists only in a nested MSI, follow [Custom EXE wrappers with nested MSI](../sources/wrappers-and-providers.md#custom-exe-wrappers-with-nested-msi). That fallback keeps the outer file cached, extracts only the verified payload, and parses the MSI once with `Get-MsiInstallerInfo`.
