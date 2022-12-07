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
