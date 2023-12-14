$Prefix = 'https://dldir1v6.qq.com/arthub/desktop/versions/'

$Task.CurrentState = Invoke-RestMethod -Uri "${Prefix}latest-win32.yml" | ConvertFrom-Yaml | ConvertFrom-ElectronUpdater -Prefix $Prefix -Locale 'zh-CN'
$Task.CurrentState.Installer.ForEach({ $_.InstallerUrl.Replace('dldir1.qq.com', 'dldir1v6.qq.com') })

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
