$Object1 = Invoke-RestMethod -Uri 'https://www.yxfile.com.cn/data/downloads.json'

# Version
$this.CurrentState.Version = $Object1.platforms.win.version

# Installer
$this.CurrentState.Installer += [ordered]@{
  InstallerUrl = $Object1.platforms.win.downloadUrl
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
