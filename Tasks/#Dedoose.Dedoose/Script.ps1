$OldReleasesPath = Join-Path $PSScriptRoot 'Releases.yaml'
if (Test-Path -Path $OldReleasesPath) {
  $Global:DumplingsStorage['Dedoose'] = $OldReleases = Get-Content -Path $OldReleasesPath -Raw | ConvertFrom-Yaml -Ordered
} else {
  $Global:DumplingsStorage['Dedoose'] = $OldReleases = [ordered]@{}
}

# The endpoint is served as text/xml but is not well-formed: release notes contain bare
# ampersands (for example "Audio & Video Navigation"), which makes both Invoke-RestMethod
# and an [xml] cast fail. Escape the stray ampersands before parsing.
$Content = Invoke-WebRequest -Uri 'https://app.dedoose.com/_assets/xml/ClientVersions.xml' | Read-ResponseContent
$Object1 = ($Content -replace '&(?!amp;|lt;|gt;|quot;|apos;|#)', '&amp;') | ConvertFrom-Xml

# Version
$this.CurrentState.Version = $Object1.DedooseClientVersions.windows

switch -Regex ($this.Check()) {
  'New|Changed|Updated|Rollbacked' {
    # ReleaseNotes (en-US)
    $this.CurrentState.Locale += [ordered]@{
      Locale = 'en-US'
      Key    = 'ReleaseNotes'
      Value  = $ReleaseNotes = $Object1.DedooseClientVersions.ReleaseNotes.ReleaseNote.Where({ $_.Version -eq $this.CurrentState.Version }, 'First').'#text' | ConvertFrom-Html | Get-TextContent | Format-Text
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
