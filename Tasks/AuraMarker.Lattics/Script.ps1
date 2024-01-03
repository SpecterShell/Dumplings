# Installer
$this.CurrentState.Installer += [ordered]@{
  InstallerUrl         = $InstallerUrl = Get-RedirectedUrl -Uri 'https://mid.zineapi.com/to/get-lattics/win-installer-x64'
  NestedInstallerFiles = @(
    [ordered]@{
      RelativeFilePath = (Split-Path -Path $InstallerUrl -Leaf) -creplace '\.zip$', '.exe'
    }
  )
}

# Version
$this.CurrentState.Version = $Version = [regex]::Match($InstallerUrl, '(\d+\.\d+\.\d+)\(\d+\)').Groups[1].Value

if ($LocalStorage.Contains('Lattics') -and $LocalStorage['Lattics'].Contains($Version)) {
  # ReleaseTime
  $this.CurrentState.ReleaseTime = $LocalStorage['Lattics'].$Version.ReleaseTime

  # ReleaseNotes (en-US)
  $this.CurrentState.Locale += [ordered]@{
    Locale = 'en-US'
    Key    = 'ReleaseNotes'
    Value  = $LocalStorage['Lattics'].$Version.ReleaseNotesEN
  }
  # ReleaseNotes (zh-CN)
  $this.CurrentState.Locale += [ordered]@{
    Locale = 'zh-CN'
    Key    = 'ReleaseNotes'
    Value  = $LocalStorage['Lattics'].$Version.ReleaseNotesCN
  }
} else {
  $this.Logging("No ReleaseNotes for version $($this.CurrentState.Version)", 'Warning')
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
