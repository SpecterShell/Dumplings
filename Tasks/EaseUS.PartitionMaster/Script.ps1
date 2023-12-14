$Object = Invoke-RestMethod -Uri 'https://download.easeus.com/api/index.php/Home/Index/productInstall?pid=5&version=free'

# Version
$Task.CurrentState.Version = $Object.data.curNum

# Installer
$Task.CurrentState.Installer += [ordered]@{
  InstallerUrl = $Object.data.download3
}

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
