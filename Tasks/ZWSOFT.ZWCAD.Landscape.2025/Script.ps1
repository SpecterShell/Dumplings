$Object1 = $Global:DumplingsStorage.ZWSOFTApps.data.Where({ $_.title -eq '中望景园 2025' }, 'First')[0]
$Object2 = Invoke-WebRequest -Uri $Object1.download[0].url

# Installer
$this.CurrentState.Installer += [ordered]@{
  InstallerUrl = Join-Uri 'https://upgrade-online.zwsoft.cn' ([regex]::Match($Object2.Content, 'https://download\.zwsoft\.cn/\d+/[a-zA-Z0-9]+([^"]+)').Groups[1].Value)
}

# Version
$this.CurrentState.Version = [regex]::Match($this.CurrentState.Installer[0].InstallerUrl, '_(\d+(?:\.\d+)+)[_.]').Groups[1].Value

switch -Regex ($this.Check()) {
  'New|Changed|Updated' {
    try {
      # ReleaseTime
      $this.CurrentState.ReleaseTime = $Object1.updateDate | Get-Date -Format 'yyyy-MM-dd'
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
