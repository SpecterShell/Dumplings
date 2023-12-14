$Prefix = 'https://pc.ximalaya.com/ximalaya-pc-updater/api/v1/update/full/'
$Headers = @{
  platform     = 'win32'
  buildversion = '0'
  version      = '0.0.0'
  uid          = ''
}

$Task.CurrentState = Invoke-RestMethod -Uri "${Prefix}latest.yml?noCache=$((New-Guid).Guid.Split('-')[0])" -Headers $Headers | ConvertFrom-Yaml | ConvertFrom-ElectronUpdater -Prefix $Prefix -Locale 'zh-CN'

# InstallerUrl
$Task.CurrentState.Installer.ForEach({ $_.InstallerUrl = Get-RedirectedUrl -Uri $_.InstallerUrl -Headers $Headers })

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
