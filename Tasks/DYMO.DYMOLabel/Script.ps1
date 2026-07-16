$Object1 = $Global:DumplingsStorage.DYMOApps.'DYMO Softwares'.'DYMO Label Software'.Windows.GetEnumerator() | Sort-Object -Property { [ChunkVersion]([regex]::Match($_.Name, 'v(\d+(\.\d+)+)').Groups[1].Value) } -Bottom 1

# Installer
$this.CurrentState.Installer += [ordered]@{
  InstallerUrl = $Object1.Value.url_s.GetEnumerator().Where({ $_.Name.Contains('Windows 11') }, 'First')[0].Value | ConvertTo-UnescapedUri | ConvertTo-Https
}

# Version
$this.CurrentState.Version = [regex]::Match($this.CurrentState.Installer[0].InstallerUrl, '(\d+(?:\.\d+)+)').Groups[1].Value

switch -Regex ($this.Check()) {
  'New|Changed|Updated' {
    foreach ($Installer in $this.CurrentState.Installer) {
      $this.InstallerFiles[$Installer.InstallerUrl] = $InstallerFile = Get-TempFile -Uri $Installer.InstallerUrl
      $InstallerInfo = Get-InstallShieldMsiInfo -Path $InstallerFile -Name 'DYMO Label.msi'
      # RealVersion
      $this.CurrentState.RealVersion = $InstallerInfo.ProductVersion
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
