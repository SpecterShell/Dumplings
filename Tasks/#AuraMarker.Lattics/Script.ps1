$OldReleaseNotesPath = Join-Path $PSScriptRoot 'Releases.yaml'
if (Test-Path -Path $OldReleaseNotesPath) {
  $Global:DumplingsStorage['Lattics'] = $OldReleaseNotes = Get-Content -Path $OldReleaseNotesPath -Raw | ConvertFrom-Yaml -Ordered
} else {
  $Global:DumplingsStorage['Lattics'] = $OldReleaseNotes = [ordered]@{}
}

# International
$Object1 = Invoke-RestMethod -Uri 'https://itunes.apple.com/lookup?id=1575605022&country=US&lang=en_us'
# Chinese
$Object2 = Invoke-RestMethod -Uri 'https://itunes.apple.com/lookup?id=1575605022&country=CN&lang=zh_cn'

if ($Object1.results[0].version -ne $Object2.results[0].version) {
  throw 'Distinct versions detected'
}

# Version
$this.CurrentState.Version = $Object1.results[0].version

# ReleaseTime
$this.CurrentState.ReleaseTime = $ReleaseTime = $Object1.results[0].currentVersionReleaseDate

# ReleaseNotes (en-US)
$this.CurrentState.Locale += [ordered]@{
  Locale = 'en-US'
  Key    = 'ReleaseNotes'
  Value  = $ReleaseNotesEN = $Object1.results[0].releaseNotes | Format-Text
}
# ReleaseNotes (zh-CN)
$this.CurrentState.Locale += [ordered]@{
  Locale = 'zh-CN'
  Key    = 'ReleaseNotes'
  Value  = $ReleaseNotesCN = $Object2.results[0].releaseNotes | Format-Text
}

switch -Regex ($this.Check()) {
  'New|Changed|Updated' {
    $OldReleaseNotes[$this.CurrentState.Version] = [ordered]@{
      ReleaseTime    = $ReleaseTime
      ReleaseNotesEN = $ReleaseNotesEN
      ReleaseNotesCN = $ReleaseNotesCN
    }
    if ($Global:DumplingsPreference.Contains('EnableWrite') -and $Global:DumplingsPreference.EnableWrite) {
      $OldReleaseNotes | ConvertTo-Yaml -OutFile $OldReleaseNotesPath -Force
    }

    $this.Write()
  }
  'Changed|Updated' {
    $this.Print()
    $this.Message()
  }
}
