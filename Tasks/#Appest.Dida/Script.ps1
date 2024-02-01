$OldReleaseNotesPath = Join-Path $PSScriptRoot 'Releases.yaml'
if (Test-Path -Path $OldReleaseNotesPath) {
  $LocalStorage['Dida'] = $OldReleaseNotes = Get-Content -Path $OldReleaseNotesPath -Raw | ConvertFrom-Yaml -Ordered
} else {
  $LocalStorage['Dida'] = $OldReleaseNotes = [ordered]@{}
}

$Object1 = Invoke-WebRequest -Uri 'https://pull.dida365.com/windows/release_note.json' | Read-ResponseContent | ConvertFrom-Json

# Version
$this.CurrentState.Version = $Object1.version

# ReleaseTime
$this.CurrentState.ReleaseTime = [datetime]::ParseExact($Object1.release_date, 'yyyyMMdd', $null).ToString('yyyy-MM-dd')

# ReleaseNotes (en-US)
$this.CurrentState.Locale += [ordered]@{
  Locale = 'en-US'
  Key    = 'ReleaseNotes'
  Value  = $ReleaseNotesEN = $Object1.data.Where({ $_.lang -eq 'en' }, 'First')[0].content | Format-Text
}
# ReleaseNotes (zh-CN)
$this.CurrentState.Locale += [ordered]@{
  Locale = 'zh-CN'
  Key    = 'ReleaseNotes'
  Value  = $ReleaseNotesCN = $Object1.data.Where({ $_.lang -eq 'zh_cn' }, 'First')[0].content | Format-Text
}

switch ($this.Check()) {
  ({ $_ -ge 1 }) {
    $OldReleaseNotes[$this.CurrentState.Version] = [ordered]@{
      ReleaseTime    = $this.CurrentState.ReleaseTime
      ReleaseNotesEN = $ReleaseNotesEN
      ReleaseNotesCN = $ReleaseNotesCN
    }
    if (-not $this.Preference.NoWrite) {
      $OldReleaseNotes | ConvertTo-Yaml -OutFile $OldReleaseNotesPath -Force
    }

    $this.Write()
  }
  ({ $_ -ge 2 }) {
    $this.Message()
  }
}
