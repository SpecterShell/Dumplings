$OldReleaseNotesPath = Join-Path $PSScriptRoot 'Releases.yaml'
if (Test-Path -Path $OldReleaseNotesPath) {
  $LocalStorage['iFlyRecMeeting'] = $OldReleaseNotes = Get-Content -Path $OldReleaseNotesPath -Raw | ConvertFrom-Yaml -Ordered
} else {
  $LocalStorage['iFlyRecMeeting'] = $OldReleaseNotes = [ordered]@{}
}

$Object1 = Invoke-RestMethod -Uri 'https://www.iflyrec.com/UpdateService/v1/updates/hardware/deltaPatch/check' -Method Post -Body (
  @{
    clientVersion = $this.LastState.Version ?? '2.0.0495'
    deviceType    = 'Windows'
    platform      = 6
  } | ConvertTo-Json -Compress
) -ContentType 'application/json'

if ($Object1.biz.update -eq 0) {
  $this.Logging("The last version $($this.LastState.Version) is the latest, skip checking", 'Info')
  return
}

# Version
$this.CurrentState.Version = $Object1.biz.latestVersion

# ReleaseNotes (zh-CN)
$this.CurrentState.Locale += [ordered]@{
  Locale = 'zh-CN'
  Key    = 'ReleaseNotes'
  Value  = $Object1.biz.latestVersionInfo.Split('&')[0] | Format-Text
}
# ReleaseNotes (en-US)
$this.CurrentState.Locale += [ordered]@{
  Locale = 'en-US'
  Key    = 'ReleaseNotes'
  Value  = $Object1.biz.latestVersionInfo.Split('&')[1] | Format-Text
}

switch ($this.Check()) {
  ({ $_ -ge 1 }) {
    $OldReleaseNotes[$this.CurrentState.Version] = @{
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
