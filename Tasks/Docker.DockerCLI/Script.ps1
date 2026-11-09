$Prefix = 'https://download.docker.com/win/static/stable/'

$Object1 = Invoke-WebRequest -Uri "${Prefix}x86_64/"

$InstallerName = $Object1.Links | Select-Object -ExpandProperty 'href' -ErrorAction SilentlyContinue | Where-Object -FilterScript { $_ -ne '../' -and $_ -match 'docker-[\d\.]+\.zip' } | Sort-Object -Property { [ChunkVersion]($_) } -Bottom 1

# Version
$this.CurrentState.Version = [regex]::Match($InstallerName, 'docker-([\d\.]+)\.zip').Groups[1].Value

# Installer
$this.CurrentState.Installer += [ordered]@{
  Architecture = 'x64'
  InstallerUrl = "${Prefix}x86_64/${InstallerName}"
}

# arm64 only when stable/aarch64/ exists and has the same version as x86_64/
$Object2 = Invoke-WebRequest -Uri $Prefix
if ($Object2.Links.href -contains 'aarch64/') {
  $Object3 = Invoke-WebRequest -Uri "${Prefix}aarch64/"
  if ($Object3.Links.href -contains $InstallerName) {
    $this.CurrentState.Installer += [ordered]@{
      Architecture = 'arm64'
      InstallerUrl = "${Prefix}aarch64/${InstallerName}"
    }
  } else {
    $this.Log("The arm64 installer ${InstallerName} is not available yet. Skipped.", 'Warning')
  }
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
