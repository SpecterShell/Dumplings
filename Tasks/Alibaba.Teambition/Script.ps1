$Object1 = Invoke-RestMethod -Uri 'https://www.teambition.com/site/client-config'

# Version
$this.CurrentState.Version = $Version = [regex]::Match($Object1.download_links.pc, 'Teambition-([\d\.]+)-win\.exe').Groups[1].Value

# Installer
$this.CurrentState.Installer += [ordered]@{
  InstallerUrl = $Object1.download_links.pc
}

if ($LocalStorage.Contains('Teambition') -and $LocalStorage.Teambition.Contains($Version)) {
  # ReleaseTime
  $this.CurrentState.ReleaseTime = $LocalStorage.Teambition.$Version.ReleaseTime
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
