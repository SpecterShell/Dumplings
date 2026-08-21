$Object1 = Invoke-WebRequest -Uri 'https://enreach.de/de/service/downloads'
$Installer = $Object1.Links.Where({ try { $_.href.EndsWith('.zip') -and $_.href.Contains('swyxit!_') -and $_.href.Contains('64bit') } catch {} }) | ForEach-Object -Process {
  [pscustomobject]@{
    Version      = [ChunkVersion][regex]::Match($_.href, 'swyxit!_(\d+(?:\.\d+)+)_64bit_german\.zip').Groups[1].Value
    InstallerUrl = $_.href
  }
} | Sort-Object -Property 'Version' -Bottom 1

# Version
$this.CurrentState.Version = [string]($Installer.Version)

# Installer
$this.CurrentState.Installer += [ordered]@{
  InstallerUrl = $Installer.InstallerUrl
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
