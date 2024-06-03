$Object1 = Invoke-WebRequest -Uri 'https://www.iqiyi.com/appstore.html'

# Installer
$this.CurrentState.Installer += [ordered]@{
  InstallerUrl = $InstallerUrl = $Object1.Links | Where-Object -FilterScript { ($_ | Get-Member -Name 'href' -ErrorAction SilentlyContinue) -and $_.href.EndsWith('.exe') -and $_.href.Contains('GeePlayer') } | Select-Object -First 1 | Select-Object -ExpandProperty 'href'
}

# Version
$this.CurrentState.Version = [regex]::Match($InstallerUrl, '(\d+\.\d+\.\d+\.\d+)').Groups[1].Value

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
