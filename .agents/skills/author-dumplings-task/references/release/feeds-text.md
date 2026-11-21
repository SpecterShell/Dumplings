# Feed and line-oriented release notes

See the [task example index](../example-index.md) for current implementations of these patterns.

## Sparkle Release Metadata

After the appcast enclosure has supplied the required version and installer URL, parse optional `pubDate`, `releaseNotesLink`, or `description` fields in guarded blocks. `Amazon.WorkspacesClient` demonstrates a publisher-specific date format. `#Clockify.Clockify` uses a separate HTML notes page, while `#TablePlus.TablePlus` converts the appcast description.

If the notes are fetched from `releaseNotesLink`, that HTTP request is a new source and belongs in its own `try`/`catch`. Clear the existing `ReleaseNotesUrl` before attempting to replace it.

## Line-Oriented Release Notes

Use a reader when release notes are a large text stream or one structured text block with version delimiters. Decode web responses with `Read-ResponseContent` when they may contain a BOM or use another encoding:

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

Use `StreamReader` directly only when the source encoding is known and streaming is needed to avoid retaining a large response. `Cjwdev.ADAccountResetTool` demonstrates a response stream, `FlorianHeidenreich.Mp3tag` uses `StringReader` over in-memory text, and `Bazwise.FolderSizeExplorer` reads extracted notes.
