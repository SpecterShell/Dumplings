# Installer
$Task.CurrentState.Installer += [ordered]@{
  InstallerUrl = $InstallerUrl = (Get-RedirectedUrl -Uri 'https://work.weixin.qq.com/wework_admin/commdownload?platform=win').Replace('dldir1.qq.com', 'dldir1v6.qq.com')
}

# Version
$Task.CurrentState.Version = [regex]::Match($InstallerUrl, '([\d\.]+)\.exe').Groups[1].Value

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
