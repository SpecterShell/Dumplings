$Prefix = 'https://dldir1v6.qq.com/arthub/desktop/versions/'

$this.CurrentState = Invoke-RestMethod -Uri "${Prefix}latest-win32.yml" | ConvertFrom-Yaml | ConvertFrom-ElectronUpdater -Prefix $Prefix -Locale 'zh-CN'

$this.CurrentState.Installer.ForEach({ $_.InstallerUrl.Replace('dldir1.qq.com', 'dldir1v6.qq.com') })

switch ($this.Check()) {
  ({ $_ -ge 1 }) {
    $this.Write()
  }
  ({ $_ -ge 2 }) {
    $this.Print()
    $this.Message()
  }
  ({ $_ -ge 3 }) {
    $this.Submit()
  }
}
