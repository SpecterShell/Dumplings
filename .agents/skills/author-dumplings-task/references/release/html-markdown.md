# HTML, Markdown, and Git-hosted release notes

See the [task example index](../example-index.md) for current implementations of these patterns.

## HTML Release Notes

Fetch an optional release-notes page only in the change branch. Keep the request and all parsing of that response in one guarded block:

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

`HP.HPCMSL` collects siblings until the next version heading. `Amazon.AppStream` extracts cells from a matching table row. `RawTherapee.RawTherapee` uses an explicit heading-range stop condition. Convert only the nodes for the target version and finish with `Format-Text`.

## PowerHTML Extraction Patterns

`ConvertFrom-Html` returns a PowerHTML document whose nodes support XPath through `SelectSingleNode()` and `SelectNodes()`. Keep the intermediate names consistent:

- `$ReleaseNotesNode` is one container for the selected release.
- `$ReleaseNotesTitleNode` is the heading that marks the start of a release.
- `$ReleaseNotesNodes` is a collection bounded by the current and next release.

Pipe the smallest correct node or node collection through `Get-TextContent`, then through `Format-Text`. Do not format the entire page and trim it afterward.

When one release is represented by a container, select its content child. This is the pattern used by `1MHz.Knotes`:

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

When a heading starts the release and the next same-level heading starts another release, collect a bounded sibling range. `HP.HPCMSL`, `AceBIT.PasswordDepot.18`, and `Anthropic.ClaudeCode` use this shape:

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

If the selected release is known to continue to the end of its parent, XPath can return all following siblings directly. `7zip.7zip` and `ADInstruments.LabChart` use this shorter form:

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

Do not use an unbounded `following-sibling` query when later releases or page sections share the same parent. Use the loop form with an explicit stop condition instead.

Interleaved bilingual release bodies may place a language marker before the element that contains that language's list. HtmlAgilityPack also exposes indentation as `#text` siblings. Keep a skip flag set across whitespace text nodes and clear it only after the next substantive element. Otherwise the whitespace consumes the flag and the unwanted list leaks into the selected locale.

```powershell
$SkipNextElement = $false
$ReleaseNotesNodes = [System.Collections.Generic.List[object]]::new()
for ($Node = $ReleaseNotesTitleNode.NextSibling; $Node -and $Node.Name -ne 'h2'; $Node = $Node.NextSibling) {
  if ($Node.Name -eq '#text' -and [string]::IsNullOrWhiteSpace($Node.InnerText)) { continue }
  $NodeText = $Node | Get-TextContent | Format-Text
  if ($NodeText -eq '中文 · 新增') { $SkipNextElement = $true; continue }
  if ($SkipNextElement) { $SkipNextElement = $false; continue }
  $ReleaseNotesNodes.Add($Node)
}
```

Match the exact publisher marker and stop boundary. If the node after the marker is not the expected list or section element, warn and omit the locale instead of skipping unrelated content.

Markdown can be converted to the same PowerHTML node model before applying these patterns. The parameter name is `-Extensions`. Pass `hardlinebreak` for sources such as GitHub release bodies where one newline is intended to produce a line break:

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

`advanced` enables the project's normal advanced Markdown pipeline, `emojis` enables emoji extension handling, and `hardlinebreak` preserves single-newline release-body formatting. Ordinary changelog Markdown should omit `hardlinebreak` unless the source uses that convention.

Review the converted text against the [release-text cleanup rules](../../../author-winget-manifest/references/locale/content-and-resources.md#format-the-release-text) before assigning `ReleaseNotes`, including removal of decorative asterisks and superscript markers.

## Skip download and hash sections

Follow the manifest-authoring [release-text rules](../../../author-winget-manifest/references/locale/content-and-resources.md#format-the-release-text). Exclude complete download and hash/checksum sections before calling `Get-TextContent`, including their headings, asset links, tables, and verification instructions. Keep genuine change entries about download or hashing features.

Use a persistent `$Skip` flag while walking the selected release or locale's sibling nodes. Set it at an unwanted heading and keep it set through that section's contents and deeper subheadings. Reconsider it only at the next heading of the same or a higher level, so later changes remain included. Reset the flag for each locale. Stop at the next release or language boundary when the document contains several.

The GitHub example below also excludes a standalone SHA-256 table. Match the actual source headings and table structure rather than copying its patterns blindly. A checksum table may appear without a heading, and download sections may contain lists, code blocks, or nested containers. Filter those observed structures explicitly. See the [release-body filtering examples](../example-index.md#release-metadata-patterns) for current `$Skip` implementations.

If the filtered text is empty, omit `ReleaseNotes` and try the release-history fallback. Preserve the remaining text verbatim after conversion.

## Git-Hosted Release Metadata

For GitHub, GitLab, Gitea, Codeberg, Bitbucket, Gitee, or GitCode releases, use the release publication time and the notes for the exact selected release. When the release body is empty, boilerplate, or download-only, fall back to a current changelog or the desktop application's official release-notes page.

`Anthropic.ClaudeCode` is the concrete fallback example. Its release discovery does not rely on a useful GitHub release body. The task assigns the repository's general `CHANGELOG.md` URL, downloads the raw changelog, converts it with `Convert-MarkdownToHtml`, selects the current version heading, and replaces the fallback URL with that heading's anchor. A failed request still leaves the general changelog URL instead of retaining a URL from the previous version.

GitHub release bodies treat hard line breaks as meaningful. Convert to nodes, skip the unwanted sections, then format the selected changes. Initialize the URL with a verified fallback or `$null` before parsing, following [clear stale release fields](workflow.md#clear-stale-release-fields):

```powershell
$this.CurrentState.Locale += [ordered]@{ Locale = 'en-US'; Key = 'ReleaseNotesUrl'; Value = $null }
try {
  $this.CurrentState.ReleaseTime = $Release.published_at.ToUniversalTime()

  $ReleaseNotesDocument = $Release.body | Convert-MarkdownToHtml -Extensions 'advanced', 'emojis', 'hardlinebreak'
  $Skip = $false
  $SkippedHeadingLevel = 0
  $ReleaseNotesNodes = for ($Node = $ReleaseNotesDocument.ChildNodes[0]; $Node; $Node = $Node.NextSibling) {
    if ($Node.Name -match '^h([1-6])$') {
      $HeadingLevel = [int]$Matches[1]
      if (-not $Skip -or $HeadingLevel -le $SkippedHeadingLevel) {
        $Skip = $Node.InnerText -match '^\s*(Downloads?|Hash(?:es)?|Checksums?|SHA-256|下载|校验和)\s*$'
        if ($Skip) { $SkippedHeadingLevel = $HeadingLevel }
      }
    }
    if (-not $Skip -and -not ($Node.Name -eq 'table' -and $Node.InnerText -match 'SHA-256')) { $Node }
  }
  $Notes = $ReleaseNotesNodes | Get-TextContent | Format-Text
  if ($Notes) {
    $this.CurrentState.Locale += [ordered]@{
      Locale = 'en-US'
      Key    = 'ReleaseNotes'
      Value  = $Notes
    }

    $this.CurrentState.Locale += [ordered]@{
      Locale = 'en-US'
      Key    = 'ReleaseNotesUrl'
      Value  = $Release.html_url
    }
  }
} catch {
  $_ | Out-Host
  $this.Log($_, 'Warning')
}
```

Keep unrelated mobile or platform announcements outside the selected nodes as well.
