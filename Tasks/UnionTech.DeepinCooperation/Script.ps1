$Object1 = Invoke-WebRequest -Uri 'https://www.deepin.org/index/assistant'

# Installer
$this.CurrentState.Installer += [ordered]@{
  InstallerUrl = $InstallerUrl = $Object1.Links | Select-Object -ExpandProperty 'href' -ErrorAction SilentlyContinue | Select-String -Pattern '\.exe$' -Raw | Select-Object -First 1
}

# Version
$this.CurrentState.Version = [regex]::Match($InstallerUrl, '-(\d+\.\d+\.\d+)[-.]').Groups[1].Value

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
