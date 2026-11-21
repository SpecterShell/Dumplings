$Object1 = Invoke-PlaywrightFetch -Uri 'https://www.microchip.com/en-us/tools-resources/develop/mplab-xc-compilers/xc8' -Headless -Stealth | Get-EmbeddedLinks

# Installer
$this.CurrentState.Installer += [ordered]@{
  Architecture  = 'x64'
  InstallerType = 'exe'
  InstallerUrl  = $Object1.Where({ try { $_.href.EndsWith('.exe') -and $_.href -match 'installer' -and $_.href -match 'full-install' -and $_.href.Contains('x64') } catch {} }, 'First')[0].href
}

# Version
$this.CurrentState.Version = [regex]::Match($this.CurrentState.Installer[0].InstallerUrl, '(v\d+(?:\.\d+)+)').Groups[1].Value

switch -Regex ($this.Check()) {
  'New|Changed|Updated' {
    try {
      # ReleaseNotesUrl (en-US)
      $this.CurrentState.Locale += [ordered]@{
        Locale = 'en-US'
        Key    = 'ReleaseNotesUrl'
        Value  = "https://ww1.microchip.com/downloads/aemDocuments/documents/DEV/ProductDocuments/UserGuides/xc8-v$($this.CurrentState.Version)-full-install-release-notes-PIC.pdf"
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
