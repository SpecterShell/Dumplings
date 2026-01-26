$Object1 = Invoke-RestMethod -Uri 'https://up.freedownloadmanager.org/fdm6/checkupdate/' -Body @{
  os             = 'windows'
  osversion      = '10.0'
  osarchitecture = 'x86_64'
  architecture   = 'x86_64'
  version        = $this.Status.Contains('New') ? '6.31.0.6586' : $this.LastState.Version
  uuid           = '00000000-0000-0000-0000-000000000000'
  initiator      = '2'
}

if ([string]::IsNullOrWhiteSpace($Object1.version)) {
  $this.Log("The version $($this.LastState.Version) from the last state is the latest, skip checking", 'Info')
  return
}

# Version
$this.CurrentState.Version = $Object1.version

# Installer
$this.CurrentState.Installer += [ordered]@{
  InstallerUrl = $Object1.downloadURL
}

switch -Regex ($this.Check()) {
  'New|Changed|Updated' {
    try {
      # ReleaseNotes (en-US)
      $this.CurrentState.Locale += [ordered]@{
        Locale = 'en-US'
        Key    = 'ReleaseNotes'
        Value  = $Object1.changelogPlain | Format-Text
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
