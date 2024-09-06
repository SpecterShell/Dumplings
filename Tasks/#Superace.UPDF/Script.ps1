$OldReleaseNotesPath = Join-Path $PSScriptRoot 'Releases.yaml'
if (Test-Path -Path $OldReleaseNotesPath) {
  $Global:DumplingsStorage['UPDF'] = $OldReleaseNotes = Get-Content -Path $OldReleaseNotesPath -Raw | ConvertFrom-Yaml -Ordered
} else {
  $Global:DumplingsStorage['UPDF'] = $OldReleaseNotes = [ordered]@{}
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
  $this.Log("Global version: $($Object1.data.version)")
  $this.Log("China version: $($Object2.data.version)")
  throw 'Inconsistent versions detected'
}

# Version
$this.CurrentState.Version = $Object1.data.version

switch -Regex ($this.Check()) {
  'New|Changed|Updated|Rollbacked' {
    try {
      # ReleaseNotes (en-US)
      $this.CurrentState.Locale += [ordered]@{
        Locale = 'en-US'
        Key    = 'ReleaseNotes'
        Value  = $ReleaseNotesEN = $Object1.data.content | Format-Text
      }
      # ReleaseNotes (zh-CN)
      $this.CurrentState.Locale += [ordered]@{
        Locale = 'zh-CN'
        Key    = 'ReleaseNotes'
        Value  = $ReleaseNotesCN = $Object2.data.content | Format-Text
      }
    } catch {
      $_ | Out-Host
      $this.Log($_, 'Warning')
    }

    $OldReleaseNotes[$this.CurrentState.Version] = [ordered]@{
      ReleaseNotesEN = $ReleaseNotesEN
      ReleaseNotesCN = $ReleaseNotesCN
    }
    if ($Global:DumplingsPreference.Contains('EnableWrite') -and $Global:DumplingsPreference.EnableWrite) {
      $OldReleaseNotes | ConvertTo-Yaml -OutFile $OldReleaseNotesPath -Force
    }

    $this.Print()
    $this.Write()
  }
  'Changed|Updated|Rollbacked' {
    $this.Message()
  }
}
