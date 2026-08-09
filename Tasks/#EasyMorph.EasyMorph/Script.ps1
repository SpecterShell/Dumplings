$OldReleasesPath = Join-Path $PSScriptRoot 'Releases.yaml'
if (Test-Path -Path $OldReleasesPath) {
  $Global:DumplingsStorage['EasyMorph'] = $OldReleases = Get-Content -Path $OldReleasesPath -Raw | ConvertFrom-Yaml -Ordered
} else {
  $Global:DumplingsStorage['EasyMorph'] = $OldReleases = [ordered]@{}
}

$Object1 = Invoke-WebRequest -Uri 'https://easymorph.com/download/EasyMorph.Version.xml' | Read-ResponseContent | ConvertFrom-Xml

# Version
$this.CurrentState.Version = "$($Object1.VersionCollection.Version.Major).$($Object1.VersionCollection.Version.Minor).$($Object1.VersionCollection.Version.Build)" -replace '(\.0+)+$'

switch -Regex ($this.Check()) {
  'New|Changed|Updated|Rollbacked' {
    # ReleaseTime
    $this.CurrentState.ReleaseTime = $Object1.VersionCollection.Version.ReleaseDate | Get-Date -Format 'yyyy-MM-dd'

    $Notes = @($Object1.VersionCollection.Version.ReleaseNotes.ReleaseNote)
    $CurrentHeaderIndex = @(0..($Notes.Count - 1) | Where-Object { $Notes[$_] -match "What's new in v$([regex]::Escape($this.CurrentState.Version))" })
    if ($CurrentHeaderIndex.Count -gt 0) {
      $StartIndex = $CurrentHeaderIndex[0] + 1
      $NextHeaderIndex = @($StartIndex..($Notes.Count - 1) | Where-Object { $Notes[$_] -match "What's new in v" } | Select-Object -First 1)
      $EndIndex = if ($NextHeaderIndex.Count -gt 0) { $NextHeaderIndex[0] } else { $Notes.Count }
      $ReleaseNotes = $Notes[$StartIndex..($EndIndex - 1)]
    } else {
      $ReleaseNotes = $Notes
    }

    # ReleaseNotes (en-US)
    $this.CurrentState.Locale += [ordered]@{
      Locale = 'en-US'
      Key    = 'ReleaseNotes'
      Value  = $ReleaseNotes | Format-Text
    }

    $OldReleases[$this.CurrentState.Version] = [ordered]@{
      ReleaseTime  = $this.CurrentState.ReleaseTime
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
