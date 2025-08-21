$Object1 = Invoke-RestMethod -Uri 'https://drive.uc.cn/api/client_version'

if (-not $Object1.data.winInstallerUrl.Contains('UCWin')) {
  $this.Log('The installer is not a UCWin installer', 'Warning')
  return
}

# Installer
$this.CurrentState.Installer += [ordered]@{
  InstallerUrl = $Object1.data.winInstallerUrl | ConvertTo-Https
}

# Version
$this.CurrentState.Version = [regex]::Match($this.CurrentState.Installer[0].InstallerUrl, 'V(\d+(?:\.\d+)+)').Groups[1].Value

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
