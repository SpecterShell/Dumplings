# Installer
$this.CurrentState.Installer += [ordered]@{
  InstallerUrl = $Global:DumplingsStorage.DYMOApps.records.Where({ $_.software -eq 'DYMO Label Software' -and $_.osVersion -eq 'Windows 11' }, 'Last')[0].url | ConvertTo-UnescapedUri | ConvertTo-Https
}

# Version
$this.CurrentState.Version = [regex]::Match($this.CurrentState.Installer[0].InstallerUrl, '(\d+(?:\.\d+)+)').Groups[1].Value

switch -Regex ($this.Check()) {
  'New|Changed|Updated' {
    foreach ($Installer in $this.CurrentState.Installer) {
      $this.InstallerFiles[$Installer.InstallerUrl] = $InstallerFile = Get-TempFile -Uri $Installer.InstallerUrl
      $InstallerInfo = Get-InstallShieldMsiInfo -Path $InstallerFile -Name 'DYMO Label.msi'
      # RealVersion
      $this.CurrentState.RealVersion = $InstallerInfo.DisplayVersion
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
