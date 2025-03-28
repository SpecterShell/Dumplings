$Object1 = Invoke-WebRequest -Uri 'https://cbs.wondershare.com/go.php?m=upgrade_info&pid=526&version=1.1.0' | Read-ResponseContent | ConvertFrom-Xml

# Version
$this.CurrentState.Version = $Object1.Respone.WhatNews.Item[0].Version

# Installer
$this.CurrentState.Installer += [ordered]@{
  InstallerUrl = $Object1.Respone.ExeUrl | ConvertTo-Https
}

switch -Regex ($this.Check()) {
  'New|Changed|Updated' {
    try {
      # ReleaseNotes (en-US)
      $this.CurrentState.Locale += [ordered]@{
        Locale = 'en-US'
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
    $this.Submit()
  }
}
