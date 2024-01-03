# Installer
$this.CurrentState.Installer += $Installer = [ordered]@{
  InstallerUrl = $InstallerUrl = Get-RedirectedUrl -Uri 'https://www.effie.co/downloadfile/win'
}

# Version
$this.CurrentState.Version = $Version = [regex]::Match($InstallerUrl, '_(\d+\.\d+\.\d+)[_.]').Groups[1].Value

$Installer.AppsAndFeaturesEntries = @(
  [ordered]@{
    DisplayName = "Effie ${Version}"
    ProductCode = 'Effie_is1'
  }
)

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
