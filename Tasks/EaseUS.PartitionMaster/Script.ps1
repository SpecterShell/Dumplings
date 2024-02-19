$Object1 = Invoke-RestMethod -Uri 'https://download.easeus.com/api/index.php/Home/Index/productInstall?pid=5&version=free'

# Version
$this.CurrentState.Version = $Object1.data.curNum

# Installer
$this.CurrentState.Installer += [ordered]@{
  InstallerUrl = $Object1.data.download3
}

switch -Regex ($this.Check()) {
  'New|Changed|Updated' {
    $this.Write()
  }
  'Changed|Updated' {
    $this.Print()
    $this.Message()
  }
  'Updated' {
    $this.Submit()
  }
}
