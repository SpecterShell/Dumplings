$OldReleaseNotesPath = Join-Path $PSScriptRoot 'Releases.yaml'
if (Test-Path -Path $OldReleaseNotesPath) {
  $Global:DumplingsStorage['AIMeetingManager'] = $OldReleaseNotes = Get-Content -Path $OldReleaseNotesPath -Raw | ConvertFrom-Yaml -Ordered
} else {
  $Global:DumplingsStorage['AIMeetingManager'] = $OldReleaseNotes = [ordered]@{}
}

$Object1 = Invoke-WebRequest -Uri 'https://filedownload.lenovo.com/dtsw/AIMeeting/AIMeetingManager.xml' | Read-ResponseContent | ConvertFrom-Xml

# Version
$this.CurrentState.Version = $Object1.amm.version

# Installer
$this.CurrentState.Installer += [ordered]@{
  InstallerUrl = $Object1.amm.url
}

switch -Regex ($this.Check()) {
  'New|Changed|Updated|Rollbacked' {
    try {
      # ReleaseNotes (zh-CN)
      $this.CurrentState.Locale += [ordered]@{
        Locale = 'zh-CN'
        Key    = 'ReleaseNotes'
        Value  = $ReleaseNotesCN = $Object1.amm.updateContent.item | Format-Text
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
