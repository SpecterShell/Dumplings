# Download
$Version1 = @($Global:DumplingsStorage['WeMeetOutlookPlugin1'].Keys)[-1] ?? '0'
# Upgrade
$Version2 = @($Global:DumplingsStorage['WeMeetOutlookPlugin2'].Keys)[-1] ?? '0'

if ([Versioning.Versioning]$Version1 -ge [Versioning.Versioning]$Version2) {
  # Version
  $this.CurrentState.Version = $Version = $Version1

  # Installer
  $this.CurrentState.Installer += [ordered]@{
    InstallerUrl = $Global:DumplingsStorage['WeMeetOutlookPlugin1'].$Version1.InstallerUrl
  }
} else {
  # Version
  $this.CurrentState.Version = $Version = $Version2

  # Installer
  $this.CurrentState.Installer += [ordered]@{
    InstallerUrl = $Global:DumplingsStorage['WeMeetOutlookPlugin2'].$Version2.InstallerUrl
  }
}

switch -Regex ($this.Check()) {
  'New|Changed|Updated' {
    try {
      if ($Global:DumplingsStorage['WeMeetOutlookPlugin1'].Contains($Version)) {
        # ReleaseTime
        $this.CurrentState.ReleaseTime = $Global:DumplingsStorage['WeMeetOutlookPlugin1'].$Version.ReleaseTime
      } else {
        $this.Log("No ReleaseTime for version $($this.CurrentState.Version)", 'Warning')
      }

      if ($Global:DumplingsStorage['WeMeetOutlookPlugin2'].Contains($Version)) {
        # ReleaseNotes (zh-CN)
        $this.CurrentState.Locale += [ordered]@{
          Locale = 'zh-CN'
          Key    = 'ReleaseNotes'
          Value  = $Global:DumplingsStorage['WeMeetOutlookPlugin2'].$Version.ReleaseNotesCN
        }
      } else {
        $this.Log("No ReleaseNotes (zh-CN) for version $($this.CurrentState.Version)", 'Warning')
      }
    } catch {
      $_ | Out-Host
      $this.Log($_, 'Warning')
    }

    $this.Print()
    $this.Write()
  }
  'Changed|Updated' {
    $this.Message()
  }
  'Updated' {
    $this.Submit()
  }
}
