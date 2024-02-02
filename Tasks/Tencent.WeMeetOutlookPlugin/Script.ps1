# Download
$Version1 = @($LocalStorage['WeMeetOutlookPlugin1'].Keys)[-1] ?? '0'
# Upgrade
$Version2 = @($LocalStorage['WeMeetOutlookPlugin2'].Keys)[-1] ?? '0'

if ((Compare-Version -ReferenceVersion $Version1 -DifferenceVersion $Version2) -le 0) {
  # Version
  $this.CurrentState.Version = $Version = $Version1

  # Installer
  $this.CurrentState.Installer += [ordered]@{
    InstallerUrl = $LocalStorage['WeMeetOutlookPlugin1'].$Version1.InstallerUrl
  }
} else {
  # Version
  $this.CurrentState.Version = $Version = $Version2

  # Installer
  $this.CurrentState.Installer += [ordered]@{
    InstallerUrl = $LocalStorage['WeMeetOutlookPlugin2'].$Version2.InstallerUrl
  }
}

if ($LocalStorage['WeMeetOutlookPlugin1'].Contains($Version)) {
  # ReleaseTime
  $this.CurrentState.ReleaseTime = $LocalStorage['WeMeetOutlookPlugin1'].$Version.ReleaseTime
}

if ($LocalStorage['WeMeetOutlookPlugin2'].Contains($Version)) {
  # ReleaseNotes (zh-CN)
  $this.CurrentState.Locale += [ordered]@{
    Locale = 'zh-CN'
    Key    = 'ReleaseNotes'
    Value  = $LocalStorage['WeMeetOutlookPlugin2'].$Version.ReleaseNotesCN
  }
}

switch ($this.Check()) {
  ({ $_ -ge 1 }) {
    $this.Write()
  }
  ({ $_ -ge 2 }) {
    $this.Message()
  }
  ({ $_ -ge 3 }) {
    $this.Submit()
  }
}
