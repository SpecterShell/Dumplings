$Object1 = Invoke-RestMethod -Uri 'https://licenses.graphpad.com/updates' -Body @{
  version       = $this.Status.Contains('New') ? '10.4.2': ($this.LastState.Version.Split('.')[0..2] -join '.')
  build         = $this.Status.Contains('New') ? '633' : $this.LastState.Version.Split('.')[3]
  platform      = 'Windows'
  osVersion     = '10.0.22000'
  osBitVersion  = '64'
  configuration = 'full'
} | ConvertFrom-Ini

# Version
$this.CurrentState.Version = $Object1.SB5UPDATE.Version

# Installer
$this.CurrentState.Installer += [ordered]@{
  InstallerUrl = Join-Uri $Object1.SB5UPDATE.Setup "InstallPrism$($this.CurrentState.Version.Split('.')[0]).msi"
}

switch -Regex ($this.Check()) {
  'New|Changed|Updated' {
    try {
      # ReleaseNotes (en-US)
      $this.CurrentState.Locale += [ordered]@{
        Locale = 'en-US'
        Key    = 'ReleaseNotes'
        Value  = $Object1.SB5UPDATE.Description | Format-Text
      }

      # ReleaseNotesUrl
      $this.CurrentState.Locale += [ordered]@{
        Key   = 'ReleaseNotesUrl'
        Value = $Object1.SB5UPDATE.ReleaseNotes
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
