# Installer
$this.CurrentState.Installer += [ordered]@{
  InstallerUrl = Get-RedirectedUrl -Uri 'https://www.bulkrenameutility.co.uk/Down/BRU_setup.exe'
}

# Version
$this.CurrentState.Version = [regex]::Match($this.CurrentState.Installer[0].InstallerUrl, '(\d+(\.\d+)+)').Groups[1].Value

switch -Regex ($this.Check()) {
  'New|Changed|Updated' {
    try {
      $Prefix = 'https://www.bulkrenameutility.co.uk/Download.php'

      $Object1 = Invoke-WebRequest -Uri $Prefix

      # ReleaseNotesUrl
      $this.CurrentState.Locale += [ordered]@{
        Locale = 'en-US'
        Key    = 'ReleaseNotesUrl'
        Value  = Get-RedirectedUrl -Uri (Join-Uri $Prefix $Object1.Links.Where({ try { $_.href.EndsWith('.pdf') -and $_.href.Contains('Changelog') } catch {} }, 'First')[0].href)
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
