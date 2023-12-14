$Object1 = Invoke-WebRequest -Uri 'https://www.douyin.com/downloadpage/pc' | ConvertFrom-Html
$Object2 = ($Object1.SelectSingleNode('//*[@id="RENDER_DATA"]').InnerText | ConvertTo-UnescapedUri | ConvertFrom-Json -AsHashtable).Values.downloadInfo

# Version
$Task.CurrentState.Version = $Object2.version

# Installer
$Task.CurrentState.Installer += [ordered]@{
  InstallerUrl = $Object2.apk.Replace('lf3-cdn-tos.bytegoofy.com', 'www.douyin.com/download/pc')
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
