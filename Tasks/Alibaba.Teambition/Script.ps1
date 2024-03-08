$Object1 = Invoke-RestMethod -Uri 'https://www.teambition.com/site/client-config'

# Version
$this.CurrentState.Version = $Version = [regex]::Match($Object1.download_links.pc, 'Teambition-([\d\.]+)-win\.exe').Groups[1].Value

# Installer
$this.CurrentState.Installer += [ordered]@{
  InstallerUrl = $Object1.download_links.pc
}

if ($Global:DumplingsStorage.Contains('Teambition') -and $Global:DumplingsStorage.Teambition.Contains($Version)) {
  # ReleaseTime
  $this.CurrentState.ReleaseTime = $Global:DumplingsStorage.Teambition.$Version.ReleaseTime
} else {
  $this.Log("No ReleaseTime for version $($this.CurrentState.Version)", 'Warning')
}

switch -Regex ($this.Check()) {
  'New|Changed|Updated' {
    $this.Write()
  }
  'Changed|Updated' {
    $this.Print()
    $this.Message()
  }
  'Updated' {
    $this.Submit()
  }
}
