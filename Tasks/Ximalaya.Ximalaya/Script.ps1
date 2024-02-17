$Prefix = 'https://pc.ximalaya.com/ximalaya-pc-updater/api/v1/update/full/'
$Headers = @{
  platform     = 'win32'
  buildversion = '0'
  version      = '0.0.0'
  uid          = ''
}

$this.CurrentState = Invoke-RestMethod -Uri "${Prefix}latest.yml?noCache=$(Get-Random)" -Headers $Headers | ConvertFrom-Yaml | ConvertFrom-ElectronUpdater -Prefix $Prefix -Locale 'zh-CN'

# InstallerUrl
$this.CurrentState.Installer.ForEach({ $_.InstallerUrl = Get-RedirectedUrl -Uri $_.InstallerUrl -Headers $Headers })

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
