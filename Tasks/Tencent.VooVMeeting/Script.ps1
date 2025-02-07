# Download
$Version1 = @($Global:DumplingsStorage['VooVMeeting1'].Keys)[-1] ?? '0'
# Upgrade
$Version2 = @($Global:DumplingsStorage['VooVMeeting2'].Keys)[-1] ?? '0'

if ([Versioning.Versioning]$Version1 -ge [Versioning.Versioning]$Version2) {
  # Version
  $this.CurrentState.Version = $Version = $Version1

  # Installer
  $this.CurrentState.Installer += [ordered]@{
    Architecture = 'x86'
    InstallerUrl = $Global:DumplingsStorage['VooVMeeting1'].$Version1.InstallerUrl
  }
  # $this.CurrentState.Installer += [ordered]@{
  #   Architecture = 'x64'
  #   InstallerUrl = $Global:DumplingsStorage['VooVMeeting1'].$Version1.InstallerUrlX64
  # }
} else {
  # Version
  $this.CurrentState.Version = $Version = $Version2

  # Installer
  $this.CurrentState.Installer += [ordered]@{
    Architecture = 'x86'
    InstallerUrl = $Global:DumplingsStorage['VooVMeeting2'].$Version2.InstallerUrl
  }
  # $this.CurrentState.Installer += [ordered]@{
  #   Architecture = 'x64'
  #   InstallerUrl = $Global:DumplingsStorage['VooVMeeting2'].$Version2.InstallerUrlX64
  # }
}

switch -Regex ($this.Check()) {
  'New|Changed|Updated' {
    try {
      if ($Global:DumplingsStorage['VooVMeeting1'].Contains($Version)) {
        # ReleaseTime
        $this.CurrentState.ReleaseTime = $Global:DumplingsStorage['VooVMeeting1'].$Version.ReleaseTime
      } else {
        $this.Log("No ReleaseTime for version $($this.CurrentState.Version)", 'Warning')
      }

      if ($Global:DumplingsStorage['VooVMeeting2'].Contains($Version)) {
        # ReleaseNotes (zh-CN)
        $this.CurrentState.Locale += [ordered]@{
          Locale = 'zh-CN'
          Key    = 'ReleaseNotes'
          Value  = $Global:DumplingsStorage['VooVMeeting2'].$Version.ReleaseNotesCN
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
