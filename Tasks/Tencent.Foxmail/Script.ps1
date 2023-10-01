$Object = Invoke-WebRequest -Uri 'https://datacollect.foxmail.com.cn/cgi-bin/foxmailupdate?f=xml' -Method Post -Body @'
<?xml version="1.0" encoding="utf-8"?>
<CheckForUpdate>
    <ProductName>Foxmail</ProductName>
    <Version>0</Version>
    <BuildNumber>0</BuildNumber>
    <RequestType>1</RequestType>
</CheckForUpdate>
'@ | Read-ResponseContent | ConvertFrom-Xml

# Version
$Task.CurrentState.Version = $Object.UpdateNotify.NewVersion

# Installer
$Task.CurrentState.Installer += [ordered]@{
  InstallerUrl = $Object.UpdateNotify.PackageURL.Replace('dldir1.qq.com', 'dldir1v6.qq.com')
}

# ReleaseNotes (zh-CN)
$Task.CurrentState.Locale += [ordered]@{
  Locale = 'zh-CN'
  Key    = 'ReleaseNotes'
  Value  = $Object.UpdateNotify.Description.'#cdata-section'.Replace('\r\n', "`n").Replace('\n', "`n") | Format-Text
}

switch (Compare-State) {
  ({ $_ -ge 1 }) {
    Write-State
  }
  ({ $_ -ge 2 }) {
    Send-VersionMessage
  }
  ({ $_ -ge 3 }) {
    New-Manifest
  }
}
