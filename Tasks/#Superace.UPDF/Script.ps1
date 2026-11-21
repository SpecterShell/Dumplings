$OldReleasesPath = Join-Path $PSScriptRoot 'Releases.yaml'
if (Test-Path -Path $OldReleasesPath) {
  $Global:DumplingsStorage['UPDF'] = $OldReleases = Get-Content -Path $OldReleasesPath -Raw | ConvertFrom-Yaml -Ordered
} else {
  $Global:DumplingsStorage['UPDF'] = $OldReleases = [ordered]@{}
}

# en-US
$Object1 = Invoke-RestMethod -Uri 'https://api.updf.com/v1/common/checkUpdate' -Headers @{
  'Accept-Language' = 'en-US'
  'Authorization'   = 'Basic dXBkZl93aW5fdjE6aTQwRGNsZiRzMF9kbWxYOXo0RiZkYzk4eEdtNWc0eHE='
  'Device-Type'     = 'WIN'
}
# zh-CN
$Object2 = Invoke-RestMethod -Uri 'https://api.updf.com/v1/common/checkUpdate' -Headers @{
  'Accept-Language' = 'zh-CN'
  'Authorization'   = 'Basic dXBkZl93aW5fdjE6aTQwRGNsZiRzMF9kbWxYOXo0RiZkYzk4eEdtNWc0eHE='
  'Device-Type'     = 'WIN'
}

if ($Object1.data.version -ne $Object2.data.version) {
  $this.Log("Inconsistent versions: Global: $($Object1.data.version), China: $($Object2.data.version)", 'Error')
  return
}

# Version
$this.CurrentState.Version = $Object1.data.version

switch -Regex ($this.Check()) {
  'New|Changed|Updated|Rollbacked' {
    # ReleaseNotes (en-US)
    $this.CurrentState.Locale += [ordered]@{
      Locale = 'en-US'
      Key    = 'ReleaseNotes'
      Value  = $ReleaseNotes = $Object1.data.content | Format-Text
    }
    # ReleaseNotes (zh-CN)
    $this.CurrentState.Locale += [ordered]@{
      Locale = 'zh-CN'
      Key    = 'ReleaseNotes'
      Value  = $ReleaseNotesCN = $Object2.data.content | Format-Text
    }

    $OldReleases[$this.CurrentState.Version] = [ordered]@{
      ReleaseNotes   = $ReleaseNotes
      ReleaseNotesCN = $ReleaseNotesCN
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
