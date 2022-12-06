$Object = Invoke-RestMethod -Uri 'https://download.easeus.com/api/index.php/Home/Index/productInstall?pid=5&version=free'

# Version
$Task.CurrentState.Version = $Object.data.curNum

# Installer
$Task.CurrentState.Installer += [ordered]@{
  InstallerUrl = $Object.data.download3
}

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
