$Object = (Invoke-WebRequest -Uri 'https://www.douyin.com/downloadpage/pc' | ConvertFrom-Html).SelectSingleNode('//*[@id="RENDER_DATA"]').InnerText | ConvertTo-UnescapedUri | ConvertFrom-Json -AsHashtable

# Version
$Task.CurrentState.Version = $Object.app.tccConfig.download_impc_info.version

# Installer
$Task.CurrentState.Installer += [ordered]@{
  Architecture = 'x86'
  InstallerUrl = $Object.app.tccConfig.download_impc_info.apk
}
$Task.CurrentState.Installer += [ordered]@{
  Architecture = 'x64'
  InstallerUrl = $Object.app.tccConfig.download_impc_info.win64Apk
}

# ReleaseTime
$Task.CurrentState.ReleaseTime = $Object.app.tccConfig.download_impc_info.time | Get-Date -Format 'yyyy-MM-dd'

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
