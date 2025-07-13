# x86
$Object1 = $Global:DumplingsStorage.AzulZuluBuilds | Where-Object -FilterScript { $_.distro_version[0] -eq 18 -and $_.name.Contains('jdk') -and -not $_.name.Contains('fx') -and $_.name.Contains('i686') } | Sort-Object -Property { $_.distro_version.ForEach({ $_.ToString().PadLeft(20) }) -join '.' } -Bottom 1
# x64
$Object2 = $Global:DumplingsStorage.AzulZuluBuilds | Where-Object -FilterScript { $_.distro_version[0] -eq 18 -and $_.name.Contains('jdk') -and -not $_.name.Contains('fx') -and $_.name.Contains('x64') } | Sort-Object -Property { $_.distro_version.ForEach({ $_.ToString().PadLeft(20) }) -join '.' } -Bottom 1

if (Compare-Object -ReferenceObject $Object1.distro_version -DifferenceObject $Object2.distro_version) {
  $this.Log("Inconsistent versions: x86: $($Object1.distro_version -join '.'), x64: $($Object2.distro_version -join '.')", 'Error')
  return
}

# Version
$this.CurrentState.Version = $Object1.distro_version -join '.'

# RealVersion
$this.CurrentState.RealVersion = $Object1.distro_version[0..2] -join '.'

# Installer
$this.CurrentState.Installer += [ordered]@{
  Architecture = 'x86'
  InstallerUrl = $Object1.download_url
}
$this.CurrentState.Installer += [ordered]@{
  Architecture = 'x64'
  InstallerUrl = $Object2.download_url
}

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
