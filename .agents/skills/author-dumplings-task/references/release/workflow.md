# Release metadata workflow

## Failure Boundary And Ordering

`ReleaseTime`, `ReleaseNotes`, and `ReleaseNotesUrl` improve a manifest but do not determine whether the installer update is valid. Handle each optional source in its own `try`/`catch`, log failures as warnings, and continue with the update. Several fields obtained from one response may share one block. Data fetched from another endpoint belongs in another block.

Version, `RealVersion`, installer URLs, installer downloading, and required installer parsing are not optional. Keep them outside recoverable `try`/`catch` blocks so a failure stops the task. A `try`/`finally` used only for disposing a stream or extraction directory is safe because it does not suppress the error.

Inside a `New|Changed|Updated` branch, use this order:

1. Parse optional metadata already available from the discovery source, such as `ReleaseTime`, in a source-specific `try`/`catch`.
2. Download and parse required installer evidence, including `RealVersion`, without a catch that converts failure into a warning.
3. Fetch and parse every additional optional source in its own `try`/`catch`.
4. Print and write state only after the required installer work succeeds.

`ADInstruments.LabChart.DeviceEnabler.BloodFlowMeter` demonstrates this order. Its provider object supplies the release date, the MSI supplies `RealVersion`, and a separate support page supplies `ReleaseNotesUrl`.

## Canonical Change Branch

```powershell
switch -Regex ($this.Check()) {
  'New|Changed|Updated' {
    try {
      # Optional metadata from the discovery response fetched before Check().
      $this.CurrentState.ReleaseTime = $Release.PublishedAt.ToUniversalTime()
    } catch {
      $_ | Out-Host
      $this.Log($_, 'Warning')
    }

    # Required installer evidence must fail the task when it cannot be read.
    $Url = $this.CurrentState.Installer[0].InstallerUrl
    $this.InstallerFiles[$Url] = $InstallerFile = Get-TempFile -Uri $Url
    $InstallerInfo = Get-MsiInstallerInfo -Path $InstallerFile
    if ([string]::IsNullOrWhiteSpace($InstallerInfo.DisplayVersion)) {
      throw 'The installer did not provide the required real version.'
    }
    $this.CurrentState.RealVersion = $InstallerInfo.DisplayVersion

    try {
      $FallbackReleaseNotesUrl = [string]$Release.ChangelogUrl
      # Keep a useful general changelog while looking for a version-specific URL.
      $this.CurrentState.Locale += [ordered]@{
        Locale = 'en-US'
        Key    = 'ReleaseNotesUrl'
        Value  = [string]::IsNullOrWhiteSpace($FallbackReleaseNotesUrl) ? $null : $FallbackReleaseNotesUrl
      }

      $Document = Invoke-WebRequest -Uri $ReleaseNotesPage | ConvertFrom-Html
      $Link = $Document.SelectSingleNode('//a[contains(., "Release Notes")]')
      if ($Link) {
        $this.CurrentState.Locale += [ordered]@{
          Locale = 'en-US'
          Key    = 'ReleaseNotesUrl'
          Value  = Join-Uri $ReleaseNotesPage $Link.Attributes['href'].Value
        }
      } else {
        $this.Log("No ReleaseNotesUrl (en-US) for version $($this.CurrentState.Version)", 'Warning')
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

Replace `Get-MsiInstallerInfo` with the applicable aggregate parser. Do not call several `Read-*` functions against the same file.

## Release Time

Assign `ReleaseTime` only after `Check()` reports a possible change. If the discovery response was fetched before `Check()`, parse its date in the first optional block without requesting the source again:

```powershell
try {
  $this.CurrentState.ReleaseTime = $Release.published_at.ToUniversalTime()
} catch {
  $_ | Out-Host
  $this.Log($_, 'Warning')
}
```

If the release date requires another endpoint, fetch and parse that endpoint in a separate block. Do not include later release-note requests in the same block. Preserve source precision when practical; manifest generation formats the value as `yyyy-MM-dd`.

Do not derive `ReleaseTime` from the installer's HTTP `Last-Modified` header. Manifest updating reads that header and supplies the fallback `ReleaseDate` automatically when no authoritative task or installer date exists. Set `ReleaseTime` only from release metadata whose meaning is established, such as a release API timestamp, appcast publication date, or versioned changelog entry. `CurrentState.LastModified` may still track changes to a versionless URL, but it must not be copied into `CurrentState.ReleaseTime`.

## Clear Stale Release Fields

Manifest updating removes old `ReleaseNotes` before applying locale entries, but an existing `ReleaseNotesUrl` remains unless the task explicitly removes it. Before fallible parsing, assign either a trustworthy general release-notes URL or `$null`. Prefer a fallback URL when the publisher maintains a changelog page that remains useful even without a version anchor. Use `$null` when no such page exists.

`ReleaseNotesUrl` must open a human-readable HTTP(S) resource: an HTML release or changelog page, a plain-text document, or a Markdown document. Do not use JSON or XML endpoints, appcasts, GitHub API URLs, or other API-like machine-readable sources for this manifest field. A task may retrieve those sources to populate `ReleaseNotes`; it should then link to the corresponding human-facing release or changelog page, use a trustworthy general fallback, or clear `ReleaseNotesUrl` when no human-readable source exists.

`Anthropic.ClaudeCode` assigns the changelog first, then upgrades it to the current version's anchor after parsing the raw Markdown:

```powershell
try {
  $ReleaseNotesUrl = 'https://github.com/anthropics/claude-code/blob/HEAD/CHANGELOG.md'
  $this.CurrentState.Locale += [ordered]@{
    Locale = 'en-US'
    Key    = 'ReleaseNotesUrl'
    Value  = $ReleaseNotesUrl
  }

  $ReleaseNotesObject = Invoke-RestMethod -Uri 'https://raw.githubusercontent.com/anthropics/claude-code/HEAD/CHANGELOG.md' | Convert-MarkdownToHtml
  $ReleaseNotesTitleNode = $ReleaseNotesObject.SelectSingleNode("/h2[contains(text(), '$($this.CurrentState.Version)')]")
  if ($ReleaseNotesTitleNode) {
    $ReleaseNotesNodes = for ($Node = $ReleaseNotesTitleNode.NextSibling; $Node -and $Node.Name -ne 'h2'; $Node = $Node.NextSibling) { $Node }
    $this.CurrentState.Locale += [ordered]@{
      Locale = 'en-US'
      Key    = 'ReleaseNotes'
      Value  = $ReleaseNotesNodes | Get-TextContent | Format-Text
    }
    $this.CurrentState.Locale += [ordered]@{
      Locale = 'en-US'
      Key    = 'ReleaseNotesUrl'
      Value  = $ReleaseNotesUrl + '#' + ($ReleaseNotesTitleNode.InnerText -creplace '[^a-zA-Z0-9\-\s]+', '' -creplace '\s+', '-').ToLower()
    }
  }
} catch {
  $_ | Out-Host
  $this.Log($_, 'Warning')
}
```

The first entry prevents a URL from the previous version surviving when the request or parser fails. Add a version-specific replacement only after confirming that it belongs to the current desktop release. Use the exact locale of the existing locale manifest. A fallback must point to the package's current desktop changelog or release-notes page, not a generic support page.

See [Task example index](../example-index.md) for current release-metadata implementations.
