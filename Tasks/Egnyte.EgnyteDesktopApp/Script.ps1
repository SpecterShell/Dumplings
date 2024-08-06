$Object1 = Invoke-WebRequest -Uri 'https://helpdesk.egnyte.com/hc/en-us/articles/205237150-Desktop-App-Installers' -UserAgent 'Mozilla/5.0 (Windows NT 10.0; Microsoft Windows 10.0.22631; en-US)'

# Installer
$this.CurrentState.Installer += [ordered]@{
  InstallerUrl = $InstallerUrl = $Object1.Links | Where-Object -FilterScript { ($_ | Get-Member -Name 'href' -ErrorAction SilentlyContinue) -and $_.href.EndsWith('.msi') } | Select-Object -First 1 | Select-Object -ExpandProperty 'href'
}

# Version
$this.CurrentState.Version = $InstallerUrl -replace '.+(\d+\.\d+\.\d+)_(\d+).+', '$1.$2'

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
