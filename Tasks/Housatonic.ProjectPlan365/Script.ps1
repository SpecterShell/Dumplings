$Object1 = Invoke-RestMethod -Uri 'https://www.projectplan365.com/PP365_WIN_INSTALLER_LIVE.txt'

# Installer
$this.CurrentState.Installer += [ordered]@{
  InstallerUrl = $Object1.Split(',')[0].Trim()
}

# Version
$this.CurrentState.Version = [regex]::Match($this.CurrentState.Installer[0].InstallerUrl, '(\d+(?:\.\d+)+)').Groups[1].Value

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
