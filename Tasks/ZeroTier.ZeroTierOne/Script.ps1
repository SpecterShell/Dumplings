$Prefix = 'https://download.zerotier.com/RELEASES/'

$Object1 = Invoke-WebRequest -Uri $Prefix

# Version
$this.CurrentState.Version = $Object1.Links.ForEach({ try { if ($_.href -match '^(\d+(?:\.\d+)+)/$') { $Matches[1] } } catch {} }) | Sort-Object -Property { $_ -replace '\d+', { $_.Value.PadLeft(20) } } -Bottom 1

# Installer
$this.CurrentState.Installer += [ordered]@{
  InstallerUrl = "${Prefix}$($this.CurrentState.Version)/dist/ZeroTierOne.msi"
  ProductCode  = "ZeroTier One $($this.CurrentState.Version)"
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
