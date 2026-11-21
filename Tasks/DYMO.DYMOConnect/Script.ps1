$Objects = $Global:DumplingsStorage.DYMOApps.records.Where({ $_.software -eq 'DYMO Connect for Desktop' })
$LatestVersion = $Objects | Sort-Object -Property { [ChunkVersion]$_.version } -Bottom 1 | Select-Object -ExpandProperty 'version'

# Installer
$this.CurrentState.Installer += [ordered]@{
  Architecture = 'x64'
  InstallerUrl = $Objects.Where({ $_.osVersion -eq 'Windows 11' -and $_.version -eq $LatestVersion -and $_.architecture -eq '64' }, 'Last')[0].url | ConvertTo-UnescapedUri | ConvertTo-Https
}
$this.CurrentState.Installer += [ordered]@{
  Architecture = 'arm64'
  InstallerUrl = $Objects.Where({ $_.osVersion -eq 'Windows 11' -and $_.version -eq $LatestVersion -and $_.architecture -eq 'ARM' }, 'Last')[0].url | ConvertTo-UnescapedUri | ConvertTo-Https
}

# Version
$this.CurrentState.Version = [regex]::Match($this.CurrentState.Installer[0].InstallerUrl, '(\d+(?:\.\d+)+)').Groups[1].Value

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
