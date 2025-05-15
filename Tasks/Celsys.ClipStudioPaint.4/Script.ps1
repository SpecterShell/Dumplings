$Object1 = Invoke-WebRequest -Uri 'https://www.clipstudio.net/en/dl/v4/'

# Version
$this.CurrentState.Version = [regex]::Match($Object1.Content, 'Version (\d+(?:\.\d+){2,})').Groups[1].Value

# Installer
$this.CurrentState.Installer += [ordered]@{
  InstallerUrl = Get-RedirectedUrl -Uri 'https://www.clipstudio.net/gd?id=csp-install-win_v4'
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
