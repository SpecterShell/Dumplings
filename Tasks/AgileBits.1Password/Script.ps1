$Object1 = Invoke-RestMethod -Uri "https://app-updates.agilebits.com/check/3/10.0.22000/x86_64/OPW8/en/$($this.LastState.Contains('RawVersion') ? $this.LastState.RawVersion: '81026039')/A1/N/msi"
# $Object1 = Invoke-RestMethod -Uri "https://app-updates.agilebits.com/check/3/10.0.22000/x86_64/OPW8/en/$($this.LastState.Contains('RawVersion') ? $this.LastState.RawVersion: '81026039')/A1/N/msix"

# Version
$this.CurrentState.Version = $Object1.available -eq '0' ? $this.LastState.Version: $Object1.version

# Installer
$this.CurrentState.Installer += [ordered]@{
  Architecture           = 'x64'
  InstallerType          = 'msi'
  InstallerUrl           = "https://c.1password.com/dist/1P/win8/1PasswordSetup-$($this.CurrentState.Version).msi"
  AppsAndFeaturesEntries = @(
    [ordered]@{
      DisplayVersion = $this.CurrentState.Version
    }
  )
}
$this.CurrentState.Installer += $InstallerMSIX = [ordered]@{
  Architecture  = 'x64'
  InstallerType = 'msix'
  InstallerUrl  = "https://c.1password.com/dist/1P/win8/1PasswordSetup-$($this.CurrentState.Version).msixbundle"
}
$this.CurrentState.Installer += [ordered]@{
  Architecture  = 'arm64'
  InstallerType = 'msix'
  InstallerUrl  = "https://c.1password.com/dist/1P/win8/1PasswordSetup-$($this.CurrentState.Version).msixbundle"
}

switch -Regex ($this.Check()) {
  'New|Changed|Updated' {
    $this.InstallerFiles[$InstallerMSIX.InstallerUrl] = $InstallerMSIXFile = Get-TempFile -Uri $InstallerMSIX.InstallerUrl
    # RealVersion
    $this.CurrentState.RealVersion = ($InstallerMSIXFile | Get-MSIXManifest | ConvertFrom-Xml).GetElementsByTagName('Package')[0].Version
    # RawVersion
    $RawVersion = $this.CurrentState.RealVersion.Split('.').ForEach({ [int]$_ })
    $this.CurrentState.RawVersion = '{0}{1}{2}{3:d3}' -f @($RawVersion)

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
