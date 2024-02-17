$Object1 = Invoke-RestMethod -Uri 'https://download.easeus.com/api/index.php/Home/Index/productInstall?pid=5&version=free'

# Version
$this.CurrentState.Version = $Object1.data.curNum

# Installer
$this.CurrentState.Installer += [ordered]@{
  InstallerUrl = $Object1.data.download3
}

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
