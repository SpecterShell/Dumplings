$Object1 = Invoke-WebRequest -Uri 'https://www.iqiyi.com/appstore.html' | ConvertFrom-Html

# Version
$this.CurrentState.Version = $Version = [regex]::Match($Object1.SelectSingleNode('//li[contains(@class, "app-item") and contains(.//h3[@class="main-title"], "爱奇艺PC客户端")]//p[@class="sub-ver"]').InnerText, '(\d+\.\d+\.\d+\.\d+)').Groups[1].Value

# Installer
$this.CurrentState.Installer += [ordered]@{
  InstallerUrl = "https://mesh.if.iqiyi.com/player/upgrade/file/$($this.CurrentState.Version)/IQIYIsetup_winget.exe"
}

switch -Regex ($this.Check()) {
  'New|Changed|Updated' {
    try {
      if ($Global:DumplingsStorage.Contains('iQIYI') -and $Global:DumplingsStorage['iQIYI'].Contains($Version)) {
        # ReleaseNotes (zh-CN)
        $this.CurrentState.Locale += [ordered]@{
          Locale = 'zh-CN'
          Key    = 'ReleaseNotes'
          Value  = $Global:DumplingsStorage['iQIYI'].$Version.ReleaseNotesCN
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
