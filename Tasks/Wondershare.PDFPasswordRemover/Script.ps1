$Object1 = Invoke-WebRequest -Uri 'https://cbs.wondershare.com/go.php?m=upgrade_info&pid=526&version=1.1.0' | Read-ResponseContent | ConvertFrom-Xml

# Version
$this.CurrentState.Version = $Object1.Respone.WhatNews.Item[0].Version

# Installer
$this.CurrentState.Installer += [ordered]@{
  InstallerUrl           = $Object1.Respone.ExeUrl | ConvertTo-Https
  AppsAndFeaturesEntries = @(
    [ordered]@{
      DisplayName = "Wondershare PDF Password Remover (Build $($this.CurrentState.Version))"
      ProductCode = '{1719FAD6-2F6A-4F5E-BF2B-1F6F6F1E3806_PasswordRemover}_is1'
    }
  )
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
