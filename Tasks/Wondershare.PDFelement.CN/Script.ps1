$Object1 = Invoke-WebRequest -Uri 'https://cbs.wondershare.com/go.php?m=upgrade_info&pid=5387&version=11.0.0' | Read-ResponseContent | ConvertFrom-Xml

# Version
$this.CurrentState.Version = $Object1.Respone.WhatNews.Item[0].Version

# Installer
$this.CurrentState.Installer += [ordered]@{
  Architecture = 'x86'
  InstallerUrl = "https://cc-download.wondershare.cc/cbs_down/pdfelement_$($this.CurrentState.Version)_full5387.exe"
}
$this.CurrentState.Installer += [ordered]@{
  Architecture = 'x64'
  InstallerUrl = "https://cc-download.wondershare.cc/cbs_down/pdfelement_64bit_$($this.CurrentState.Version)_full5387.exe"
}

switch -Regex ($this.Check()) {
  'New|Changed|Updated' {
    try {
      # ReleaseNotes (zh-CN)
      $this.CurrentState.Locale += [ordered]@{
        Locale = 'zh-CN'
        Key    = 'ReleaseNotes'
        Value  = $Object1.Respone.WhatNews.Item[0].Text.'#cdata-section' | Format-Text
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
    if ($this.CurrentState.Version.Split('.')[0] -ne $this.LastState.Version.Split('.')[0]) {
      $this.Log('Major version update. The WinGet package needs to be updated', 'Error')
    } else {
      $this.Submit()
    }
  }
}
