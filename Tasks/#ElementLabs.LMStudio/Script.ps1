$OldReleasesPath = Join-Path $PSScriptRoot 'Releases.yaml'
if (Test-Path -Path $OldReleasesPath) {
  $Global:DumplingsStorage['LMStudio'] = $OldReleases = Get-Content -Path $OldReleasesPath -Raw | ConvertFrom-Yaml -Ordered
} else {
  $Global:DumplingsStorage['LMStudio'] = $OldReleases = [ordered]@{}
}

$Object1 = Invoke-RestMethod -Uri "https://versions-prod.lmstudio.ai/update/win32/x86/$($this.Status.Contains('New') ? '0.3.19' : $this.LastState.Version)"

# Version
$this.CurrentState.Version = "$($Object1.version)$($Object1.build -gt 0 ? "+$($Object1.build)" : '')"

switch -Regex ($this.Check()) {
  'New|Changed|Updated|Rollbacked' {
    $ReleaseNotesObject = $Object1.releaseNotes | Convert-MarkdownToHtml
    if ($ReleaseNotesTitleNode = $ReleaseNotesObject.SelectSingleNode("//p[contains(./strong, 'Build $($Object1.build)')]")) {
      $ReleaseNotesNodes = for ($Node = $ReleaseNotesTitleNode.NextSibling; $Node -and -not ($Node.SelectSingleNode('./self::p/strong') -and $Node.InnerText -match 'Build \d+'); $Node = $Node.NextSibling) { $Node }
      # ReleaseNotes (en-US)
      $this.CurrentState.Locale += [ordered]@{
        Locale = 'en-US'
        Key    = 'ReleaseNotes'
        Value  = $ReleaseNotes = $ReleaseNotesNodes | Get-TextContent | Format-Text
      }
    } elseif ($ReleaseNotesTitleNode = $ReleaseNotesObject.SelectSingleNode("./h2[contains(text(), '$($this.CurrentState.Version)')]")) {
      # ReleaseNotes (en-US)
      $this.CurrentState.Locale += [ordered]@{
        Locale = 'en-US'
        Key    = 'ReleaseNotes'
        Value  = $ReleaseNotes = $ReleaseNotesTitleNode.SelectNodes('./following-sibling::node()') | Get-TextContent | Format-Text
      }
    } else {
      # ReleaseNotes (en-US)
      $this.CurrentState.Locale += [ordered]@{
        Locale = 'en-US'
        Key    = 'ReleaseNotes'
        Value  = $ReleaseNotes = $ReleaseNotesObject | Get-TextContent | Format-Text
      }
    }

    $OldReleases[$this.CurrentState.Version] = [ordered]@{
      ReleaseNotes = $ReleaseNotes
    }
    if ($Global:DumplingsPreference.Contains('EnableWrite') -and $Global:DumplingsPreference.EnableWrite) {
      $OldReleases | ConvertTo-Yaml -OutFile $OldReleasesPath -Force
    }
  }
  'New' {
    $this.Print()
    $this.Write()
  }
  { $_ -match 'Changed' -and $_ -notmatch 'Updated|Rollbacked' } {
    $this.Print()
    $this.Write()
    $this.Message()
  }
  'Updated' {
    $this.Print()
    $this.Write()
    if (-not $OldReleases.Contains($this.CurrentState.Version)) {
      $this.Message()
    }
  }
  { $_ -match 'Rollbacked' -and -not $OldReleases.Contains($this.CurrentState.Version) } {
    $this.Print()
    $this.Message()
  }
}
