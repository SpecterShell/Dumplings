$Object1 = Invoke-WebRequest -Uri 'https://www.dedoose.com/download-the-app'

# Installer
$this.CurrentState.Installer += [ordered]@{
  InstallerUrl = $Object1.Links.Where({ try { $_.href.EndsWith('.exe') -and $_.href.Contains('Installer') } catch {} }, 'First')[0].href
}

$Object2 = Invoke-WebRequest -Uri $this.CurrentState.Installer[0].InstallerUrl -Method Head

# Version
$this.CurrentState.Version = [regex]::Match($Object2.Headers.'Content-Disposition'[0], '(\d+(?:\.\d+)+)').Groups[1].Value

switch -Regex ($this.Check()) {
  'New|Changed|Updated' {
    try {
      if ($Global:DumplingsStorage.Contains('Dedoose') -and $Global:DumplingsStorage.Dedoose.Contains($this.CurrentState.Version)) {
        # ReleaseNotes (en-US)
        $this.CurrentState.Locale += [ordered]@{
          Locale = 'en-US'
          Key    = 'ReleaseNotes'
          Value  = $Global:DumplingsStorage.Dedoose[$this.CurrentState.Version].ReleaseNotes
        }
      } else {
        $this.Log("No ReleaseNotes (en-US) for version $($this.CurrentState.Version)", 'Warning')
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
