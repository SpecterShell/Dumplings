$Objects = @($Global:DumplingsStorage.DYMOApps.'DYMO Softwares'.'DYMO Connect for Desktop'.Windows.GetEnumerator())
$LatestVersion = $Objects | ForEach-Object { [regex]::Match($_.Name, 'v(\d+(\.\d+)+)').Groups[1].Value } | Sort-Object -Property { [ChunkVersion]$_ } -Bottom 1
$InstallerUrls = $Objects.Where({ [regex]::Match($_.Name, 'v(\d+(\.\d+)+)').Groups[1].Value -eq $LatestVersion }) | ForEach-Object { $_.Value.url_s.GetEnumerator() }

# Installer
$this.CurrentState.Installer += [ordered]@{
  Architecture = 'x64'
  InstallerUrl = $InstallerUrls.Where({ $_.Value -match '(?i)-X64\.exe$' }, 'First')[0].Value | ConvertTo-UnescapedUri | ConvertTo-Https
}
$this.CurrentState.Installer += [ordered]@{
  Architecture = 'arm64'
  InstallerUrl = $InstallerUrls.Where({ $_.Value -match '(?i)-Arm64\.exe$' }, 'First')[0].Value | ConvertTo-UnescapedUri | ConvertTo-Https
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
