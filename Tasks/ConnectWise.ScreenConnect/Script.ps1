$Object1 = Invoke-WebRequest -Uri 'https://www.screenconnect.com/download'
$Object2 = $Object1.Links.Where({ try { $_.href.EndsWith('.msi') -and -not $_.href.Contains('Debug') } catch {} }, 'First')[0]

# Installer
$this.CurrentState.Installer += [ordered]@{
  InstallerUrl = $Object2.href
}

# Version
$this.CurrentState.Version = [regex]::Match($this.CurrentState.Installer[0].InstallerUrl, '(\d+(?:\.\d+)+)').Groups[1].Value

switch -Regex ($this.Check()) {
  'New|Changed|Updated' {
    try {
      # ReleaseTime
      $this.CurrentState.ReleaseTime = [datetime]::ParseExact(
        [regex]::Match($Object2.outerHTML, '(\d{1,2}/\d{1,2}/20\d{2})').Groups[1].Value,
        'M/d/yyyy',
        $null
      )
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
