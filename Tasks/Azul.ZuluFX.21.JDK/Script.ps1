$Object1 = $Global:DumplingsStorage.AzulZuluBuilds | Where-Object -FilterScript { $_.distro_version[0] -eq 21 -and $_.name.Contains('jdk') -and $_.name.Contains('fx') -and $_.name.Contains('x64') } | Sort-Object -Property { $_.distro_version.ForEach({ $_.ToString().PadLeft(20) }) -join '.' } -Bottom 1

# Version
$this.CurrentState.Version = $Object1.distro_version -join '.'

# RealVersion
$this.CurrentState.RealVersion = $Object1.distro_version[0..2] -join '.'

# Installer
$this.CurrentState.Installer += [ordered]@{
  Architecture = 'x64'
  InstallerUrl = $Object1.download_url
}

switch -Regex ($this.Check()) {
  'New|Changed|Updated' {
    $InstallerFile = Get-TempFile -Uri $this.CurrentState.Installer[0].InstallerUrl

    # InstallerSha256
    $this.CurrentState.Installer[0]['InstallerSha256'] = (Get-FileHash -Path $InstallerFile -Algorithm SHA256).Hash
    # AppsAndFeaturesEntries + ProductCode
    $this.CurrentState.Installer[0]['AppsAndFeaturesEntries'] = @(
      [ordered]@{
        DisplayName = "Azul Zulu JDK $($this.CurrentState.Version) ($($Object1.java_version -join '.')), 64-bit"
      }
    )
    $this.CurrentState.Installer[0]['ProductCode'] = $InstallerFile | Read-ProductCodeFromMsi

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
