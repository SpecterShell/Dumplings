$Prefix = 'https://download.kde.org/stable/kdiff3/'

$Object1 = Invoke-WebRequest -Uri $Prefix

$InstallerName = $Object1.Links.Where({ try { $_.href.EndsWith('.exe') } catch {} }).href | Sort-Object -Property { [RawVersion]$_ } -Bottom 1

# Version
$this.CurrentState.Version = [regex]::Match($InstallerName, 'kdiff3-(\d+(?:\.\d+)+)').Groups[1].Value

# Installer
$this.CurrentState.Installer += [ordered]@{
  InstallerUrl = Join-Uri $Prefix $InstallerName
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
