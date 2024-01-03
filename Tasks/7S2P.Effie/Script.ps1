# Installer
$this.CurrentState.Installer += [ordered]@{
  InstallerUrl = $InstallerUrl = Get-RedirectedUrl -Uri 'https://www.effie.pro/downloadfile/win'
}

# Version
$this.CurrentState.Version = [regex]::Match($InstallerUrl, '_(\d+\.\d+\.\d+)[_.]').Groups[1].Value

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
