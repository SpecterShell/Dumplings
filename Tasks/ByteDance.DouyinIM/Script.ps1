$Object1 = Invoke-WebRequest -Uri 'https://www.douyin.com/downloadpage/chat' | ConvertFrom-Html
$Object2 = ($Object1.SelectSingleNode('//*[@id="RENDER_DATA"]').InnerText | ConvertTo-UnescapedUri | ConvertFrom-Json -AsHashtable).Values.downloadImPcInfo

# Version
$Task.CurrentState.Version = $Object2.version

# Installer
$Task.CurrentState.Installer += [ordered]@{
  InstallerUrl = $Object2.apk
}

# ReleaseTime
$Task.CurrentState.ReleaseTime = $Object2.time | Get-Date -Format 'yyyy-MM-dd'

switch ($Task.Check()) {
  ({ $_ -ge 1 }) {
    $Task.Write()
  }
  ({ $_ -ge 2 }) {
    $Task.Message()
  }
  ({ $_ -ge 3 }) {
    $Task.Submit()
  }
}
