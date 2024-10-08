$OldReleaseNotesPath = Join-Path $PSScriptRoot 'Releases.yaml'
if (Test-Path -Path $OldReleaseNotesPath) {
  $Global:DumplingsStorage['Lattics'] = $OldReleaseNotes = Get-Content -Path $OldReleaseNotesPath -Raw | ConvertFrom-Yaml -Ordered
} else {
  $Global:DumplingsStorage['Lattics'] = $OldReleaseNotes = [ordered]@{}
}

# Global
$Object1 = Invoke-RestMethod -Uri 'https://itunes.apple.com/lookup?id=1575605022&country=US&lang=en_us'
# China
$Object2 = Invoke-RestMethod -Uri 'https://itunes.apple.com/lookup?id=1575605022&country=CN&lang=zh_cn'

if ($Object1.results[0].version -ne $Object2.results[0].version) {
  $this.Log("Global version: $($Object1.results[0].version)")
  $this.Log("China version: $($Object2.results[0].version)")
  throw 'Distinct versions detected'
}

# Version
$this.CurrentState.Version = $Object1.results[0].version

switch -Regex ($this.Check()) {
  'New|Changed|Updated' {
    try {
      # ReleaseTime
      $this.CurrentState.ReleaseTime = $ReleaseTime = $Object1.results[0].currentVersionReleaseDate.ToUniversalTime()

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
    } catch {
      $_ | Out-Host
      $this.Log($_, 'Warning')
    }

    $OldReleaseNotes[$this.CurrentState.Version] = [ordered]@{
      ReleaseTime    = $ReleaseTime
      ReleaseNotesEN = $ReleaseNotesEN
      ReleaseNotesCN = $ReleaseNotesCN
    }
    if ($Global:DumplingsPreference.Contains('EnableWrite') -and $Global:DumplingsPreference.EnableWrite) {
      $OldReleaseNotes | ConvertTo-Yaml -OutFile $OldReleaseNotesPath -Force
    }

    $this.Print()
    $this.Write()
  }
  'Changed|Updated' {
    $this.Message()
  }
}
