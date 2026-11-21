$Prefix = 'https://oficinavirtual.comercio.gob.es/AFORIXUpdater/'
$Object1 = Invoke-WebRequest -Uri $Prefix

# Version
$this.CurrentState.Version = [regex]::Match($Object1.Content, 'Versión\s+([\d.]+)').Groups[1].Value

# Installer
$this.CurrentState.Installer += [ordered]@{
  Architecture  = 'x86'
  InstallerType = 'inno'
  InstallerUrl  = Join-Uri $Prefix $Object1.Links.Where({ try { $_.href.EndsWith('.exe') } catch {} }, 'First')[0].href
}

switch -Regex ($this.Check()) {
  'New|Changed|Updated' {
    try {
      if ($Object1.Content -match 'Versión\s+[\d.]+\s+\((\d{1,2}\s+de\s+\S+\s+de\s+\d{4})\)') {
        # ReleaseTime
        $this.CurrentState.ReleaseTime = [datetime]::Parse($Matches[1], [System.Globalization.CultureInfo]::GetCultureInfo('es-ES')).ToString('yyyy-MM-dd')
      } else {
        $this.Log("No ReleaseTime for version $($this.CurrentState.Version)", 'Warning')
      }
    } catch {
      $_ | Out-Host
      $this.Log($_, 'Warning')
    }

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
