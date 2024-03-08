$OldReleaseNotesPath = Join-Path $PSScriptRoot 'Releases.yaml'
if (Test-Path -Path $OldReleaseNotesPath) {
  $Global:DumplingsStorage['PikPak'] = $OldReleaseNotes = Get-Content -Path $OldReleaseNotesPath -Raw | ConvertFrom-Yaml -Ordered
} else {
  $Global:DumplingsStorage['PikPak'] = $OldReleaseNotes = [ordered]@{}
}

# en-US
$Object1 = Invoke-RestMethod -Uri 'https://config.mypikpak.com/config/v1/client_version' -Method Post -Body (
  @{
    data   = @{ language = 'en-US' }
    client = 'windows'
  } | ConvertTo-Json -Compress
)
# zh-CN
$Object2 = Invoke-RestMethod -Uri 'https://config.mypikpak.com/config/v1/client_version' -Method Post -Body (
  @{
    data   = @{ language = 'zh-CN' }
    client = 'windows'
  } | ConvertTo-Json -Compress
)

# Version
$this.CurrentState.Version = $Object1.values.client_version.newVersionName

# RealVersion
$this.CurrentState.RealVersion = $Object1.values.client_version.newVersionName.Split('.')[0..2] -join '.'

# ReleaseNotes (en-US)
$this.CurrentState.Locale += [ordered]@{
  Locale = 'en-US'
  Key    = 'ReleaseNotes'
  Value  = $ReleaseNotesEN = $Object1.values.client_version.news | Format-Text
}

# ReleaseNotes (zh-CN)
$this.CurrentState.Locale += [ordered]@{
  Locale = 'zh-CN'
  Key    = 'ReleaseNotes'
  Value  = $ReleaseNotesCN = $Object2.values.client_version.news | Format-Text
}

switch -Regex ($this.Check()) {
  'New|Changed|Updated' {
    $OldReleaseNotes[$this.CurrentState.Version] = [ordered]@{
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
