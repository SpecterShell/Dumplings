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
if ($Global:LocalStorage.Contains('Lattics') -and $Global:LocalStorage['Lattics'].Contains($ShortVersion)) {
  # ReleaseTime
  $this.CurrentState.ReleaseTime = $Global:LocalStorage['Lattics'].$ShortVersion.ReleaseTime

  # ReleaseNotes (en-US)
  $this.CurrentState.Locale += [ordered]@{
    Locale = 'en-US'
    Key    = 'ReleaseNotes'
    Value  = $Global:LocalStorage['Lattics'].$ShortVersion.ReleaseNotesEN
  }
  # ReleaseNotes (zh-CN)
  $this.CurrentState.Locale += [ordered]@{
    Locale = 'zh-CN'
    Key    = 'ReleaseNotes'
    Value  = $Global:LocalStorage['Lattics'].$ShortVersion.ReleaseNotesCN
  }
} else {
  $this.Log("No ReleaseNotes for version $($this.CurrentState.Version)", 'Warning')
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
