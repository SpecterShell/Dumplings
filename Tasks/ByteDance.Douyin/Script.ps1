$Object1 = Invoke-WebRequest -Uri 'https://www.douyin.com/downloadpage/chat' | ConvertFrom-Html
$Object2 = ($Object1.SelectSingleNode('//*[@id="RENDER_DATA"]').InnerText | ConvertTo-UnescapedUri | ConvertFrom-Json -AsHashtable).Values.downloadInfo

# Version
$Task.CurrentState.Version = $Object2.version

# Installer
$Task.CurrentState.Installer += [ordered]@{
  InstallerUrl = $Object2.apk
}

# ReleaseTime
$Task.CurrentState.ReleaseTime = $Object2.time | Get-Date -Format 'yyyy-MM-dd'

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
