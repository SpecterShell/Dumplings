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
$this.CurrentState.Version = [regex]::Match($InstallerUrl, '(\d+\.\d+\.\d+)').Groups[1].Value

switch -Regex ($this.Check()) {
  'New|Changed|Updated' {
    try {
      $ShortVersion = $this.CurrentState.Version -creplace '\.0$', ''
      if ($Global:DumplingsStorage.Contains('Lattics') -and $Global:DumplingsStorage['Lattics'].Contains($ShortVersion)) {
        # ReleaseTime
        $this.CurrentState.ReleaseTime = $Global:DumplingsStorage['Lattics'].$ShortVersion.ReleaseTime | Get-Date -AsUTC

        # ReleaseNotes (en-US)
        $this.CurrentState.Locale += [ordered]@{
          Locale = 'en-US'
          Key    = 'ReleaseNotes'
          Value  = $Global:DumplingsStorage['Lattics'].$ShortVersion.ReleaseNotes
        }
        # ReleaseNotes (zh-CN)
        $this.CurrentState.Locale += [ordered]@{
          Locale = 'zh-CN'
          Key    = 'ReleaseNotes'
          Value  = $Global:DumplingsStorage['Lattics'].$ShortVersion.ReleaseNotesCN
        }
      } else {
        $this.Log("No ReleaseTime, ReleaseNotes (en-US) and ReleaseNotes (zh-CN) for version $($this.CurrentState.Version)", 'Warning')
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
