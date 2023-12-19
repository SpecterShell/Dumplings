$Object = Invoke-RestMethod -Uri 'https://download.easeus.com/api/index.php/Home/Index/productInstall?pid=5&version=free'

# Version
$this.CurrentState.Version = $Object.data.curNum

# Installer
$this.CurrentState.Installer += [ordered]@{
  InstallerUrl = $Object.data.download3
}

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
