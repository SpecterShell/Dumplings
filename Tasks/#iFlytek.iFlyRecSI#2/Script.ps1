$OldReleaseNotesPath = Join-Path $PSScriptRoot 'Releases.yaml'
if (Test-Path -Path $OldReleaseNotesPath) {
  $LocalStorage['iFlyRecSI2'] = $OldReleaseNotes = Get-Content -Path $OldReleaseNotesPath -Raw | ConvertFrom-Yaml -Ordered
} else {
  $LocalStorage['iFlyRecSI2'] = $OldReleaseNotes = [ordered]@{}
}

$Object1 = Invoke-RestMethod -Uri 'https://tongchuan.iflyrec.com/UpdateService/v1/updates/hardware/deltaPatch/check' -Method Post -Body (
  @{
    clientVersion = $this.LastState.Version ?? '3.0.1374'
    deviceType    = 'WinOS'
    platform      = 7
  } | ConvertTo-Json -Compress
) -ContentType 'application/json'

# Installer
$this.CurrentState.Installer += [ordered]@{
  InstallerUrl = $InstallerUrl = $Object1.biz.downloadUrl
}

# Version
$this.CurrentState.Version = [regex]::Match($InstallerUrl, '_(\d+\.\d+\.\d+)[_.]').Groups[1].Value

# ReleaseNotes (zh-CN)
$this.CurrentState.Locale += [ordered]@{
  Locale = 'zh-CN'
  Key    = 'ReleaseNotes'
  Value  = $Object1.biz.latestVersionInfo | Format-Text
}

switch ($this.Check()) {
  ({ $_ -ge 1 }) {
    $OldReleaseNotes[$this.CurrentState.Version] = @{ ReleaseTime = $this.CurrentState.ReleaseTime }
    if (-not $this.Preference.NoWrite) {
      $OldReleaseNotes | ConvertTo-Yaml -OutFile $OldReleaseNotesPath -Force
    }

    $this.Write()
  }
  ({ $_ -ge 2 }) {
    $this.Message()
  }
}
