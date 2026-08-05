# Release Metadata Patterns And Example Tasks

## Contents

- [Failure Boundary And Ordering](#failure-boundary-and-ordering)
- [Canonical Change Branch](#canonical-change-branch)
- [Example Index](#example-index)
- [Release Time](#release-time)
- [Clear Stale Release Fields](#clear-stale-release-fields)
- [HTML Release Notes](#html-release-notes)
- [PowerHTML Extraction Patterns](#powerhtml-extraction-patterns)
- [Git-Hosted Release Metadata](#git-hosted-release-metadata)
- [Sparkle Release Metadata](#sparkle-release-metadata)
- [Line-Oriented Release Notes](#line-oriented-release-notes)

## Failure Boundary And Ordering

`ReleaseTime`, `ReleaseNotes`, and `ReleaseNotesUrl` improve a manifest but do not
determine whether the installer update is valid. Handle each optional source in
its own `try`/`catch`, log failures as warnings, and continue with the update.
Several fields obtained from one response may share one block. Data fetched from
another endpoint belongs in another block.

Version, `RealVersion`, installer URLs, installer downloading, and required
installer parsing are not optional. Keep them outside recoverable
`try`/`catch` blocks so a failure stops the task. A `try`/`finally` used only for
disposing a stream or extraction directory is safe because it does not suppress
the error.

Inside a `New|Changed|Updated` branch, use this order:

1. Parse optional metadata already available from the discovery source, such as
   `ReleaseTime`, in a source-specific `try`/`catch`.
2. Download and parse required installer evidence, including `RealVersion`,
   without a catch that converts failure into a warning.
3. Fetch and parse every additional optional source in its own `try`/`catch`.
4. Print and write state only after the required installer work succeeds.

`ADInstruments.LabChart.DeviceEnabler.BloodFlowMeter` demonstrates this order.
Its provider object supplies the release date, the MSI supplies `RealVersion`,
and a separate support page supplies `ReleaseNotesUrl`.

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

Replace `Get-MsiInstallerInfo` with the applicable aggregate parser. Do not call
several `Read-*` functions against the same file.

## Example Index

| Pattern | Primary examples | What to reuse |
| --- | --- | --- |
| Metadata and installer evidence from separate sources | `ADInstruments.LabChart.DeviceEnabler.BloodFlowMeter` | Release date first, uncaught MSI download and `RealVersion`, then a separately guarded release-notes page. |
| Stable changelog fallback | `Anthropic.ClaudeCode` | Assign the general changelog URL first, parse the raw changelog when the GitHub release body is unsuitable, and replace the URL with a version anchor when found. |
| HTML release-note nodes | `1MHz.Knotes`, `HP.HPCMSL`, `Amazon.AppStream`, `RawTherapee.RawTherapee` | Nested node selection, version boundaries, XPath selection, `Get-TextContent`, and `Format-Text`. |
| Markdown converted to PowerHTML | `9001.copyparty`, `7zip.7zip`, `Anthropic.ClaudeCode` | Markdig extensions, title-node selection, bounded sibling ranges, and direct following-sibling XPath. |
| GitHub release body | `qyzhg.Prism`, `1357310795.TboxWebdav`, `7zip.7zip` | Publication time, hard-line-break Markdown conversion, release URL, and removal of download-only text. |
| Sparkle metadata | `#Clockify.Clockify`, `#TablePlus.TablePlus`, `Amazon.WorkspacesClient`, `FlorianHeidenreich.Mp3tag` | `pubDate`, `releaseNotesLink`, description content, and publisher-specific date parsing. |
| Line-oriented release notes | `Cjwdev.ADAccountResetTool`, `FlorianHeidenreich.Mp3tag`, `Bazwise.FolderSizeExplorer` | `StreamReader` for known streams, `StringReader` for decoded text, version boundaries, and deterministic disposal. |

Open the named task directly. Reuse the source and parsing shape, but retain the
failure boundary and field-clearing rules in this workflow when the older task
does not yet follow them.

## Release Time

Assign `ReleaseTime` only after `Check()` reports a possible change. If the
discovery response was fetched before `Check()`, parse its date in the first
optional block without requesting the source again:

```powershell
try {
  $this.CurrentState.ReleaseTime = $Release.published_at.ToUniversalTime()
} catch {
  $_ | Out-Host
  $this.Log($_, 'Warning')
}
```

If the release date requires another endpoint, fetch and parse that endpoint in
a separate block. Do not include later release-note requests in the same block.
Preserve source precision when practical; manifest generation formats the value
as `yyyy-MM-dd`.

## Clear Stale Release Fields

Manifest updating removes old `ReleaseNotes` before applying locale entries, but
an existing `ReleaseNotesUrl` remains unless the task explicitly removes it.
Before fallible parsing, assign either a trustworthy general release-notes URL
or `$null`. Prefer a fallback URL when the publisher maintains a changelog page
that remains useful even without a version anchor. Use `$null` when no such page
exists.

`Anthropic.ClaudeCode` assigns the changelog first, then upgrades it to the
current version's anchor after parsing the raw Markdown:

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

The first entry prevents a URL from the previous version surviving when the
request or parser fails. Add a version-specific replacement only after
confirming that it belongs to the current desktop release. Use the exact locale
of the existing locale manifest. A fallback must point to the package's current
desktop changelog or release-notes page, not a generic support page.

## HTML Release Notes

Fetch an optional release-notes page only in the change branch. Keep the request
and all parsing of that response in one guarded block:

```powershell
try {
  $Document = Invoke-WebRequest -Uri $ReleaseNotesPage | ConvertFrom-Html
  $Heading = $Document.SelectSingleNode("//h3[contains(., '$($this.CurrentState.Version)')]")
  if ($Heading) {
    $Nodes = for ($Node = $Heading.NextSibling; $Node -and $Node.Name -ne 'h3'; $Node = $Node.NextSibling) { $Node }

    $this.CurrentState.Locale += [ordered]@{
      Locale = 'en-US'
      Key    = 'ReleaseNotes'
      Value  = $Nodes | Get-TextContent | Format-Text
    }
  } else {
    $this.Log("No ReleaseNotes (en-US) for version $($this.CurrentState.Version)", 'Warning')
  }
} catch {
  $_ | Out-Host
  $this.Log($_, 'Warning')
}
```

`HP.HPCMSL` collects siblings until the next version heading.
`Amazon.AppStream` extracts cells from a matching table row.
`RawTherapee.RawTherapee` uses an explicit heading-range stop condition. Convert
only the nodes for the target version and finish with `Format-Text`.

## PowerHTML Extraction Patterns

`ConvertFrom-Html` returns a PowerHTML document whose nodes support XPath through
`SelectSingleNode()` and `SelectNodes()`. Keep the intermediate names
consistent:

- `$ReleaseNotesNode` is one container for the selected release.
- `$ReleaseNotesTitleNode` is the heading that marks the start of a release.
- `$ReleaseNotesNodes` is a collection bounded by the current and next release.

Pipe the smallest correct node or node collection through `Get-TextContent`, then
through `Format-Text`. Do not format the entire page and trim it afterward.

When one release is represented by a container, select its content child. This
is the pattern used by `1MHz.Knotes`:

```powershell
try {
  $ReleaseNotesDocument = Invoke-WebRequest -Uri $ReleaseNotesPage | ConvertFrom-Html
  $ReleaseNotesNode = $ReleaseNotesDocument.SelectSingleNode("//article[contains(./div[1]/h2, '$($this.CurrentState.Version)')]")
  if ($ReleaseNotesNode) {
    $ReleaseNotes = $ReleaseNotesNode.SelectSingleNode('./div[2]') | Get-TextContent | Format-Text
    $this.CurrentState.Locale += [ordered]@{
      Locale = 'en-US'
      Key    = 'ReleaseNotes'
      Value  = $ReleaseNotes
    }
  } else {
    $this.Log("No ReleaseNotes (en-US) for version $($this.CurrentState.Version)", 'Warning')
  }
} catch {
  $_ | Out-Host
  $this.Log($_, 'Warning')
}
```

When a heading starts the release and the next same-level heading starts another
release, collect a bounded sibling range. `HP.HPCMSL`,
`AceBIT.PasswordDepot.18`, and `Anthropic.ClaudeCode` use this shape:

```powershell
try {
  $ReleaseNotesDocument = Invoke-WebRequest -Uri $ReleaseNotesPage | ConvertFrom-Html
  $ReleaseNotesTitleNode = $ReleaseNotesDocument.SelectSingleNode("//h2[contains(., '$($this.CurrentState.Version)')]")
  if ($ReleaseNotesTitleNode) {
    $ReleaseNotesNodes = for ($Node = $ReleaseNotesTitleNode.NextSibling; $Node -and $Node.Name -ne 'h2'; $Node = $Node.NextSibling) { $Node }
    $this.CurrentState.Locale += [ordered]@{
      Locale = 'en-US'
      Key    = 'ReleaseNotes'
      Value  = $ReleaseNotesNodes | Get-TextContent | Format-Text
    }
  }
} catch {
  $_ | Out-Host
  $this.Log($_, 'Warning')
}
```

If the selected release is known to continue to the end of its parent, XPath can
return all following siblings directly. `7zip.7zip` and
`ADInstruments.LabChart` use this shorter form:

```powershell
try {
  $ReleaseNotesDocument = Invoke-WebRequest -Uri $ReleaseNotesPage | ConvertFrom-Html
  $ReleaseNotesTitleNode = $ReleaseNotesDocument.SelectSingleNode("//h2[contains(., '$($this.CurrentState.Version)')]")
  if ($ReleaseNotesTitleNode) {
    $this.CurrentState.Locale += [ordered]@{
      Locale = 'en-US'
      Key    = 'ReleaseNotes'
      Value  = $ReleaseNotesTitleNode.SelectNodes('./following-sibling::node()') | Get-TextContent | Format-Text
    }
  }
} catch {
  $_ | Out-Host
  $this.Log($_, 'Warning')
}
```

Do not use an unbounded `following-sibling` query when later releases or page
sections share the same parent. Use the loop form with an explicit stop
condition instead.

Markdown can be converted to the same PowerHTML node model before applying these
patterns. The parameter name is `-Extensions`; pass `hardlinebreak` for sources
such as GitHub release bodies where one newline is intended to produce a line
break:

```powershell
try {
  $Markdown = Invoke-RestMethod -Uri $ReleaseNotesSource
  $ReleaseNotesDocument = $Markdown | Convert-MarkdownToHtml -Extensions 'advanced', 'emojis', 'hardlinebreak'
  $ReleaseNotesTitleNode = $ReleaseNotesDocument.SelectSingleNode('./h2[1]')
  if ($ReleaseNotesTitleNode) {
    $ReleaseNotesNodes = for ($Node = $ReleaseNotesTitleNode.NextSibling; $Node -and $Node.Name -ne 'hr'; $Node = $Node.NextSibling) { $Node }
    $this.CurrentState.Locale += [ordered]@{
      Locale = 'en-US'
      Key    = 'ReleaseNotes'
      Value  = $ReleaseNotesNodes | Get-TextContent | Format-Text
    }
  }
} catch {
  $_ | Out-Host
  $this.Log($_, 'Warning')
}
```

`advanced` enables the project's normal advanced Markdown pipeline, `emojis`
enables emoji extension handling, and `hardlinebreak` preserves single-newline
release-body formatting. Ordinary changelog Markdown should omit
`hardlinebreak` unless the source uses that convention.

## Git-Hosted Release Metadata

For GitHub, GitLab, Gitea, Codeberg, Bitbucket, Gitee, or GitCode releases, use
the release publication time and the notes for the exact selected release. When
the release body is empty, boilerplate, or download-only, fall back to a current
changelog or the desktop application's official release-notes page.

`Anthropic.ClaudeCode` is the concrete fallback example. Its release discovery
does not rely on a useful GitHub release body. The task assigns the repository's
general `CHANGELOG.md` URL, downloads the raw changelog, converts it with
`Convert-MarkdownToHtml`, selects the current version heading, and replaces the
fallback URL with that heading's anchor. A failed request still leaves the
general changelog URL instead of retaining a URL from the previous version.

GitHub release bodies treat hard line breaks as meaningful:

```powershell
try {
  $this.CurrentState.ReleaseTime = $Release.published_at.ToUniversalTime()

  $Notes = $Release.body | Convert-MarkdownToHtml -Extensions 'advanced', 'emojis', 'hardlinebreak' | Get-TextContent | Format-Text
  if ($Notes) {
    $this.CurrentState.Locale += [ordered]@{
      Locale = 'en-US'
      Key    = 'ReleaseNotes'
      Value  = $Notes
    }
  }

  $this.CurrentState.Locale += [ordered]@{
    Locale = 'en-US'
    Key    = 'ReleaseNotesUrl'
    Value  = $Release.html_url
  }
} catch {
  $_ | Out-Host
  $this.Log($_, 'Warning')
}
```

Remove checksum tables, repeated asset links, and unrelated mobile or platform
announcements from the source selection. Preserve the selected source text
verbatim after conversion; do not summarize it.

## Sparkle Release Metadata

After the appcast enclosure has supplied the required version and installer URL,
parse optional `pubDate`, `releaseNotesLink`, or `description` fields in guarded
blocks. `Amazon.WorkspacesClient` demonstrates a publisher-specific date format.
`#Clockify.Clockify` uses a separate HTML notes page, while
`#TablePlus.TablePlus` converts the appcast description.

If the notes are fetched from `releaseNotesLink`, that HTTP request is a new
source and belongs in its own `try`/`catch`. Clear the existing
`ReleaseNotesUrl` before attempting to replace it.

## Line-Oriented Release Notes

Use a reader when release notes are a large text stream or one structured text
block with version delimiters. Decode web responses with `Read-ResponseContent`
when they may contain a BOM or use another encoding:

```powershell
try {
  $Text = Invoke-WebRequest -Uri $ReleaseNotesUrl | Read-ResponseContent
  $Reader = [IO.StringReader]::new($Text)
  try {
    $FoundVersion = $false
    while ($Reader.Peek() -ne -1) {
      $Line = $Reader.ReadLine()
      if ($Line -eq "Version $($this.CurrentState.Version)") {
        $FoundVersion = $true
        break
      }
    }

    if ($FoundVersion) {
      $Notes = [Collections.Generic.List[string]]::new()
      while ($Reader.Peek() -ne -1) {
        $Line = $Reader.ReadLine()
        if ($Line -match '^Version \d+(?:\.\d+)+$') { break }
        $Notes.Add($Line)
      }

      $this.CurrentState.Locale += [ordered]@{
        Locale = 'en-US'
        Key    = 'ReleaseNotes'
        Value  = $Notes | Format-Text
      }
    }
  } finally {
    $Reader.Dispose()
  }
} catch {
  $_ | Out-Host
  $this.Log($_, 'Warning')
}
```

Use `StreamReader` directly only when the source encoding is known and streaming
is needed to avoid retaining a large response. `Cjwdev.ADAccountResetTool`
demonstrates a response stream, `FlorianHeidenreich.Mp3tag` uses `StringReader`
over in-memory text, and `Bazwise.FolderSizeExplorer` reads extracted notes.
