$Object1 = Invoke-RestMethod -Uri 'https://stores1.hispace.hicloud.com/hwmarket/api/clientApi' -Method Post -Body @{
  sign        = '09001000000000w72000000000000100000000000000100101010000000250000000200b0000000001000'
  serviceType = '39'
  json        = '[{"pkgName":"AppGallery"}]'
  method      = 'client.pcupdate'
}

# Version
$this.CurrentState.Version = $Object1.onlineApps.Where({ $_.package -eq 'AppGallery' }, 'First')[0].versionName

# Installer
$this.CurrentState.Installer += [ordered]@{
  InstallerUrl = $Object1.onlineApps.Where({ $_.package -eq 'AppGallery' }, 'First')[0].downurl
}

# ReleaseTime
$this.CurrentState.ReleaseTime = $Object1.onlineApps.Where({ $_.package -eq 'AppGallery' }, 'First')[0].releaseDate | ConvertFrom-UnixTimeMilliseconds

# ReleaseNotes (zh-Hans)
$this.CurrentState.Locale += [ordered]@{
  Locale = 'zh-Hans'
  Key    = 'ReleaseNotes'
  Value  = $Object1.onlineApps.Where({ $_.package -eq 'AppGallery' }, 'First')[0].newFeatures | Format-Text
}
# ReleaseNotes (zh-Hans-CN)
$this.CurrentState.Locale += [ordered]@{
  Locale = 'zh-Hans-CN'
  Key    = 'ReleaseNotes'
  Value  = $Object1.onlineApps.Where({ $_.package -eq 'AppGallery' }, 'First')[0].newFeatures | Format-Text
}

switch -Regex ($this.Check()) {
  'New|Changed|Updated' {
    $this.Write()
  }
  'Changed|Updated' {
    $this.Print()
    $this.Message()
  }
  'Updated' {
    $this.Submit()
  }
}
