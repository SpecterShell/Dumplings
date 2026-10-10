$this.CurrentState = $Global:DumplingsStorage.WondershareUpgradeInfo['5239']

if ($this.CurrentState.Installer[0].InstallerUrl.Contains('_gray')) {
  $this.Log("The version $($this.CurrentState.Version) is an A/B test version", 'Error')
  return
}

# Installer
$this.CurrentState.Installer = @(
  [ordered]@{
    Architecture = 'x86'
    InstallerUrl = $this.CurrentState.Installer[0].InstallerUrl.Replace('_64bit', '')
  }
  [ordered]@{
    Architecture = 'x64'
    InstallerUrl = $this.CurrentState.Installer[0].InstallerUrl
  }
)

switch -Regex ($this.Check()) {
  'New|Changed|Updated' {
    try {
      # Format HTML content
      $this.CurrentState.Locale.Where({ $_.Key -eq 'ReleaseNotes' }).ForEach({ $_.Value = $_.Value | ConvertFrom-Html | Get-TextContent | Format-Text })
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
    if ($this.CurrentState.Version.Split('.')[0] -ne $this.Config.WinGetIdentifier.Split('.')[-1]) {
      $this.Log('Major version update. The WinGet package needs to be updated', 'Error')
    } else {
      $this.Submit()
    }
  }
}
