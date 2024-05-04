$Object1 = Invoke-RestMethod -Uri 'http://download.easeus.com/api2/index.php/Apicp/Drwdl202004/index/' -Method Post -Body @{
  exeNumber = 100000
  pid       = 5
  version   = 'free'
}

# Version
$this.CurrentState.Version = $Object1.data.curNum

# Installer
$this.CurrentState.Installer += [ordered]@{
  InstallerUrl = $Object1.data.download
}

switch -Regex ($this.Check()) {
  'New|Changed|Updated' {
    $this.Print()
    $this.Write()
  }
  'Changed|Updated' {
    $this.Message()
  }
  'Updated' {
    $this.Submit()
  }
}
