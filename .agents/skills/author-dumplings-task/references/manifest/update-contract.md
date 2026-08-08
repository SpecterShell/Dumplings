# Task State To WinGet Manifest Contract

## Contents

- [Data Flow](#data-flow)
- [Installer Entry Matching](#installer-entry-matching)
- [Update Mode And Replace Mode](#update-mode-and-replace-mode)
- [Explicit Installer Overrides](#explicit-installer-overrides)
- [Download And Parser Updates](#download-and-parser-updates)
- [Release Date](#release-date)
- [Locale Entries](#locale-entries)
- [Post-Processing](#post-processing)

## Data Flow

```text
Script.ps1
  `-- CurrentState.Version / Installer[] / Locale[] / ReleaseTime
          |
          v
PackageTask.Submit()
  `-- Send-WinGetManifest
        +-- read latest reference manifest
        +-- Update-WinGetManifest
        |    +-- match installer entries
        |    +-- download or reuse cached installers
        |    +-- hash and statically parse installers
        |    `-- apply locale entries
        +-- optimize field levels and redundant ARP fields
        +-- serialize and validate
        `-- write dry output or submit a pull request
```

Task state is an update description, not a replacement YAML manifest. Existing author intent remains the baseline unless an entry explicitly overrides it or a trusted parser refreshes a field that already exists.

## Installer Entry Matching

Without `Query`, these fields select an existing effective installer:

- `InstallerLocale`
- `Architecture`
- `InstallerType`
- `NestedInstallerType`
- `Scope`

They are matching keys and are not copied back as overrides. All matching keys present in the task entry must exist with the same case-sensitive value in the old effective installer. The last matching task entry wins. Every old installer must match an entry, or update mode throws.

Example for two existing WiX entries:

```powershell
$this.CurrentState.Installer += [ordered]@{
  Architecture  = 'x86'
  InstallerType = 'wix'
  InstallerUrl  = $Release.X86Url
}
$this.CurrentState.Installer += [ordered]@{
  Architecture  = 'x64'
  InstallerType = 'wix'
  InstallerUrl  = $Release.X64Url
}
```

The architecture and type identify the old entries; `InstallerUrl` is applied. The updater removes the old hash and release date, downloads each new URL, and recomputes them.

Use `Query` when the selector differs from the values to write:

```powershell
$this.CurrentState.Installer += [ordered]@{
  Query        = [ordered]@{ Architecture = 'x64'; Scope = 'machine' }
  InstallerUrl = $Release.X64Url
}
```

A dictionary `Query` requires exact values. A scriptblock `Query` receives an old installer and must return a truthy value. When `Query` exists, other fields are writes rather than implicit selectors, so include only intentional changes. `RawTherapee.RawTherapee` demonstrates a dictionary query.

## Update Mode And Replace Mode

Normal mode iterates over every old installer and updates it from the last matching current-state entry. It preserves the installer set and is safest for routine release updates.

`WinGetReplaceMode: true` iterates over current-state entries and builds the new installer set from matching old entries. Use it when architectures or installer families can be added or removed, and supply explicit `Query` values whenever the correct base entry is not unambiguous. `Xmind.Xmind` demonstrates a release whose ARM64 entry is retained only when its version matches x64.

## Explicit Installer Overrides

Any non-`Query` key must be a valid installer schema property. Explicit values take priority over parser output. Use this for source-authoritative data or an intentional manifest change, not to repeat data the installer parser can read.

Useful explicit cases include:

- `NestedInstallerFiles` when a release changes the path inside an archive.
- `InstallerSwitches` when the new release changes verified behavior.
- `ProductCode` or `AppsAndFeaturesEntries` only when authoritative source or VM evidence is stronger than the parser and the existing manifest must change.
- `ReleaseDate` when one installer has a date different from `ReleaseTime`.

Do not put task-only keys beside installer schema fields. Persist ETags and other change evidence at the top level of `CurrentState`.

## Download And Parser Updates

For an installer without a supplied hash, manifest generation downloads it with the WinGet-compatible downloader, computes `InstallerSha256`, and reuses the file for analysis. A file registered in `$this.InstallerFiles` takes priority and avoids a second download.

For ZIP installers, analysis extracts only the first authored `NestedInstallerFiles` path rather than expanding the whole archive. Known types (`msi`, `wix`, `burn`, `nullsoft`, `inno`, `msix`, and `appx`) are checked against their declared type before parsing. A definitive mismatch throws; incomplete metadata warns and preserves existing fields. Generic `exe` parsing is best effort.

Parser metadata refreshes these authored fields when they already exist and the task did not override them:

- installer `ProductCode`
- `InstallationMetadata.DefaultInstallLocation`
- existing `AppsAndFeaturesEntries` values such as `DisplayName`, `DisplayVersion`, `Publisher`, `ProductCode`, and `UpgradeCode`
- MSIX/AppX identity, signature, minimum OS, platform, and capability fields
- an existing non-package `MinimumOSVersion` when the parser proves it

The updater may remove redundant `AppsAndFeaturesEntries.InstallerType` and structurally empty values. It does not infer or rewrite `Scope`, `ElevationRequirement`, `Protocols`, `FileExtensions`, `Dependencies`, locale `PackageName`, or locale `Publisher`. Those remain author-controlled because one artifact cannot safely prove every scope, dependency, first-run association, or localized identity.

The parser also does not add every absent optional field. Author the desired manifest shape first; subsequent task runs keep parser-owned fields current.

## Release Date

`CurrentState.ReleaseTime` is formatted as `yyyy-MM-dd` and copied to every installer entry unless that entry supplies `ReleaseDate`. If neither source is available, the downloader may use a valid installer `Last-Modified` header. Task scripts must not duplicate this fallback by assigning that header to `CurrentState.ReleaseTime`.

```powershell
$this.CurrentState.ReleaseTime = $Release.published_at.ToUniversalTime()
```

## Locale Entries

Each locale entry has this contract:

```powershell
[ordered]@{
  Locale = 'en-US'       # optional
  Key    = 'ReleaseNotes'
  Value  = $ReleaseNotes
}
```

- `Key` and `Value` are required; `Locale` is optional.
- With `Locale`, the entry applies only to an existing locale document with that exact locale. It does not create a new locale manifest.
- Without `Locale`, the entry applies to every locale document whose schema accepts that key. Use this only for genuinely shared values.
- A scalar or collection replaces the field after schema validation.
- `$null` removes the field.
- A scriptblock transforms each existing value and receives that value through the pipeline.

Targeted release notes:

```powershell
$this.CurrentState.Locale += [ordered]@{
  Locale = 'en-US'
  Key    = 'ReleaseNotes'
  Value  = $HtmlNodes | Get-TextContent | Format-Text
}
```

Targeted release-notes URL:

```powershell
$this.CurrentState.Locale += [ordered]@{
  Locale = 'en-US'
  Key    = 'ReleaseNotesUrl'
  Value  = $Release.html_url
}
```

Shared release-notes URL:

```powershell
$this.CurrentState.Locale += [ordered]@{
  Key   = 'ReleaseNotesUrl'
  Value = $Release.html_url
}
```

Transform an existing field during an intentional identifier migration:

```powershell
$this.CurrentState.Locale += [ordered]@{
  Locale = 'en-US'
  Key    = 'PackageName'
  Value  = { $_ -replace '2025', '2026' }
}
```

Before applying locale entries, the updater removes old `ReleaseNotes`; a task must provide notes for the new release or leave them absent. It updates an existing copyright year, normalizes tags, and keeps `Moniker` only in the default locale. Installer parser names and publishers never overwrite locale `PackageName` or `Publisher`.

## Post-Processing

After installer and locale updates, `Optimize-WinGetManifest` removes redundant common `InstallerLocale`, ProductCode, InstallerType, normalized name, and publisher values where allowed. Serialization then moves common installer values to manifest level, preserves installer-level overrides, sorts fields, and emits the fixed current headers. Offline validation runs before dry output or submission.
