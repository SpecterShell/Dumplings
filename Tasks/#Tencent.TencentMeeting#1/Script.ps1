$OldReleaseNotesPath = Join-Path $PSScriptRoot 'Releases.yaml'
if (Test-Path -Path $OldReleaseNotesPath) {
  $Global:DumplingsStorage['TencentMeeting1'] = $OldReleaseNotes = Get-Content -Path $OldReleaseNotesPath -Raw | ConvertFrom-Yaml -Ordered
} else {
  $Global:DumplingsStorage['TencentMeeting1'] = $OldReleaseNotes = [ordered]@{}
}

$Object1 = Invoke-RestMethod -Uri 'https://meeting.tencent.com/web-service/query-download-info?q=[{%22package-type%22:%22app%22,%22channel%22:%220300000000%22,%22platform%22:%22windows%22}]&nonce=AAAAAAAAAAAAAAAA'

# Version
$this.CurrentState.Version = $Object1.'info-list'[0].version

# Installer
$this.CurrentState.Installer += [ordered]@{
  InstallerUrl = $InstallerUrl = $Object1.'info-list'[0].url.Replace('.officialwebsite', '')
}

# ReleaseTime
$this.CurrentState.ReleaseTime = $Object1.'info-list'[0].'sub-date' | Get-Date -Format 'yyyy-MM-dd'

switch -Regex ($this.Check()) {
  'New|Changed|Updated' {
    $OldReleaseNotes[$this.CurrentState.Version] = [ordered]@{
      InstallerUrl = $InstallerUrl
      ReleaseTime  = $this.CurrentState.ReleaseTime
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
