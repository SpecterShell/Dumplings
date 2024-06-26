$OldReleaseNotesPath = Join-Path $PSScriptRoot 'Releases.yaml'
if (Test-Path -Path $OldReleaseNotesPath) {
  $Global:DumplingsStorage['iFlyRecSI2'] = $OldReleaseNotes = Get-Content -Path $OldReleaseNotesPath -Raw | ConvertFrom-Yaml -Ordered
} else {
  $Global:DumplingsStorage['iFlyRecSI2'] = $OldReleaseNotes = [ordered]@{}
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

switch -Regex ($this.Check()) {
  'New|Changed|Updated|Rollbacked' {
    try {
      # ReleaseNotes (zh-CN)
      $this.CurrentState.Locale += [ordered]@{
        Locale = 'zh-CN'
        Key    = 'ReleaseNotes'
        Value  = $ReleaseNotesCN = $Object1.biz.latestVersionInfo | Format-Text
      }
    } catch {
      $_ | Out-Host
      $this.Log($_, 'Warning')
    }

    $OldReleaseNotes[$this.CurrentState.Version] = [ordered]@{
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
