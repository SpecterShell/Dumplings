$Object1 = Invoke-RestMethod -Uri 'https://data.api.sj.360.cn/data?key=96d7538fe8fbb6456420b7734585f04b'

# Version
$this.CurrentState.Version = [regex]::Match($Object1.data[0].pc_update_info, 'V(\d+(?:\.\d+){3,})').Groups[1].Value

# Installer
$this.CurrentState.Installer += [ordered]@{
  InstallerUrl = 'https://zs.down.360safe.com/360mobilemgr/instmobilemgr.exe'
}

switch -Regex ($this.Check()) {
  'New|Changed|Updated' {
    try {
      # ReleaseTime
      $this.CurrentState.ReleaseTime = [regex]::Match($Object1.data[0].pc_update_info, '(\d{4}\.\d{1,2}\.\d{1,2})').Groups[1].Value | Get-Date -Format 'yyyy-MM-dd'
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
