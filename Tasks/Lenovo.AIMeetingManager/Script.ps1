$EdgeDriver = Get-EdgeDriver
$EdgeDriver.Navigate().GoToUrl('https://lva.lenovo.com.cn/')

# Installer
$this.CurrentState.Installer += [ordered]@{
  InstallerUrl = $InstallerUrl = $EdgeDriver.ExecuteScript('return downloadURl.amm', $null)
}

# Version
$this.CurrentState.Version = $Version = [regex]::Match($InstallerUrl, '([\d\.]+)\.exe').Groups[1].Value

switch -Regex ($this.Check()) {
  'New|Changed|Updated' {
    try {
      if ($Global:DumplingsStorage.Contains('AIMeetingManager') -and $Global:DumplingsStorage['AIMeetingManager'].Contains($Version)) {
        # ReleaseNotes (zh-CN)
        $this.CurrentState.Locale += [ordered]@{
          Locale = 'zh-CN'
          Key    = 'ReleaseNotes'
          Value  = $Global:DumplingsStorage['AIMeetingManager'].$Version.ReleaseNotesCN
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
