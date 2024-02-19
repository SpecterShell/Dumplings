# Download
$Version1 = @($LocalStorage['TencentMeeting1'].Keys)[-1] ?? '0'
# Upgrade
$Version2 = @($LocalStorage['TencentMeeting2'].Keys)[-1] ?? '0'

if ((Compare-Version -ReferenceVersion $Version1 -DifferenceVersion $Version2) -le 0) {
  # Version
  $this.CurrentState.Version = $Version = $Version1

  # Installer
  $this.CurrentState.Installer += [ordered]@{
    InstallerUrl = $LocalStorage['TencentMeeting1'].$Version1.InstallerUrl
  }
} else {
  # Version
  $this.CurrentState.Version = $Version = $Version2

  # Installer
  $this.CurrentState.Installer += [ordered]@{
    InstallerUrl = $LocalStorage['TencentMeeting2'].$Version2.InstallerUrl
  }
}

if ($LocalStorage['TencentMeeting1'].Contains($Version)) {
  # ReleaseTime
  $this.CurrentState.ReleaseTime = $LocalStorage['TencentMeeting1'].$Version.ReleaseTime
}

if ($LocalStorage['TencentMeeting2'].Contains($Version)) {
  # ReleaseNotes (zh-CN)
  $this.CurrentState.Locale += [ordered]@{
    Locale = 'zh-CN'
    Key    = 'ReleaseNotes'
    Value  = $LocalStorage['TencentMeeting2'].$Version.ReleaseNotesCN
  }
}

switch -Regex ($this.Check()) {
  'New|Changed|Updated' {
    $this.Write()
  }
  'Changed|Updated' {
    $this.Print()
    $this.Message()
  }
  'Updated' {
    $this.Submit()
  }
}
