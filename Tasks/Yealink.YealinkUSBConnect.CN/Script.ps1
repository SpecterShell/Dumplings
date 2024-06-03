$Object1 = Invoke-WebRequest -Uri 'https://www.yealink.com.cn/product-detail/usb-connect-management' | ConvertFrom-Html

# Installer
$InstallerUrl = $Object1.SelectSingleNode('/html/body/main/div[1]/article[1]/div/div[1]/div/small/p/span/a[1]').Attributes['href'].Value
if ($InstallerUrl.StartsWith('/')) { $InstallerUrl = 'https://www.yealink.com.cn' + $InstallerUrl }
$this.CurrentState.Installer += [ordered]@{
  InstallerUrl = $InstallerUrl
}

# Version
$this.CurrentState.Version = $Version = [regex]::Match($InstallerUrl, '(\d+\.\d+\.\d+\.\d+)').Groups[1].Value

switch -Regex ($this.Check()) {
  'New|Changed|Updated' {
    try {
      if ($Global:DumplingsStorage.Contains('YealinkUSBConnectCN') -and $Global:DumplingsStorage['YealinkUSBConnectCN'].Contains($Version)) {
        # ReleaseTime
        $this.CurrentState.ReleaseTime = $Global:DumplingsStorage['YealinkUSBConnectCN'].$Version.ReleaseTime
        # ReleaseNotes (en-US)
        $this.CurrentState.Locale += [ordered]@{
          Locale = 'en-US'
          Key    = 'ReleaseNotes'
          Value  = $Global:DumplingsStorage['YealinkUSBConnectCN'].$Version.ReleaseNotes
        }
        # ReleaseNotes (zh-CN)
        $this.CurrentState.Locale += [ordered]@{
          Locale = 'zh-CN'
          Key    = 'ReleaseNotes'
          Value  = $Global:DumplingsStorage['YealinkUSBConnectCN'].$Version.ReleaseNotesCN
        }
      } else {
        $this.Log("No ReleaseTime, ReleaseTime (en-US) and ReleaseNotes (zh-CN) for version $($this.CurrentState.Version)", 'Warning')
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
