$Prefix = 'https://cos5.cloud.tencent.com/cosbrowser/'

$this.CurrentState = Invoke-WebRequest -Uri "${Prefix}latest.yml?noCache=$((New-Guid).Guid.Split('-')[0])" | Read-ResponseContent | ConvertFrom-Yaml | ConvertFrom-ElectronUpdater -Prefix $Prefix -Locale 'zh-CN'

$this.CurrentState.Installer.ForEach({ $_.InstallerUrl.Replace('dldir1.qq.com', 'dldir1v6.qq.com') })

switch ($this.Check()) {
  ({ $_ -ge 1 }) {
    $this.Write()
  }
  ({ $_ -ge 2 }) {
    $this.Message()
  }
  ({ $_ -ge 3 }) {
    $this.Submit()
  }
}
