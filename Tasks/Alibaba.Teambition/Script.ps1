$Object1 = Invoke-RestMethod -Uri 'https://www.teambition.com/site/client-config'

# Version
$this.CurrentState.Version = [regex]::Match($Object1.download_links.pc, 'Teambition-([\d\.]+)-win\.exe').Groups[1].Value

# Installer
$this.CurrentState.Installer += [ordered]@{
  InstallerUrl = $Object1.download_links.pc
}

switch -Regex ($this.Check()) {
  'New|Changed|Updated' {
    try {
      if ($Global:DumplingsStorage.Contains('Teambition') -and $Global:DumplingsStorage.Teambition.Contains($this.CurrentState.Version)) {
        # ReleaseTime
        $this.CurrentState.ReleaseTime = $Global:DumplingsStorage.Teambition[$this.CurrentState.Version].ReleaseTime | Get-Date -AsUTC
      } else {
        $this.Log("No ReleaseTime for version $($this.CurrentState.Version)", 'Warning')
      }
    } catch {
      $_ | Out-Host
      $this.Log($_, 'Warning')
    }

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
