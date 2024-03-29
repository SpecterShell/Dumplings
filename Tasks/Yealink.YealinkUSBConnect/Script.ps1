$Object1 = Invoke-WebRequest -Uri 'https://www.yealink.com/en/product-detail/usb-connect-management' | ConvertFrom-Html

# Installer
$this.CurrentState.Installer += [ordered]@{
  InstallerUrl = $InstallerUrl = $Object1.SelectSingleNode('/html/body/main/div/article[1]/div/div[1]/div/small/p/span/a[1]').Attributes['href'].Value
}

# Version
$this.CurrentState.Version = $Version = [regex]::Match($InstallerUrl, '(\d+\.\d+\.\d+\.\d+)').Groups[1].Value

if ($Global:DumplingsStorage.Contains('YealinkUSBConnect') -and $Global:DumplingsStorage['YealinkUSBConnect'].Contains($Version)) {
  # ReleaseTime
  $this.CurrentState.ReleaseTime = $Global:DumplingsStorage['YealinkUSBConnect'].$Version.ReleaseTime
  # ReleaseNotes (en-US)
  $this.CurrentState.Locale += [ordered]@{
    Locale = 'en-US'
    Key    = 'ReleaseNotes'
    Value  = $Global:DumplingsStorage['YealinkUSBConnect'].$Version.ReleaseNotes
  }
  # ReleaseNotes (zh-CN)
  $this.CurrentState.Locale += [ordered]@{
    Locale = 'zh-CN'
    Key    = 'ReleaseNotes'
    Value  = $Global:DumplingsStorage['YealinkUSBConnect'].$Version.ReleaseNotesCN
  }
} else {
  $this.Log("No ReleaseTime, ReleaseTime (en-US) and ReleaseNotes (zh-CN) for version $($this.CurrentState.Version)", 'Warning')
}

switch -Regex ($this.Check()) {
  'New|Changed|Updated' {
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
