# Installer
$this.CurrentState.Installer += [ordered]@{
  InstallerUrl         = $InstallerUrl = Get-RedirectedUrl -Uri 'https://mid.zineapi.com/to/get-lattics/win-installer-x64'
  NestedInstallerFiles = @(
    [ordered]@{
      RelativeFilePath = (Split-Path -Path $InstallerUrl -Leaf) -creplace '\.zip$', ''
    }
  )
}

# Version
$this.CurrentState.Version = [regex]::Match($InstallerUrl, '(\d+\.\d+\.\d+)\(\d+\)').Groups[1].Value

$ShortVersion = $this.CurrentState.Version -creplace '\.0$', ''
if ($LocalStorage.Contains('Lattics') -and $LocalStorage['Lattics'].Contains($ShortVersion)) {
  # ReleaseTime
  $this.CurrentState.ReleaseTime = $LocalStorage['Lattics'].$ShortVersion.ReleaseTime

  # ReleaseNotes (en-US)
  $this.CurrentState.Locale += [ordered]@{
    Locale = 'en-US'
    Key    = 'ReleaseNotes'
    Value  = $LocalStorage['Lattics'].$ShortVersion.ReleaseNotesEN
  }
  # ReleaseNotes (zh-CN)
  $this.CurrentState.Locale += [ordered]@{
    Locale = 'zh-CN'
    Key    = 'ReleaseNotes'
    Value  = $LocalStorage['Lattics'].$ShortVersion.ReleaseNotesCN
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
